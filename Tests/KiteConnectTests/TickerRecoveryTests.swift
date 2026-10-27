import Foundation
import KiteConnect
import Testing

actor RecoverySleeper: KiteTickerSleeper {
  nonisolated let delays: AsyncStream<Duration>
  nonisolated let requested: AsyncStream<Duration>.Continuation
  private var pending: CheckedContinuation<Void, any Error>?
  private var waitID = UUID()
  nonisolated let cancellations: AsyncStream<Void>
  nonisolated let cancelled: AsyncStream<Void>.Continuation
  init() {
    (delays, requested) = AsyncStream.makeStream()
    (cancellations, cancelled) = AsyncStream.makeStream()
  }
  func sleep(for delay: Duration) async throws {
    let id = UUID()
    waitID = id
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      try await withCheckedThrowingContinuation { continuation in
        pending = continuation
        requested.yield(delay)
      }
      try Task.checkCancellation()
    } onCancel: {
      Task { await self.cancel(id: id) }
    }
  }
  func advance() {
    pending?.resume()
    pending = nil
  }
  func cancel(id: UUID) {
    if id == waitID {
      pending?.resume(throwing: CancellationError())
      pending = nil
    }
    cancelled.yield(())
  }
}

actor RecoveryTransport: KiteWebSocketTransport {
  nonisolated let attempts: AsyncStream<URL>
  nonisolated let attempted: AsyncStream<URL>.Continuation
  private var results: [Result<any KiteWebSocketConnection, KiteTickerError>]
  init(_ results: [Result<any KiteWebSocketConnection, KiteTickerError>]) {
    self.results = results
    (attempts, attempted) = AsyncStream.makeStream()
  }
  func connect(url: URL) async throws -> any KiteWebSocketConnection {
    attempted.yield(url)
    return try results.removeFirst().get()
  }
}

@Test func transientRecoveryUsesBoundedExponentialTimeAndRestoresDesiredModes() async throws {
  let first = ControlledSocket()
  let recovered = ControlledSocket()
  let transport = RecoveryTransport([
    .success(first), .failure(.connectionClosed), .failure(.connectionClosed), .success(recovered),
  ])
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token", transport: transport,
    reconnectPolicy: .init(
      initialDelay: .seconds(1), maximumDelay: .seconds(3), maximumAttempts: 4),
    sleeper: time)
  var lifecycle = try await ticker.lifecycleEvents().makeAsyncIterator()
  try await ticker.connect()
  #expect(try await lifecycle.next() == .connected)
  try await ticker.subscribe([1], mode: .full)
  try await ticker.subscribe([2], mode: .quote)
  first.incoming.finish(throwing: KiteTickerError.connectionClosed)
  #expect(try await lifecycle.next() == .possibleDataGap)
  var delays = time.delays.makeAsyncIterator()
  #expect(await delays.next() == .seconds(1))
  try await ticker.unsubscribe([1])
  try await ticker.setMode(.full, for: [2])
  try await ticker.subscribe([3], mode: .ltp)
  await time.advance()
  #expect(await delays.next() == .seconds(2))
  await time.advance()
  #expect(await delays.next() == .seconds(3))
  await time.advance()
  #expect(try await lifecycle.next() == .reconnected)
  let commands = try await recovered.sent().map {
    try JSONSerialization.jsonObject(with: Data($0.utf8)) as! NSDictionary
  }
  #expect(
    commands == [
      ["a": "subscribe", "v": [2, 3]] as NSDictionary,
      ["a": "mode", "v": ["ltp", [3]]] as NSDictionary,
      ["a": "mode", "v": ["full", [2]]] as NSDictionary,
    ])
  let quotes = try await ticker.ticks()
  recovered.incoming.yield(.binary(Data([0, 1, 0, 8, 0, 0, 0, 3, 0, 0, 0, 1])))
  var ticks = quotes.makeAsyncIterator()
  #expect(try await ticks.next()?.instrumentToken == 3)
  await ticker.disconnect()
  #expect(try await lifecycle.next() == .disconnected)
  #expect(try await lifecycle.next() == nil)
}

