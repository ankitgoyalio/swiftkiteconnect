//
//  TickerSessionRecoveryTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

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

    func sent() -> [String] {
        writes
    }

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
        transport: RecoveryTransport([.success(first), .success(fresh)]), sleeper: time,
    )
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
        ],
    )
    await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1)))
func disconnectCancelsRetrySleepAndExplicitConnectStartsFreshGeneration() async throws {
    let first = ControlledSocket()
    let fresh = ControlledSocket()
    let time = RecoverySleeper()
    let ticker = try KiteTicker(
        apiKey: "key", accessToken: "token",
        transport: RecoveryTransport([.success(first), .success(fresh)]), sleeper: time,
    )
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
        apiKey: "key", accessToken: "old", transport: transport, sleeper: time,
    )
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
    _ = await requests.next() // old session's recovery is now suspended in the handshake
    let replacement = Task { try await ticker.replaceCredentials(apiKey: "key", accessToken: "new") }
    #expect(try await events.next() == .possibleDataGap)
    let stale = ControlledSocket()
    await transport.complete(2, with: .success(stale))
    let url = try #require(await requests.next())
    #expect(url.absoluteString.contains("access_token=new"))
    let fresh = ControlledSocket()
    await transport.complete(3, with: .success(fresh))
    try await replacement.value
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
            apiKey: "key", accessToken: "token", transport: ControlledWebSocket(), reconnectPolicy: policy,
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
        apiKey: "key", accessToken: "old", transport: transport, sleeper: time,
    )
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
        transport: RecoveryTransport([.success(old), .success(fresh)]),
    )
    try await ticker.connect()
    let subscribing = Task { try await ticker.subscribe([1], mode: .full) }
    var writing = old.writing.makeAsyncIterator()
    _ = await writing.next()
    try await ticker.replaceCredentials(apiKey: "key", accessToken: "new")
    await #expect(throws: CancellationError.self) { try await subscribing.value }
    #expect(await old.sent().count == 1) // The stale session never receives the mode command.
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
        transport: RecoveryTransport([.success(old)]), reconnectPolicy: .init(maximumAttempts: 0),
    )
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
        transport: RecoveryTransport([.failure(.handshakeRejected(statusCode: 403)), .success(fresh)]),
    )
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
    var messages: AsyncThrowingStream<KiteWebSocketMessage, any Error> {
        socket.messages
    }

    func send(text _: String) async throws {
        throw KiteTickerError.transport("controlled write failure")
    }

    func close() async {
        await socket.close()
    }
}

@Test(.timeLimit(.minutes(1))) func failedSubscriptionWriteStillRestoresDesiredTokenAndMode()
    async throws
{
    let fresh = ControlledSocket()
    let time = RecoverySleeper()
    let ticker = try KiteTicker(
        apiKey: "key", accessToken: "token",
        transport: RecoveryTransport([.success(WriteFailureSocket()), .success(fresh)]), sleeper: time,
    )
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
        ],
    )
    await ticker.disconnect()
}

/// Reports physical overlap at the transport boundary, independently of ticker state.
actor TeardownAuditTransport: KiteWebSocketTransport {
    let old: CloseGateSocket
    let fresh = ControlledSocket()
    private var count = 0
    init(_ old: CloseGateSocket) {
        self.old = old
    }

    func connect(url _: URL) async throws -> any KiteWebSocketConnection {
        count += 1
        if count == 1 {
            return old
        }
        #expect(await old.isClosed(), "New connection admitted before physical teardown completed")
        return fresh
    }
}

@Test(.timeLimit(.minutes(1)))
func recoveryAdmissionWaitsForPhysicalCloseAfterWriteFailure() async throws {
    let old = CloseGateSocket(failWrites: true)
    let transport = TeardownAuditTransport(old)
    let time = RecoverySleeper()
    let ticker = try KiteTicker(
        apiKey: "key", accessToken: "old", transport: transport, sleeper: time,
    )
    var events = try await ticker.lifecycleEvents().makeAsyncIterator()
    try await ticker.connect()
    _ = try await events.next()
    let writing = Task { try await ticker.subscribe([257]) }
    var closing = old.closing.makeAsyncIterator()
    _ = await closing.next()
    var delays = time.delays.makeAsyncIterator()
    _ = await delays.next()
    await time.advance()
    // Exercise public actor work while close is suspended. No wall-clock delay or private seam.
    for _ in 0 ..< 100 {
        try await ticker.setMode(.quote, for: [257])
    }
    await old.finishClose()
    await #expect(throws: KiteTickerError.transport("Controlled write failure")) {
        try await writing.value
    }
    #expect(try await events.next() == .possibleDataGap)
    #expect(try await events.next() == .reconnected)
    try await ticker.subscribe([513])
    await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1)), arguments: ["disconnect", "failure", "replacement"])
func sessionTransitionsKeepDetachedCloseInAdmissionFence(transition: String) async throws {
    let old = CloseGateSocket(failWrites: transition == "failure")
    let transport = TeardownAuditTransport(old)
    let ticker = try KiteTicker(
        apiKey: "key", accessToken: "old", transport: transport, sleeper: RecoverySleeper(),
    )
    try await ticker.connect()
    let retiring = Task {
        switch transition {
        case "disconnect": await ticker.disconnect()
        case "failure":
            await #expect(throws: KiteTickerError.transport("Controlled write failure")) {
                try await ticker.subscribe([257])
            }
        default:
            await #expect(throws: CancellationError.self) {
                try await ticker.replaceCredentials(apiKey: "key", accessToken: "superseded")
            }
        }
    }
    var closing = old.closing.makeAsyncIterator()
    _ = await closing.next()
    let entering = Task {
        if transition == "disconnect" {
            try await ticker.connect()
        } else {
            try await ticker.replaceCredentials(apiKey: "key", accessToken: "fresh")
        }
    }
    // Public configuration/command work can continue while the physical socket is closing.
    for _ in 0 ..< 100 {
        _ = try await ticker.lifecycleEvents(bufferCapacity: 1)
    }
    await old.finishClose()
    await retiring.value
    try await entering.value
    try await ticker.subscribe([513])
    #expect(await transport.fresh.sent().count >= 2)
    await ticker.disconnect()
}

@Test(.timeLimit(.minutes(1)), arguments: [true, false])
func lateHandshakeCloseFencesExplicitConnectionAfterDisconnect(lateSuccess: Bool) async throws {
    let stale = CloseGateSocket()
    let transport = HandshakeGate(audit: stale)
    let ticker = try KiteTicker(apiKey: "key", accessToken: "old", transport: transport)
    var requests = transport.requests.makeAsyncIterator()
    let initial = Task { try await ticker.connect() }
    _ = await requests.next()
    await ticker.disconnect()
    if lateSuccess {
        await transport.complete(1, with: .success(stale))
        var closing = stale.closing.makeAsyncIterator()
        _ = await closing.next()
    } else {
        await transport.complete(1, with: .failure(.connectionClosed))
        await stale.finishClose() // No socket was returned; there is no physical resource to retire.
    }
    let entering = Task { try await ticker.connect() }
    for _ in 0 ..< 100 {
        _ = try await ticker.lifecycleEvents(bufferCapacity: 1)
    }
    await stale.finishClose()
    _ = await requests.next()
    let fresh = ControlledSocket()
    await transport.complete(2, with: .success(fresh))
    await #expect(throws: CancellationError.self) { try await initial.value }
    try await entering.value
    try await ticker.subscribe([513])
    #expect(await fresh.sent().count == 2)
    await ticker.disconnect()
}
