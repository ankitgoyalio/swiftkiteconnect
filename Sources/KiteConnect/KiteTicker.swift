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
  private var lifecycleSubscribers:
    [UUID: AsyncThrowingStream<KiteTickerLifecycleEvent, any Error>.Continuation] = [:]
  private let tradingTimeZone: TimeZone
  private var brokerSubscribers:
    [UUID: AsyncThrowingStream<KiteBrokerEvent, any Error>.Continuation] = [:]
  private var orderSubscribers:
    [UUID: AsyncThrowingStream<KiteOrderUpdateEvent, any Error>.Continuation] = [:]
  private let transport: any KiteWebSocketTransport
  private var connection: (any KiteWebSocketConnection)?
  private var receiver: Task<Void, Never>?
  private var generation = UUID()
  private var connecting = false
  private var connector: Task<any KiteWebSocketConnection, any Error>?
  private var subscribers: [UUID: AsyncThrowingStream<KiteLTPTick, any Error>.Continuation] = [:]
  private var marketSubscribers:
    [UUID: AsyncThrowingStream<KiteMarketTick, any Error>.Continuation] = [:]
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
    guard bufferCapacity > 0 else {
      throw KiteTickerError.invalidConfiguration("Buffer capacity must be positive")
    }
    let id = UUID()
    let (stream, continuation) = AsyncThrowingStream<KiteLTPTick, any Error>.makeStream(
      bufferingPolicy: .bufferingOldest(bufferCapacity))
    subscribers[id] = continuation
    continuation.onTermination = { [weak self] _ in Task { await self?.removeSubscriber(id) } }
    return stream
  }

  /// Each subscriber receives every binary layout with its own bounded buffer.
  public func marketTicks(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<
    KiteMarketTick, any Error
  > {
    guard bufferCapacity > 0 else {
      throw KiteTickerError.invalidConfiguration("Buffer capacity must be positive")
    }
    let id = UUID()
    let (stream, continuation) = AsyncThrowingStream<KiteMarketTick, any Error>.makeStream(
      bufferingPolicy: .bufferingOldest(bufferCapacity))
    marketSubscribers[id] = continuation
    continuation.onTermination = { [weak self] _ in Task { await self?.removeMarketSubscriber(id) }
    }
    return stream
  }

  /// Each call has a bounded buffer independent of all market-data subscribers.
  public func orderUpdates(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<
    KiteOrderUpdateEvent, any Error
  > {
    guard bufferCapacity > 0 else {
      throw KiteTickerError.invalidConfiguration("Buffer capacity must be positive")
    }
    let id = UUID()
    let (stream, continuation) = AsyncThrowingStream<KiteOrderUpdateEvent, any Error>.makeStream(
      bufferingPolicy: .bufferingOldest(bufferCapacity))
    orderSubscribers[id] = continuation
    continuation.onTermination = { [weak self] _ in Task { await self?.removeOrderSubscriber(id) } }
    return stream
  }

  /// Broker notices and errors have their own per-subscriber bounded capacity.
  public func brokerEvents(bufferCapacity: Int = 64) throws -> AsyncThrowingStream<
    KiteBrokerEvent, any Error
  > {
    guard bufferCapacity > 0 else {
      throw KiteTickerError.invalidConfiguration("Buffer capacity must be positive")
    }
    let id = UUID()
    let (stream, continuation) = AsyncThrowingStream<KiteBrokerEvent, any Error>.makeStream(
      bufferingPolicy: .bufferingOldest(bufferCapacity))
    brokerSubscribers[id] = continuation
    continuation.onTermination = { [weak self] _ in Task { await self?.removeBrokerSubscriber(id) }
    }
    return stream
  }

  public func lifecycleEvents(bufferCapacity: Int = 64) throws -> AsyncThrowingStream<
    KiteTickerLifecycleEvent, any Error
  > {
    guard bufferCapacity > 0 else {
      throw KiteTickerError.invalidConfiguration("Buffer capacity must be positive")
    }
    let id = UUID()
    let (stream, continuation) = AsyncThrowingStream<KiteTickerLifecycleEvent, any Error>
      .makeStream(bufferingPolicy: .bufferingOldest(bufferCapacity))
    lifecycleSubscribers[id] = continuation
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeLifecycleSubscriber(id) }
    }
    return stream
  }

  private func removeLifecycleSubscriber(_ id: UUID) {
    lifecycleSubscribers.removeValue(forKey: id)
  }
  private func emit(_ event: KiteTickerLifecycleEvent) {
    for (id, continuation) in lifecycleSubscribers {
      switch continuation.yield(event) {
      case .dropped:
        continuation.finish(throwing: KiteTickerError.bufferOverflow)
        lifecycleSubscribers.removeValue(forKey: id)
      case .terminated: lifecycleSubscribers.removeValue(forKey: id)
      default: break
      }
    }
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
    connector?.cancel()
    connector = nil
    receiver?.cancel()
    receiver = nil
    connecting = wasActive
    commandOperation = nil
    let old = connection
    connection = nil
    if wasActive && !wasBlocked { emit(.possibleDataGap) }
    await old?.close()
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
    connecting = true
    let pending = Task { [transport, url] in try await transport.connect(url: url) }
    connector = pending
    let socket = try await withTaskCancellationHandler {
      try await pending.value
    } onCancel: {
      pending.cancel()
    }
    guard epoch == generation, !Task.isCancelled, active else {
      await socket.close()
      throw CancellationError()
    }
    connector = nil
    // Retain the pending socket so disconnect/replacement also closes a blocked restore write.
    connection = socket
    do {
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
    } catch {
      await socket.close()
      throw error
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
    connector?.cancel()
    connector = nil
    receiver?.cancel()
    receiver = nil
    let socket = connection
    connection = nil
    subscriptions.removeAll()
    modes.removeAll()
    commandOperation = nil
    let current = subscribers.values
    subscribers.removeAll()
    for continuation in current { continuation.finish() }
    for continuation in marketSubscribers.values { continuation.finish() }
    marketSubscribers.removeAll()
    for continuation in brokerSubscribers.values { continuation.finish() }
    brokerSubscribers.removeAll()
    for continuation in orderSubscribers.values { continuation.finish() }
    orderSubscribers.removeAll()
    emit(.disconnected)
    for continuation in lifecycleSubscribers.values { continuation.finish() }
    lifecycleSubscribers.removeAll()
    await socket?.close()
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
  private func removeBrokerSubscriber(_ id: UUID) { brokerSubscribers.removeValue(forKey: id) }
  private func removeOrderSubscriber(_ id: UUID) { orderSubscribers.removeValue(forKey: id) }
  private func removeMarketSubscriber(_ id: UUID) { marketSubscribers.removeValue(forKey: id) }
  private func removeSubscriber(_ id: UUID) { subscribers.removeValue(forKey: id) }
  private func failed(_ error: any Error, epoch: UUID, schedule: Bool = true) async {
    guard epoch == generation, active else { return }
    generation = UUID()
    connecting = false
    connector?.cancel()
    connector = nil
    receiver?.cancel()
    receiver = nil
    let socket = connection
    connection = nil
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
      for continuation in subscribers.values { continuation.finish(throwing: error) }
      subscribers.removeAll()
      for continuation in marketSubscribers.values { continuation.finish(throwing: error) }
      marketSubscribers.removeAll()
      for continuation in brokerSubscribers.values { continuation.finish(throwing: error) }
      brokerSubscribers.removeAll()
      for continuation in orderSubscribers.values { continuation.finish(throwing: error) }
      orderSubscribers.removeAll()
      for continuation in lifecycleSubscribers.values { continuation.finish(throwing: error) }
      lifecycleSubscribers.removeAll()
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
    await socket?.close()
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
          for (id, continuation) in orderSubscribers {
            switch continuation.yield(order) {
            case .dropped:
              continuation.finish(throwing: KiteTickerError.bufferOverflow)
              orderSubscribers.removeValue(forKey: id)
            case .terminated: orderSubscribers.removeValue(forKey: id)
            case .enqueued: break
            @unknown default: break
            }
          }
        case .broker(let event):
          for (id, continuation) in brokerSubscribers {
            switch continuation.yield(event) {
            case .dropped:
              continuation.finish(throwing: KiteTickerError.bufferOverflow)
              brokerSubscribers.removeValue(forKey: id)
            case .terminated: brokerSubscribers.removeValue(forKey: id)
            case .enqueued: break
            @unknown default: break
            }
          }
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
      for (id, continuation) in marketSubscribers {
        switch continuation.yield(tick) {
        case .dropped:
          continuation.finish(throwing: KiteTickerError.bufferOverflow)
          marketSubscribers.removeValue(forKey: id)
        case .terminated: marketSubscribers.removeValue(forKey: id)
        case .enqueued: break
        @unknown default: break
        }
      }
      let tick = KiteLTPTick(instrumentToken: tick.instrumentToken, lastPrice: tick.lastPrice)
      for (id, continuation) in subscribers {
        switch continuation.yield(tick) {
        case .dropped:
          continuation.finish(throwing: KiteTickerError.bufferOverflow)
          subscribers.removeValue(forKey: id)
        case .terminated: subscribers.removeValue(forKey: id)
        case .enqueued: break
        @unknown default: break
        }
      }
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