@Test(arguments: [401, 403]) func authenticationHandshakeStopsUntilCredentialsAreReplaced(
  status: Int
) async throws {
  let socket = ControlledSocket()
  let transport = RecoveryTransport([
    .failure(.handshakeRejected(statusCode: status)), .success(socket),
  ])
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "expired", transport: transport, sleeper: time)
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  await #expect(throws: KiteTickerError.handshakeRejected(statusCode: status)) {
    try await ticker.connect()
  }
  #expect(try await events.next() == .possibleDataGap)
  #expect(try await events.next() == .authenticationRequired)
  await #expect(throws: KiteTickerError.authenticationRequired) { try await ticker.connect() }
  try await ticker.subscribe([1], mode: .full)
  try await ticker.replaceCredentials(apiKey: "new key", accessToken: "fresh+token")
  #expect(try await events.next() == .reconnected)
  var attempts = transport.attempts.makeAsyncIterator()
  _ = await attempts.next()
  let url = try #require(await attempts.next())
  #expect(url.absoluteString.contains("access_token=fresh%2Btoken"))
  #expect(await socket.sent().count == 2)
  await ticker.disconnect()
}

@Test(
  .timeLimit(.minutes(1)),
  arguments: [
    "TokenException", "Invalid `api_key` or `access_token`.", "Session expired",
    "Authentication failed",
  ])
func explicitAuthenticationTextStopsRecoveryButStillReachesBrokerSubscriber(text: String)
  async throws
{
  let socket = ControlledSocket()
  let fresh = ControlledSocket()
  let transport = RecoveryTransport([.success(socket), .success(fresh)])
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "old", transport: transport, sleeper: RecoverySleeper())
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  var broker = try await ticker.brokerEvents().makeAsyncIterator()
  try await ticker.connect()
  _ = try await events.next()
  let data = try JSONSerialization.data(withJSONObject: ["type": "error", "data": text])
  socket.incoming.yield(.text(String(decoding: data, as: UTF8.self)))
  #expect(try await broker.next() == .serverError(text))
  // connect() must report the stopped authentication state, not alreadyConnected.
  // The broker iterator only synchronizes delivery; a lifecycle event synchronizes the stop.
  #expect(try await events.next() == .possibleDataGap)
  #expect(try await events.next() == .authenticationRequired)
  await #expect(throws: KiteTickerError.authenticationRequired) { try await ticker.connect() }
  try await ticker.replaceCredentials(apiKey: "key", accessToken: "fresh")
  #expect(try await events.next() == .reconnected)
  await ticker.disconnect()
}

/// Deliberately returns late even after cancellation to exercise the ticker's session fence.
actor HandshakeGate: KiteWebSocketTransport {
  nonisolated let requests: AsyncStream<URL>
  nonisolated let requested: AsyncStream<URL>.Continuation
  private var pending: [Int: CheckedContinuation<any KiteWebSocketConnection, any Error>] = [:]
  private var count = 0
  init() { (requests, requested) = AsyncStream.makeStream() }
  func connect(url: URL) async throws -> any KiteWebSocketConnection {
    count += 1
    let index = count
    return try await withCheckedThrowingContinuation { continuation in
      pending[index] = continuation
      requested.yield(url)
    }
  }
  func complete(_ index: Int, with result: Result<any KiteWebSocketConnection, KiteTickerError>) {
    pending.removeValue(forKey: index)!.resume(with: result.mapError { $0 as any Error })
  }
}

