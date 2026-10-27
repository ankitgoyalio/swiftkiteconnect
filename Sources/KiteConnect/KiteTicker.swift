import Foundation

public enum KiteWebSocketMessage: Sendable, Equatable {
  case binary(Data)
  case text(String)
}

/// A single connection. Messages must be ordered and bounded; overflow must fail explicitly.
/// Closing must release the socket and finish messages. No retries belong at this boundary.
public protocol KiteWebSocketConnection: Sendable {
  var messages: AsyncThrowingStream<KiteWebSocketMessage, any Error> { get }
  func send(text: String) async throws
  func close() async
}

/// Creates an independent connection for each call; implementations must honor cancellation.
public protocol KiteWebSocketTransport: Sendable {
  func connect(url: URL) async throws -> any KiteWebSocketConnection
}

public enum KiteTickerError: Error, Sendable, Equatable {
  case invalidConfiguration(String)
  case authenticationRequired
  case notConnected
  case alreadyConnected
  case operationInProgress
  case malformedText
  case malformedPacket
  case unsupportedPacketLength(Int)
  case bufferOverflow
  case connectionClosed
  case handshakeRejected(statusCode: Int)
  case transport(String)
}

public struct KiteLTPTick: Sendable, Equatable {
  public let instrumentToken: UInt32
  public let lastPrice: Decimal
}

