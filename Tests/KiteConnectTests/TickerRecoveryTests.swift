//
//  TickerRecoveryTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

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
            initialDelay: .seconds(1), maximumDelay: .seconds(3), maximumAttempts: 4,
        ),
        sleeper: time,
    )
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
        ],
    )
    let quotes = try await ticker.ticks()
    recovered.incoming.yield(.binary(Data([0, 1, 0, 8, 0, 0, 0, 3, 0, 0, 0, 1])))
    var ticks = quotes.makeAsyncIterator()
    #expect(try await ticks.next()?.instrumentToken == 3)
    await ticker.disconnect()
    #expect(try await lifecycle.next() == .disconnected)
    #expect(try await lifecycle.next() == nil)
}

@Test(arguments: [401, 403]) func authenticationHandshakeStopsUntilCredentialsAreReplaced(
    status: Int,
) async throws {
    let socket = ControlledSocket()
    let transport = RecoveryTransport([
        .failure(.handshakeRejected(statusCode: status)), .success(socket),
    ])
    let time = RecoverySleeper()
    let ticker = try KiteTicker(
        apiKey: "key", accessToken: "expired", transport: transport, sleeper: time,
    )
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
    ],
)
func explicitAuthenticationTextStopsRecoveryButStillReachesBrokerSubscriber(text: String)
    async throws
{
    let socket = ControlledSocket()
    let fresh = ControlledSocket()
    let transport = RecoveryTransport([.success(socket), .success(fresh)])
    let ticker = try KiteTicker(
        apiKey: "key", accessToken: "old", transport: transport, sleeper: RecoverySleeper(),
    )
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
    private let audit: CloseGateSocket?
    init(audit: CloseGateSocket? = nil) {
        self.audit = audit
        (requests, requested) = AsyncStream.makeStream()
    }

    func connect(url: URL) async throws -> any KiteWebSocketConnection {
        count += 1
        if count > 1, let audit {
            #expect(await audit.isClosed(), "New handshake bypassed stale-result teardown")
        }
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
    var events = try await ticker.lifecycleEvents().makeAsyncIterator()
    let replacing = Task { try await ticker.replaceCredentials(apiKey: "new", accessToken: "new") }
    #expect(try await events.next() == .possibleDataGap)
    let stale = ControlledSocket()
    await transport.complete(
        1, with: lateSuccess ? .success(stale) : .failure(.handshakeRejected(statusCode: 403)),
    )
    let newURL = try #require(await requests.next())
    #expect(newURL.absoluteString.contains("access_token=new"))
    let fresh = ControlledSocket()
    await transport.complete(2, with: .success(fresh))
    try await replacing.value
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
        apiKey: "key", accessToken: "token", transport: transport, sleeper: time,
    )
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
        reconnectPolicy: .init(maximumAttempts: 1), sleeper: time,
    )
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
    private let failWrites: Bool
    private var closed = false
    init(failWrites: Bool = false) {
        self.failWrites = failWrites
        (messages, incoming) = AsyncThrowingStream.makeStream()
        (closing, started) = AsyncStream.makeStream()
    }

    func send(text _: String) async throws {
        if failWrites {
            throw KiteTickerError.transport("Controlled write failure")
        }
    }

    func isClosed() -> Bool {
        closed
    }

    func close() async {
        if closed {
            return
        }
        await withCheckedContinuation { continuation in
            pending = continuation
            started.yield(())
        }
    }

    func finishClose() {
        closed = true
        incoming.finish()
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
        apiKey: "key", accessToken: "token", transport: transport, sleeper: time,
    )
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
        ],
    )
    for length in [8, 28, 32, 44, 184] {
        fresh.incoming.yield(
            .binary(
                Data(
                    [0, 1, 0, UInt8(length), 0, 0, 1, 1, 0, 0, 0, 123]
                        + Array(repeating: 0, count: length - 8),
                ),
            ),
        )
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