@Test(.timeLimit(.minutes(1)), arguments: [true, false])
func replacedCredentialsFenceOldHandshakeSuccessAndFailure(lateSuccess: Bool) async throws {
  let transport = HandshakeGate()
  let ticker = try KiteTicker(apiKey: "old", accessToken: "old", transport: transport)
  var requests = transport.requests.makeAsyncIterator()
  let connecting = Task { try await ticker.connect() }
  _ = await requests.next()
  let replacing = Task { try await ticker.replaceCredentials(apiKey: "new", accessToken: "new") }
  let newURL = try #require(await requests.next())
  #expect(newURL.absoluteString.contains("access_token=new"))
  let fresh = ControlledSocket()
  let stale = ControlledSocket()
  await transport.complete(2, with: .success(fresh))
  try await replacing.value
  await transport.complete(
    1, with: lateSuccess ? .success(stale) : .failure(.handshakeRejected(statusCode: 403)))
  await #expect(throws: CancellationError.self) { try await connecting.value }
  if lateSuccess {
    var oldMessages = stale.messages.makeAsyncIterator()
    #expect(try await oldMessages.next() == nil)
  }
  try await ticker.subscribe([1], mode: .quote)
  #expect(await stale.sent().isEmpty)
  #expect(await fresh.sent().count == 2)
  await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1))) func disconnectFencesLateRecoveryHandshakeAndClosesEveryStream()
  async throws
{
  let transport = HandshakeGate()
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token", transport: transport, sleeper: time)
  let ltp = try await ticker.ticks()
  let market = try await ticker.marketTicks()
  let orders = try await ticker.orderUpdates()
  let broker = try await ticker.brokerEvents()
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  var requests = transport.requests.makeAsyncIterator()
  let connecting = Task { try await ticker.connect() }
  _ = await requests.next()
  let first = ControlledSocket()
  await transport.complete(1, with: .success(first))
  try await connecting.value
  _ = try await events.next()
  first.incoming.finish()
  #expect(try await events.next() == .possibleDataGap)
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await time.advance()
  _ = await requests.next()
  await ticker.disconnect()
  #expect(try await events.next() == .disconnected)
  #expect(try await events.next() == nil)
  var a = ltp.makeAsyncIterator()
  var b = market.makeAsyncIterator()
  var c = orders.makeAsyncIterator()
  var d = broker.makeAsyncIterator()
  #expect(try await a.next() == nil)
  #expect(try await b.next() == nil)
  #expect(try await c.next() == nil)
  #expect(try await d.next() == nil)
  let late = ControlledSocket()
  await transport.complete(2, with: .success(late))
  var messages = late.messages.makeAsyncIterator()
  #expect(try await messages.next() == nil)
  await #expect(throws: KiteTickerError.notConnected) { try await ticker.subscribe([1]) }
}

@Test(.timeLimit(.minutes(1))) func recoveryExhaustionIsExplicit() async throws {
  let first = ControlledSocket()
  let transport = RecoveryTransport([.success(first), .failure(.connectionClosed)])
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token", transport: transport,
    reconnectPolicy: .init(maximumAttempts: 1), sleeper: time)
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  try await ticker.connect()
  _ = try await events.next()
  first.incoming.finish()
  _ = try await events.next()
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await time.advance()
  #expect(try await events.next() == .recoveryExhausted)
  try await ticker.subscribe([1], mode: .full)
  await ticker.disconnect()
  #expect(try await events.next() == .disconnected)
}

actor CloseGateSocket: KiteWebSocketConnection {
  nonisolated let messages: AsyncThrowingStream<KiteWebSocketMessage, any Error>
  nonisolated let incoming: AsyncThrowingStream<KiteWebSocketMessage, any Error>.Continuation
  nonisolated let closing: AsyncStream<Void>
  private let started: AsyncStream<Void>.Continuation
  private var pending: CheckedContinuation<Void, Never>?
  init() {
    (messages, incoming) = AsyncThrowingStream.makeStream()
    (closing, started) = AsyncStream.makeStream()
  }
  func send(text: String) async throws {}
  func close() async {
    incoming.finish()
    await withCheckedContinuation { continuation in
      pending = continuation
      started.yield(())
    }
  }
  func finishClose() {
    pending?.resume()
    pending = nil
  }
}

@Test(.timeLimit(.minutes(1))) func cancellingCredentialReplacementDuringCloseStopsTicker()
  async throws
{
  let old = CloseGateSocket()
  let transport = RecoveryTransport([.success(old)])
  let ticker = try KiteTicker(apiKey: "key", accessToken: "old", transport: transport)
  try await ticker.connect()
  let replacing = Task { try await ticker.replaceCredentials(apiKey: "key", accessToken: "fresh") }
  var closing = old.closing.makeAsyncIterator()
  _ = await closing.next()
  replacing.cancel()
  await old.finishClose()
  await #expect(throws: CancellationError.self) { try await replacing.value }
  await #expect(throws: KiteTickerError.notConnected) { try await ticker.subscribe([1]) }
  await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1)))