/// One explicit WebSocket owner with bounded recovery, without missed-event replay.
public actor KiteTicker {
  private var url: URL
  private let reconnectPolicy: KiteTickerReconnectPolicy
  private let sleeper: any KiteTickerSleeper
  private var recovery: Task<Void, Never>?
  private var recoveryID = UUID()
  private var active = false
  private var authenticationBlocked = false
  private var modes: [UInt32: KiteTickerMode] = [:]
  private var desiredRevision = UUID()
  private var lifecycleSubscribers = BoundedSubscribers<KiteTickerLifecycleEvent>()
  private let tradingTimeZone: TimeZone
  private var brokerSubscribers = BoundedSubscribers<KiteBrokerEvent>()
  private var orderSubscribers = BoundedSubscribers<KiteOrderUpdateEvent>()
  private let transport: any KiteWebSocketTransport
  private var connection: (any KiteWebSocketConnection)?
  // Retired handshakes own cleanup of any late socket result. Every new handshake waits
  // for this chain, so detaching actor state never releases physical admission early.
  private var teardown: Task<Void, Never>?
  private var receiver: Task<Void, Never>?
  private var generation = UUID()
  private var connecting = false
  private var connector: Task<any KiteWebSocketConnection, any Error>?
  private var subscribers = BoundedSubscribers<KiteLTPTick>()
  private var marketSubscribers = BoundedSubscribers<KiteMarketTick>()
  private var subscriptions: Set<UInt32> = []
  private var commandOperation: UUID?

  public init(
    apiKey: String, accessToken: String, userID: String? = nil,
    endpoint: URL = URL(string: "wss://ws.kite.trade")!,
    transport: any KiteWebSocketTransport,
    tradingTimeZone: TimeZone = TimeZone(identifier: "Asia/Kolkata")!,
    reconnectPolicy: KiteTickerReconnectPolicy = .init(),
    sleeper: any KiteTickerSleeper = KiteTickerContinuousSleeper()
  ) throws {
    guard reconnectPolicy.initialDelay > .zero,
      reconnectPolicy.maximumDelay >= reconnectPolicy.initialDelay,
      reconnectPolicy.maximumDelay <= .seconds(3600),
      (0...1000).contains(reconnectPolicy.maximumAttempts)
    else { throw KiteTickerError.invalidConfiguration("Invalid reconnect bounds") }
    guard !apiKey.isEmpty, !accessToken.isEmpty,
      var parts = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
      ["ws", "wss"].contains(parts.scheme), parts.host != nil,
      parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil
    else {
      throw KiteTickerError.invalidConfiguration(
        "Supply credentials and a ws/wss endpoint without query or user info")
    }
    if parts.host == "ws-sandbox.kite.trade", userID?.isEmpty != false {
      throw KiteTickerError.invalidConfiguration("Sandbox WebSocket requires user_id")
    }
    parts.queryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "access_token", value: accessToken),
    ]
    if let userID { parts.queryItems?.append(URLQueryItem(name: "user_id", value: userID)) }
    // HTTP query parsers commonly interpret a literal plus as a space.
    parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(
      of: "+", with: "%2B")
    self.reconnectPolicy = reconnectPolicy
    self.sleeper = sleeper
    self.url = parts.url!
    self.transport = transport
    self.tradingTimeZone = tradingTimeZone
  }

  /// Each call creates an independent bounded subscriber. Overflow ends only that subscriber.
  public func ticks(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<KiteLTPTick, any Error>
  {
    try subscribers.stream(capacity: bufferCapacity) { [weak self] id in
      Task { await self?.removeSubscriber(id) }
    }
  }

  /// Each subscriber receives every binary layout with its own bounded buffer.
  public func marketTicks(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<
    KiteMarketTick, any Error
  > {
    try marketSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
      Task { await self?.removeMarketSubscriber(id) }
    }
  }

  /// Each call has a bounded buffer independent of all market-data subscribers.
  public func orderUpdates(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<
    KiteOrderUpdateEvent, any Error
  > {
    try orderSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
      Task { await self?.removeOrderSubscriber(id) }
    }
  }

  /// Broker notices and errors have their own per-subscriber bounded capacity.
  public func brokerEvents(bufferCapacity: Int = 64) throws -> AsyncThrowingStream<
    KiteBrokerEvent, any Error
  > {
    try brokerSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
      Task { await self?.removeBrokerSubscriber(id) }
    }
  }

  public func lifecycleEvents(bufferCapacity: Int = 64) throws -> AsyncThrowingStream<
    KiteTickerLifecycleEvent, any Error
  > {
    try lifecycleSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
      Task { await self?.removeLifecycleSubscriber(id) }
    }
  }

  private func removeLifecycleSubscriber(_ id: UUID) {
    lifecycleSubscribers.remove(id)
  }
  private func emit(_ event: KiteTickerLifecycleEvent) {
    lifecycleSubscribers.yield(event)
  }

  public func connect() async throws {
    try Task.checkCancellation()
    guard !authenticationBlocked else { throw KiteTickerError.authenticationRequired }
    guard !active else { throw KiteTickerError.alreadyConnected }
    active = true
    let epoch = generation
    do {
      try await establish(epoch: epoch)
      emit(.connected)
    } catch {
      if epoch != generation || Task.isCancelled || error is CancellationError {
        if epoch == generation { await disconnect() }
        throw CancellationError()
      }
      await failed(error, epoch: epoch)
      throw error
    }
  }

  /// Replaces this ticker's session, closing the old socket before connecting with new credentials.
  /// Desired subscriptions survive; in-flight old-session work is cancelled and generation-fenced.
  /// If explicitly disconnected, only updates credentials; call connect() to start again.
  public func replaceCredentials(apiKey: String, accessToken: String, userID: String? = nil)
    async throws
  {
    guard !apiKey.isEmpty, !accessToken.isEmpty else {
      throw KiteTickerError.invalidConfiguration("Supply nonempty credentials")
    }
    var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    if parts.host == "ws-sandbox.kite.trade", userID?.isEmpty != false {
      throw KiteTickerError.invalidConfiguration("Sandbox WebSocket requires user_id")
    }
    parts.queryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "access_token", value: accessToken),
    ]
    if let userID { parts.queryItems?.append(URLQueryItem(name: "user_id", value: userID)) }
    parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(
      of: "+", with: "%2B")
    url = parts.url!
    let wasActive = active
    let wasBlocked = authenticationBlocked
    authenticationBlocked = false
    generation = UUID()
    let epoch = generation
    recoveryID = UUID()
    recovery?.cancel()
    recovery = nil
    let closing = retireConnection()
    receiver?.cancel()
    receiver = nil
    connecting = wasActive
    commandOperation = nil
    if wasActive && !wasBlocked { emit(.possibleDataGap) }
    await closing.value
    guard epoch == generation else { throw CancellationError() }
    if Task.isCancelled {
      await disconnect()
      throw CancellationError()
    }
    guard wasActive else { return }
    do {
      try await establish(epoch: epoch)
      emit(.reconnected)
    } catch {
      if epoch != generation || error is CancellationError || Task.isCancelled {
        if epoch == generation { await disconnect() }
        throw CancellationError()
      }
      await failed(error, epoch: epoch)
      throw error
    }
  }

  private func establish(epoch: UUID) async throws {
    guard epoch == generation, active else { throw CancellationError() }
    if let teardown { await teardown.value }
    try Task.checkCancellation()
    guard epoch == generation, active else { throw CancellationError() }
    connecting = true
    let pending = Task { [transport, url] in try await transport.connect(url: url) }
    connector = pending
    let socket = try await withTaskCancellationHandler {
      try await pending.value
    } onCancel: {
      pending.cancel()
    }
    guard epoch == generation, !Task.isCancelled, active else {
      // The transition which invalidated this epoch owns late-result cleanup.
      throw CancellationError()
    }
    connector = nil
    // Retain the socket so failure/disconnect/replacement owns any blocked restore cleanup.
    connection = socket
    var sent: Set<UInt32> = []
    repeat {
      let revision = desiredRevision
      let snapshot = modes
      let tokens = Set(snapshot.keys)
      if !sent.subtracting(tokens).isEmpty {
        try await send(
          command("unsubscribe", sent.subtracting(tokens).sorted()), on: socket, epoch: epoch)
      }
      if !tokens.isEmpty {
        try await send(command("subscribe", tokens.sorted()), on: socket, epoch: epoch)
        for mode in KiteTickerMode.allCases {
          let group = tokens.filter { snapshot[$0] == mode }.sorted()
          if !group.isEmpty { try await send(modeCommand(mode, group), on: socket, epoch: epoch) }
        }
      }
      sent = tokens
      if revision == desiredRevision { break }
    } while true
    guard epoch == generation, active, !Task.isCancelled else { throw CancellationError() }
    connecting = false
    receiver = Task { [weak self] in
      do {
        for try await message in socket.messages {
          try Task.checkCancellation()
          guard let self else { break }
          try await self.receive(message, epoch: epoch)
        }
        await self?.failed(KiteTickerError.connectionClosed, epoch: epoch)
      } catch { await self?.failed(error, epoch: epoch) }
    }
  }

  private func send(_ text: String, on socket: any KiteWebSocketConnection, epoch: UUID)
    async throws
  {
    guard epoch == generation, active else { throw CancellationError() }
    try Task.checkCancellation()
    try await socket.send(text: text)
    guard epoch == generation, active else { throw CancellationError() }
    try Task.checkCancellation()
  }

  /// Preserves the original LTP subscription API, including function references.
  public func subscribe(_ tokens: [UInt32]) async throws {
    try await subscribe(tokens, mode: .ltp)
  }

  public func subscribe(_ tokens: [UInt32], mode: KiteTickerMode) async throws {
    guard !tokens.isEmpty, tokens.allSatisfy({ $0 > 0 }), subscriptions.union(tokens).count <= 3000
    else {
      throw KiteTickerError.invalidConfiguration("Subscribe to 1...3000 nonzero instrument tokens")
    }
    guard active else { throw KiteTickerError.notConnected }
    guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
    try Task.checkCancellation()
    subscriptions.formUnion(tokens)
    for token in tokens { modes[token] = mode }
    desiredRevision = UUID()
    guard let connection, !connecting else { return }
    let operation = UUID()
    commandOperation = operation
    defer { if commandOperation == operation { commandOperation = nil } }
    let epoch = generation
    try Task.checkCancellation()
    do {
      try await send(command("subscribe", tokens), on: connection, epoch: epoch)
      guard epoch == generation else { throw CancellationError() }
      try await send(modeCommand(mode, tokens), on: connection, epoch: epoch)
      guard epoch == generation else { throw CancellationError() }
    } catch {
      await failed(error, epoch: epoch)
      throw error
    }
  }

  /// Changes only currently subscribed tokens. Commands are serialized by the caller.
  public func setMode(_ mode: KiteTickerMode, for tokens: [UInt32]) async throws {
    guard !tokens.isEmpty, tokens.allSatisfy({ $0 > 0 }) else {
      throw KiteTickerError.invalidConfiguration("Supply nonzero instrument tokens")
    }
    guard active else { throw KiteTickerError.notConnected }
    guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
    guard Set(tokens).isSubset(of: subscriptions) else {
      throw KiteTickerError.invalidConfiguration("Mode changes require subscribed tokens")
    }
    try Task.checkCancellation()
    for token in tokens { modes[token] = mode }
    desiredRevision = UUID()
    guard let connection, !connecting else { return }
    let operation = UUID()
    commandOperation = operation
    defer { if commandOperation == operation { commandOperation = nil } }
    let epoch = generation
    do {
      try Task.checkCancellation()
      try await send(modeCommand(mode, tokens), on: connection, epoch: epoch)
      guard epoch == generation else { throw CancellationError() }
    } catch {
      await failed(error, epoch: epoch)
      throw error
    }
  }

  public func unsubscribe(_ tokens: [UInt32]) async throws {
    guard !tokens.isEmpty, tokens.allSatisfy({ $0 > 0 }) else {
      throw KiteTickerError.invalidConfiguration("Supply nonzero instrument tokens")
    }
    guard active else { throw KiteTickerError.notConnected }
    guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
    try Task.checkCancellation()
    subscriptions.subtract(tokens)
    for token in tokens { modes.removeValue(forKey: token) }
    desiredRevision = UUID()
    guard let connection, !connecting else { return }
    let operation = UUID()
    commandOperation = operation
    defer { if commandOperation == operation { commandOperation = nil } }
    let epoch = generation
    do {
      try Task.checkCancellation()
      try await send(command("unsubscribe", tokens), on: connection, epoch: epoch)
      guard epoch == generation else { throw CancellationError() }
    } catch {
      await failed(error, epoch: epoch)
      throw error
    }
  }

  public func disconnect() async {
    active = false
    recoveryID = UUID()
    recovery?.cancel()
    recovery = nil
    generation = UUID()
    connecting = false
    let hadSocket = connection != nil
    let closing = retireConnection()
    receiver?.cancel()
    receiver = nil
    subscriptions.removeAll()
    modes.removeAll()
    commandOperation = nil
    subscribers.finish()
    marketSubscribers.finish()
    brokerSubscribers.finish()
    orderSubscribers.finish()
    emit(.disconnected)
    lifecycleSubscribers.finish()
    if hadSocket { await closing.value }
  }

  /// Install the fence synchronously, before any actor suspension or recovery admission.
  private func retireConnection() -> Task<Void, Never> {
    let previous = teardown
    let pending = connector
    let socket = connection
    pending?.cancel()
    connector = nil
    connection = nil
    let closing = Task {
      await previous?.value
      if let socket { await socket.close() }
      if let pending, let late = try? await pending.value { await late.close() }
    }
    teardown = closing
    return closing
  }

  private func command(_ action: String, _ tokens: [UInt32]) throws -> String {
    String(
      decoding: try JSONSerialization.data(withJSONObject: ["a": action, "v": tokens]),
      as: UTF8.self)
  }
  private func modeCommand(_ mode: KiteTickerMode, _ tokens: [UInt32]) throws -> String {
    String(
      decoding: try JSONSerialization.data(withJSONObject: [
        "a": "mode", "v": [mode.rawValue, tokens],
      ]),
      as: UTF8.self)
  }
  private func removeBrokerSubscriber(_ id: UUID) { brokerSubscribers.remove(id) }
  private func removeOrderSubscriber(_ id: UUID) { orderSubscribers.remove(id) }
  private func removeMarketSubscriber(_ id: UUID) { marketSubscribers.remove(id) }
  private func removeSubscriber(_ id: UUID) { subscribers.remove(id) }
  private func failed(_ error: any Error, epoch: UUID, schedule: Bool = true) async {
    guard epoch == generation, active else { return }
    generation = UUID()
    connecting = false
    let closing = retireConnection()
    receiver?.cancel()
    receiver = nil
    commandOperation = nil
    let authentication = Self.isAuthenticationFailure(error)
    let terminal: Bool
    switch error as? KiteTickerError {
    case .malformedPacket, .malformedText, .unsupportedPacketLength, .invalidConfiguration:
      terminal = true
    default: terminal = false
    }
    if terminal {
      active = false
      subscribers.finish(throwing: error)
      marketSubscribers.finish(throwing: error)
      brokerSubscribers.finish(throwing: error)
      orderSubscribers.finish(throwing: error)
      lifecycleSubscribers.finish(throwing: error)
    } else {
      if schedule { emit(.possibleDataGap) }
      if authentication {
        authenticationBlocked = true
        recoveryID = UUID()
        recovery?.cancel()
        recovery = nil
        emit(.authenticationRequired)
      } else if schedule {
        startRecovery()
      }
    }
    await closing.value
  }

  private static func isAuthenticationFailure(_ error: any Error) -> Bool {
    switch error as? KiteTickerError {
    case .authenticationRequired, .handshakeRejected(statusCode: 401),
      .handshakeRejected(statusCode: 403):
      true
    default: false
    }
  }

  // The protocol supplies only a string. Recognize explicit session/credential failures;
  // ordinary subscription errors remain broker values. Unknown strings are never guessed.
  private static func isAuthenticationText(_ text: String) -> Bool {
    let value = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return value == "tokenexception" || value == "sessionexception"
      || value == "session expired" || value == "authentication failed"
      || value == "invalid `api_key` or `access_token`."
      || value == "invalid api_key or access_token"
      || value == "invalid access token" || value == "access token expired"
  }

  private func startRecovery() {
    recovery?.cancel()
    let id = UUID()
    recoveryID = id
    recovery = Task { [weak self] in await self?.recover(id: id) }
  }

  private func recover(id: UUID) async {
    var delay = reconnectPolicy.initialDelay
    for _ in 0..<reconnectPolicy.maximumAttempts {
      do { try await sleeper.sleep(for: delay) } catch { return }
      guard id == recoveryID, active, !authenticationBlocked, !Task.isCancelled else { return }
      let epoch = generation
      do {
        try await establish(epoch: epoch)
        guard id == recoveryID, epoch == generation else { return }
        recovery = nil
        emit(.reconnected)
        return
      } catch {
        guard id == recoveryID, epoch == generation, !Task.isCancelled else { return }
        await failed(error, epoch: epoch, schedule: false)
        guard id == recoveryID, active, !authenticationBlocked else { return }
      }
      delay = min(delay * 2, reconnectPolicy.maximumDelay)
    }
    guard id == recoveryID, active else { return }
    recovery = nil
    emit(.recoveryExhausted)
  }
  private func receive(_ message: KiteWebSocketMessage, epoch: UUID) throws {
    guard epoch == generation else { return }
    if case .text(let text) = message {
      do {
        let event = try KiteTimestamp.decoder(timeZone: tradingTimeZone).decode(
          KiteTextEvent.self, from: Data(text.utf8))
        switch event {
        case .order(let order):
          orderSubscribers.yield(order)
        case .broker(let event):
          brokerSubscribers.yield(event)
          if case .serverError(let text) = event, Self.isAuthenticationText(text) {
            throw KiteTickerError.authenticationRequired
          }
        }
      } catch KiteTickerError.authenticationRequired {
        throw KiteTickerError.authenticationRequired
      } catch { throw KiteTickerError.malformedText }
      return
    }
    guard case .binary(let data) = message else { return }
    let ticks = try Self.decode(data)
    for tick in ticks {
      marketSubscribers.yield(tick)
      let tick = KiteLTPTick(instrumentToken: tick.instrumentToken, lastPrice: tick.lastPrice)
      subscribers.yield(tick)
    }
  }
  private static func decode(_ data: Data) throws -> [KiteMarketTick] {
    let bytes = [UInt8](data)
    if bytes.count == 1 { return [] }  // documented binary heartbeat
    guard bytes.count >= 2 else { throw KiteTickerError.malformedPacket }
    func short(_ offset: Int) -> Int { Int(bytes[offset]) << 8 | Int(bytes[offset + 1]) }
    func word(_ offset: Int) -> UInt32 {
      UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8
        | UInt32(bytes[offset + 3])
    }
    let count = short(0)
    var offset = 2
    var result: [KiteMarketTick] = []
    for _ in 0..<count {
      guard offset + 2 <= bytes.count else { throw KiteTickerError.malformedPacket }
      let length = short(offset)
      offset += 2
      guard offset + length <= bytes.count else { throw KiteTickerError.malformedPacket }
      // Packet length defines the layout, including packets in flight during mode changes.
      guard [8, 28, 32, 44, 184].contains(length) else {
        throw KiteTickerError.unsupportedPacketLength(length)
      }
      let token = word(offset)
      guard token > 0 else { throw KiteTickerError.malformedPacket }
      let raw = word(offset + 4)
      let segment = token & 0xff
      let divisor = segment == 3 ? 10_000_000 : ([6, 12].contains(segment) ? 10_000 : 100)
      func price(_ field: Int) -> Decimal { Decimal(word(offset + field)) / Decimal(divisor) }
      var details: KiteMarketTick.Details = .ltp
      if length == 44 || length == 184 {
        let quote = KiteQuoteFields(
          lastTradedQuantity: word(offset + 8), averageTradedPrice: price(12),
          volumeTraded: word(offset + 16), totalBuyQuantity: word(offset + 20),
          totalSellQuantity: word(offset + 24),
          ohlc: KiteOHLC(open: price(28), high: price(32), low: price(36), close: price(40)))
        details = .quote(quote)
        if length == 184 {
          let levels = stride(from: 64, to: 184, by: 12).map { field in
            KiteDepthLevel(
              price: price(field + 4), quantity: Int64(word(offset + field)),
              orders: Int64(short(offset + field + 8)))
          }
          details = .full(
            KiteFullFields(
              quote: quote,
              lastTradeTime: Date(timeIntervalSince1970: TimeInterval(word(offset + 44))),
              openInterest: word(offset + 48), openInterestDayHigh: word(offset + 52),
              openInterestDayLow: word(offset + 56),
              exchangeTimestamp: Date(timeIntervalSince1970: TimeInterval(word(offset + 60))),
              depth: KiteMarketDepth(buy: Array(levels.prefix(5)), sell: Array(levels.suffix(5)))))
        }
      }
      if length == 28 || length == 32 {
        let index = KiteIndexFields(
          ohlc: KiteOHLC(open: price(16), high: price(8), low: price(12), close: price(20)),
          priceChange: Decimal(Int32(bitPattern: word(offset + 24))) / Decimal(divisor))
        details = .indexQuote(index)
        if length == 32 {
          details = .indexFull(
            index,
            exchangeTimestamp: Date(timeIntervalSince1970: TimeInterval(word(offset + 28))))
        }
      }
      result.append(
        KiteMarketTick(
          instrumentToken: token, lastPrice: Decimal(raw) / Decimal(divisor), details: details))
      offset += length
    }
    guard offset == bytes.count else { throw KiteTickerError.malformedPacket }
    return result
  }
}
