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
  case notConnected
  case alreadyConnected
  case operationInProgress
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

/// One explicit WebSocket owner. No automatic reconnect or replay.
public actor KiteTicker {
  private let url: URL
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
    transport: any KiteWebSocketTransport
  ) throws {
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
    self.url = parts.url!
    self.transport = transport
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

  public func connect() async throws {
    try Task.checkCancellation()
    guard !connecting, connection == nil else { throw KiteTickerError.alreadyConnected }
    connecting = true
    let epoch = generation
    let pending = Task { [transport, url] in try await transport.connect(url: url) }
    connector = pending
    do {
      let socket = try await withTaskCancellationHandler {
        try await pending.value
      } onCancel: {
        pending.cancel()
      }
      guard epoch == generation, !Task.isCancelled else {
        await socket.close()
        throw CancellationError()
      }
      connecting = false
      connector = nil
      connection = socket
      receiver = Task { [weak self] in
        do {
          for try await message in socket.messages {
            try Task.checkCancellation()
            guard let self else { break }
            try await self.receive(message, epoch: epoch)
          }
          await self?.failed(KiteTickerError.connectionClosed, epoch: epoch)
        } catch {
          await self?.failed(error, epoch: epoch)
        }
      }
    } catch {
      if epoch == generation {
        connecting = false
        connector = nil
      }
      if Task.isCancelled || error is CancellationError { throw CancellationError() }
      throw error
    }
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
    guard let connection else { throw KiteTickerError.notConnected }
    guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
    let operation = UUID()
    commandOperation = operation
    defer { if commandOperation == operation { commandOperation = nil } }
    let epoch = generation
    try Task.checkCancellation()
    do {
      try await connection.send(text: command("subscribe", tokens))
      guard epoch == generation else { throw CancellationError() }
      try await connection.send(text: modeCommand(mode, tokens))
      guard epoch == generation else { throw CancellationError() }
      subscriptions.formUnion(tokens)
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
    guard let connection else { throw KiteTickerError.notConnected }
    guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
    guard Set(tokens).isSubset(of: subscriptions) else {
      throw KiteTickerError.invalidConfiguration("Mode changes require subscribed tokens")
    }
    let operation = UUID()
    commandOperation = operation
    defer { if commandOperation == operation { commandOperation = nil } }
    let epoch = generation
    do {
      try Task.checkCancellation()
      try await connection.send(text: modeCommand(mode, tokens))
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
    guard let connection else { throw KiteTickerError.notConnected }
    guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
    let operation = UUID()
    commandOperation = operation
    defer { if commandOperation == operation { commandOperation = nil } }
    let epoch = generation
    do {
      try Task.checkCancellation()
      try await connection.send(text: command("unsubscribe", tokens))
      guard epoch == generation else { throw CancellationError() }
      subscriptions.subtract(tokens)
    } catch {
      await failed(error, epoch: epoch)
      throw error
    }
  }

  public func disconnect() async {
    generation = UUID()
    connecting = false
    connector?.cancel()
    connector = nil
    receiver?.cancel()
    receiver = nil
    let socket = connection
    connection = nil
    subscriptions.removeAll()
    commandOperation = nil
    let current = subscribers.values
    subscribers.removeAll()
    for continuation in current { continuation.finish() }
    for continuation in marketSubscribers.values { continuation.finish() }
    marketSubscribers.removeAll()
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
  private func removeMarketSubscriber(_ id: UUID) { marketSubscribers.removeValue(forKey: id) }
  private func removeSubscriber(_ id: UUID) { subscribers.removeValue(forKey: id) }
  private func failed(_ error: any Error, epoch: UUID) async {
    guard epoch == generation else { return }
    generation = UUID()
    let socket = connection
    connection = nil
    receiver = nil
    subscriptions.removeAll()
    commandOperation = nil
    for continuation in subscribers.values { continuation.finish(throwing: error) }
    subscribers.removeAll()
    for continuation in marketSubscribers.values { continuation.finish(throwing: error) }
    marketSubscribers.removeAll()
    await socket?.close()
  }
  private func receive(_ message: KiteWebSocketMessage, epoch: UUID) throws {
    guard epoch == generation else { return }
    // Text events are outside #18. Their typed channel follows in #20.
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