func recoveredConnectionDeliversAllBinaryModesAndTextWithSubscriberOnlyOverflow() async throws {
  let first = ControlledSocket()
  let fresh = ControlledSocket()
  let time = RecoverySleeper()
  let transport = RecoveryTransport([.success(first), .success(fresh)])
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token", transport: transport, sleeper: time)
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  var healthy = try await ticker.marketTicks().makeAsyncIterator()
  var slow = try await ticker.marketTicks(bufferCapacity: 1).makeAsyncIterator()
  var orders = try await ticker.orderUpdates().makeAsyncIterator()
  var broker = try await ticker.brokerEvents().makeAsyncIterator()
  try await ticker.connect()
  _ = try await events.next()
  try await ticker.subscribe([257], mode: .ltp)
  try await ticker.subscribe([513], mode: .quote)
  try await ticker.subscribe([769], mode: .full)
  first.incoming.finish(throwing: KiteTickerError.transport("controlled failure"))
  #expect(try await events.next() == .possibleDataGap)
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await time.advance()
  #expect(try await events.next() == .reconnected)
  let writes = try await fresh.sent().map {
    try JSONSerialization.jsonObject(with: Data($0.utf8)) as! NSDictionary
  }
  #expect(
    writes == [
      ["a": "subscribe", "v": [257, 513, 769]] as NSDictionary,
      ["a": "mode", "v": ["ltp", [257]]] as NSDictionary,
      ["a": "mode", "v": ["quote", [513]]] as NSDictionary,
      ["a": "mode", "v": ["full", [769]]] as NSDictionary,
    ])
  for length in [8, 28, 32, 44, 184] {
    fresh.incoming.yield(
      .binary(
        Data(
          [0, 1, 0, UInt8(length), 0, 0, 1, 1, 0, 0, 0, 123]
            + Array(repeating: 0, count: length - 8))))
    let tick = try #require(try await healthy.next())
    #expect(tick.lastPrice == Decimal(string: "1.23"))
    switch (length, tick.details) {
    case (8, .ltp), (28, .indexQuote), (32, .indexFull), (44, .quote), (184, .full): break
    default: Issue.record("Recovered packet lost its binary mode")
    }
  }
  _ = try await slow.next()
  await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await slow.next() }
  fresh.incoming.yield(.text(orderUpdateFixture))
  #expect(try await orders.next()?.update.orderID == "220303000308932")
  fresh.incoming.yield(.text(#"{"type":"error","data":"Invalid subscription"}"#))
  #expect(try await broker.next() == .serverError("Invalid subscription"))
  try await ticker.setMode(.quote, for: [257])
  await #expect(throws: KiteTickerError.alreadyConnected) { try await ticker.connect() }
  await ticker.disconnect()
}

actor RestoreGateSocket: KiteWebSocketConnection {
  nonisolated let messages: AsyncThrowingStream<KiteWebSocketMessage, any Error>
  private let incoming: AsyncThrowingStream<KiteWebSocketMessage, any Error>.Continuation
  nonisolated let writing: AsyncStream<Void>
  private let started: AsyncStream<Void>.Continuation
  private var pending: CheckedContinuation<Void, Never>?
  private var writes: [String] = []
  init() {
    (messages, incoming) = AsyncThrowingStream.makeStream()
    (writing, started) = AsyncStream.makeStream()
  }
  func send(text: String) async throws {
    writes.append(text)
    if writes.count == 1 {
      await withCheckedContinuation { continuation in
        pending = continuation
        started.yield(())
      }
    }
  }
  func releaseWrite() {
    pending?.resume()
    pending = nil
  }
  func sent() -> [String] { writes }
  func close() async {
    releaseWrite()
    incoming.finish()
  }
}

@Test(.timeLimit(.minutes(1)))
func desiredChangesDuringRestorationAreAppliedBeforeReconnectedEvent() async throws {
  let first = ControlledSocket()
  let fresh = RestoreGateSocket()
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token",
    transport: RecoveryTransport([.success(first), .success(fresh)]), sleeper: time)
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  try await ticker.connect()
  _ = try await events.next()
  try await ticker.subscribe([1], mode: .full)
  first.incoming.finish()
  _ = try await events.next()
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await time.advance()
  var writing = fresh.writing.makeAsyncIterator()
  _ = await writing.next()
  try await ticker.unsubscribe([1])
  try await ticker.subscribe([2], mode: .quote)
  try await ticker.setMode(.ltp, for: [2])
  await fresh.releaseWrite()
  #expect(try await events.next() == .reconnected)
  let commands = try await fresh.sent().map {
    try JSONSerialization.jsonObject(with: Data($0.utf8)) as! NSDictionary
  }
  #expect(
    Array(commands.suffix(3)) == [
      ["a": "unsubscribe", "v": [1]] as NSDictionary,
      ["a": "subscribe", "v": [2]] as NSDictionary,
      ["a": "mode", "v": ["ltp", [2]]] as NSDictionary,
    ])
  await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1)))
func disconnectCancelsRetrySleepAndExplicitConnectStartsFreshGeneration() async throws {
  let first = ControlledSocket()
  let fresh = ControlledSocket()
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token",
    transport: RecoveryTransport([.success(first), .success(fresh)]), sleeper: time)
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  try await ticker.connect()
  _ = try await events.next()
  first.incoming.finish()
  _ = try await events.next()
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await ticker.disconnect()
  var cancelled = time.cancellations.makeAsyncIterator()
  _ = await cancelled.next()
  await time.advance()
  #expect(try await events.next() == .disconnected)
  try await ticker.connect()
  try await ticker.subscribe([2])
  #expect(await fresh.sent().count == 2)
  await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1)))
func replacingCredentialsFencesPendingRecoveryAndClosesPreviousConnection() async throws {
  let transport = HandshakeGate()
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "old", transport: transport, sleeper: time)
  var requests = transport.requests.makeAsyncIterator()
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  let initial = Task { try await ticker.connect() }
  _ = await requests.next()
  let first = ControlledSocket()
  await transport.complete(1, with: .success(first))
  try await initial.value
  _ = try await events.next()
  try await ticker.subscribe([1], mode: .full)
  first.incoming.finish()
  _ = try await events.next()
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await time.advance()
  _ = await requests.next()  // old session's recovery is now suspended in the handshake
  let replacement = Task { try await ticker.replaceCredentials(apiKey: "key", accessToken: "new") }
  let url = try #require(await requests.next())
  #expect(url.absoluteString.contains("access_token=new"))
  let fresh = ControlledSocket()
  let stale = ControlledSocket()
  await transport.complete(3, with: .success(fresh))
  try await replacement.value
  await transport.complete(2, with: .success(stale))
  var closed = stale.messages.makeAsyncIterator()
  #expect(try await closed.next() == nil)
  #expect(await stale.sent().isEmpty)
  #expect(await fresh.sent().count == 2)
  try await ticker.setMode(.quote, for: [1])
  await ticker.disconnect()
}

@Test(arguments: [
  KiteTickerReconnectPolicy(initialDelay: .zero),
  KiteTickerReconnectPolicy(initialDelay: .seconds(2), maximumDelay: .seconds(1)),
  KiteTickerReconnectPolicy(maximumDelay: .seconds(3601)),
  KiteTickerReconnectPolicy(maximumAttempts: -1),
]) func invalidReconnectBoundsAreRejected(policy: KiteTickerReconnectPolicy) throws {
  #expect(throws: KiteTickerError.self) {
    try KiteTicker(
      apiKey: "key", accessToken: "token", transport: ControlledWebSocket(), reconnectPolicy: policy
    )
  }
}

@Test(.timeLimit(.minutes(1)))
func authenticationFailureDuringRecoveryStopsBudgetUntilFreshCredentials() async throws {
  let old = ControlledSocket()
  let fresh = ControlledSocket()
  let time = RecoverySleeper()
  let transport = RecoveryTransport([
    .success(old), .failure(.handshakeRejected(statusCode: 403)), .success(fresh),
  ])
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "old", transport: transport, sleeper: time)
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  try await ticker.connect()
  _ = try await events.next()
  old.incoming.finish()
  _ = try await events.next()
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await time.advance()
  #expect(try await events.next() == .authenticationRequired)
  await #expect(throws: KiteTickerError.authenticationRequired) { try await ticker.connect() }
  try await ticker.replaceCredentials(apiKey: "key", accessToken: "fresh")
  #expect(try await events.next() == .reconnected)
  await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1))) func replacementClosesActiveSocketAndFencesPendingSubscriptionWrite()
  async throws
{
  let old = RestoreGateSocket()
  let fresh = ControlledSocket()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "old",
    transport: RecoveryTransport([.success(old), .success(fresh)]))
  try await ticker.connect()
  let subscribing = Task { try await ticker.subscribe([1], mode: .full) }
  var writing = old.writing.makeAsyncIterator()
  _ = await writing.next()
  try await ticker.replaceCredentials(apiKey: "key", accessToken: "new")
  await #expect(throws: CancellationError.self) { try await subscribing.value }
  #expect(await old.sent().count == 1)  // The stale session never receives the mode command.
  var closed = old.messages.makeAsyncIterator()
  #expect(try await closed.next() == nil)
  #expect(await fresh.sent().count == 2)
  await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1)))
func lifecycleOverflowIsSubscriberOnlyAndZeroAttemptsEmitsExhaustion() async throws {
  let old = ControlledSocket()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "old",
    transport: RecoveryTransport([.success(old)]), reconnectPolicy: .init(maximumAttempts: 0))
  var slow = try await ticker.lifecycleEvents(bufferCapacity: 1).makeAsyncIterator()
  var healthy = try await ticker.lifecycleEvents().makeAsyncIterator()
  try await ticker.connect()
  #expect(try await healthy.next() == .connected)
  old.incoming.finish()
  #expect(try await healthy.next() == .possibleDataGap)
  #expect(try await healthy.next() == .recoveryExhausted)
  #expect(try await slow.next() == .connected)
  await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await slow.next() }
  await ticker.disconnect()
  #expect(try await healthy.next() == .disconnected)
}

@Test func disconnectDoesNotUnlockRejectedCredentials() async throws {
  let fresh = ControlledSocket()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "expired",
    transport: RecoveryTransport([.failure(.handshakeRejected(statusCode: 403)), .success(fresh)]))
  await #expect(throws: KiteTickerError.handshakeRejected(statusCode: 403)) {
    try await ticker.connect()
  }
  await ticker.disconnect()
  await #expect(throws: KiteTickerError.authenticationRequired) { try await ticker.connect() }
  try await ticker.replaceCredentials(apiKey: "key", accessToken: "fresh")
  try await ticker.connect()
  try await ticker.subscribe([1])
  #expect(await fresh.sent().count == 2)
  await ticker.disconnect()
}

struct WriteFailureSocket: KiteWebSocketConnection {
  let socket = ControlledSocket()
  var messages: AsyncThrowingStream<KiteWebSocketMessage, any Error> { socket.messages }
  func send(text: String) async throws {
    throw KiteTickerError.transport("controlled write failure")
  }
  func close() async { await socket.close() }
}

@Test(.timeLimit(.minutes(1))) func failedSubscriptionWriteStillRestoresDesiredTokenAndMode()
  async throws
{
  let fresh = ControlledSocket()
  let time = RecoverySleeper()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token",
    transport: RecoveryTransport([.success(WriteFailureSocket()), .success(fresh)]), sleeper: time)
  var events = try await ticker.lifecycleEvents().makeAsyncIterator()
  try await ticker.connect()
  _ = try await events.next()
  await #expect(throws: KiteTickerError.transport("controlled write failure")) {
    try await ticker.subscribe([257], mode: .full)
  }
  #expect(try await events.next() == .possibleDataGap)
  var delays = time.delays.makeAsyncIterator()
  _ = await delays.next()
  await time.advance()
  #expect(try await events.next() == .reconnected)
  let commands = try await fresh.sent().map {
    try JSONSerialization.jsonObject(with: Data($0.utf8)) as! NSDictionary
  }
  #expect(
    commands == [
      ["a": "subscribe", "v": [257]] as NSDictionary,
      ["a": "mode", "v": ["full", [257]]] as NSDictionary,
    ])
  await ticker.disconnect()
}
