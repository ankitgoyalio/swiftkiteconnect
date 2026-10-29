//
//  TickerTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Synchronization
import Testing

actor ControlledSocket: KiteWebSocketConnection {
    nonisolated let messages: AsyncThrowingStream<KiteWebSocketMessage, any Error>
    nonisolated let incoming: AsyncThrowingStream<KiteWebSocketMessage, any Error>.Continuation
    private var writes: [String] = []
    init() {
        (messages, incoming) = AsyncThrowingStream.makeStream()
    }

    func send(text: String) async throws {
        writes.append(text)
    }

    func close() async {
        incoming.finish()
    }

    func sent() -> [String] {
        writes
    }
}

actor ControlledWebSocket: KiteWebSocketTransport {
    let socket = ControlledSocket()
    var urls: [URL] = []
    func connect(url: URL) async throws -> any KiteWebSocketConnection {
        urls.append(url)
        return socket
    }
}

@Test func tickerConnectsSandboxAndReceivesDecimalLTP() async throws {
    let transport = ControlledWebSocket()
    let ticker = try KiteTicker(
        apiKey: "demo key", accessToken: "demo+token", userID: "AB1234",
        endpoint: URL(string: "wss://ws-sandbox.kite.trade")!, transport: transport,
    )
    let ticks = try await ticker.ticks(bufferCapacity: 4)
    try await ticker.connect()
    try await ticker.subscribe([408_065])
    let url = try #require(await transport.urls.first)
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
    #expect(url.absoluteString.contains("access_token=demo%2Btoken"))
    #expect(query.contains(URLQueryItem(name: "user_id", value: "AB1234")))
    #expect(query.contains(URLQueryItem(name: "access_token", value: "demo+token")))
    let socket = transport.socket
    socket.incoming.yield(.binary(Data([0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 48, 57])))
    var iterator = ticks.makeAsyncIterator()
    let tick = try #require(try await iterator.next())
    #expect(tick.instrumentToken == 408_065)
    #expect(tick.lastPrice == Decimal(string: "123.45"))
    let commands = await socket.sent()
    #expect(commands.count == 2)
    #expect(
        try JSONSerialization.jsonObject(with: Data(commands[0].utf8)) as? NSDictionary == [
            "a": "subscribe", "v": [408_065],
        ] as NSDictionary,
    )
    #expect(
        try JSONSerialization.jsonObject(with: Data(commands[1].utf8)) as? NSDictionary == [
            "a": "mode", "v": ["ltp", [408_065]],
        ] as NSDictionary,
    )
    await ticker.disconnect()
    #expect(try await iterator.next() == nil)
}

@Test func tickerDecodesCurrencyDivisorsAndHeartbeatInMultiPacketMessage() async throws {
    let transport = ControlledWebSocket()
    let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
    let ticks = try await ticker.ticks()
    try await ticker.connect()
    let socket = transport.socket
    socket.incoming.yield(.binary(Data([0])))
    // Official SDK segment IDs: CDS=3, BCD=6, NCO=12, indices=9. Prices 123456789 / divisor.
    socket.incoming.yield(
        .binary(
            Data([
                0, 4,
                0, 8, 0, 0, 1, 3, 7, 91, 205, 21,
                0, 8, 0, 0, 1, 6, 7, 91, 205, 21,
                0, 8, 0, 0, 1, 12, 7, 91, 205, 21,
                0, 8, 0, 0, 1, 9, 7, 91, 205, 21,
            ]),
        ),
    )
    var iterator = ticks.makeAsyncIterator()
    #expect(try await iterator.next()?.lastPrice == Decimal(string: "12.3456789"))
    #expect(try await iterator.next()?.lastPrice == Decimal(string: "12345.6789"))
    #expect(try await iterator.next()?.lastPrice == Decimal(string: "12345.6789"))
    #expect(try await iterator.next()?.lastPrice == Decimal(string: "1234567.89"))
    await ticker.disconnect()
}

private func sampleLTP(_ price: UInt8 = 1) -> KiteWebSocketMessage {
    .binary(Data([0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 0, price]))
}

@Test func slowSubscriberOverflowAndCancellationLeaveHealthyConsumerRunning() async throws {
    let transport = ControlledWebSocket()
    let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
    let slow = try await ticker.ticks(bufferCapacity: 1)
    let healthy = try await ticker.ticks(bufferCapacity: 8)
    let cancelled = try await ticker.ticks(bufferCapacity: 1)
    let waiting = Task {
        var iterator = cancelled.makeAsyncIterator()
        return try await iterator.next()
    }
    waiting.cancel()
    #expect(try await waiting.value == nil)
    try await ticker.connect()
    let socket = transport.socket
    var consumer = healthy.makeAsyncIterator()
    socket.incoming.yield(sampleLTP(1))
    #expect(try await consumer.next()?.lastPrice == Decimal(string: "0.01"))
    socket.incoming.yield(sampleLTP(2))
    #expect(try await consumer.next()?.lastPrice == Decimal(string: "0.02"))
    var lagging = slow.makeAsyncIterator()
    #expect(try await lagging.next()?.lastPrice == Decimal(string: "0.01"))
    await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await lagging.next() }
    socket.incoming.yield(sampleLTP(3))
    #expect(try await consumer.next()?.lastPrice == Decimal(string: "0.03"))
    await ticker.disconnect()
    #expect(try await consumer.next() == nil)
}

actor PausedWebSocketTransport: KiteWebSocketTransport {
    nonisolated let started: AsyncStream<Void>
    nonisolated let accepted: AsyncStream<Void>.Continuation
    nonisolated let release: AsyncStream<Void>
    nonisolated let resume: AsyncStream<Void>.Continuation
    nonisolated let cancelled = Synchronization.Mutex(false)
    let socket = ControlledSocket()
    init() {
        (started, accepted) = AsyncStream.makeStream()
        (release, resume) = AsyncStream.makeStream()
    }

    func connect(url _: URL) async throws -> any KiteWebSocketConnection {
        accepted.yield(())
        return try await withTaskCancellationHandler {
            for await _ in release {}
            try Task.checkCancellation()
            return socket
        } onCancel: {
            cancelled.withLock { $0 = true }
        }
    }
}

@Test func disconnectCancelsPendingConnectAndFencesLateSuccess() async throws {
    let transport = PausedWebSocketTransport()
    let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
    let connecting = Task { try await ticker.connect() }
    var started = transport.started.makeAsyncIterator()
    _ = await started.next()
    await ticker.disconnect()
    #expect(transport.cancelled.withLock { $0 })
    transport.resume.finish()
    await #expect(throws: CancellationError.self) { try await connecting.value }
    await #expect(throws: KiteTickerError.notConnected) { try await ticker.subscribe([408_065]) }
}

@Test(arguments: [
    Data(), Data([0, 1]), Data([0, 1, 0]), Data([0, 1, 0, 8, 0]),
    Data([0, 1, 0, 7, 0, 6, 58, 1, 0, 0, 1]),
    Data([0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 0, 1, 99]),
    Data([0, 2, 0, 8, 0, 6, 58, 1, 0, 0, 0, 1, 0, 8, 0]),
    Data([0, 1, 0, 8, 0, 0, 0, 0, 0, 0, 0, 1]),
]) func malformedBinaryFailsWithoutEmittingPartialTicks(packet: Data) async throws {
    let transport = ControlledWebSocket()
    let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
    let ticks = try await ticker.ticks()
    try await ticker.connect()
    let socket = transport.socket
    socket.incoming.yield(.binary(packet))
    var iterator = ticks.makeAsyncIterator()
    await #expect(throws: KiteTickerError.self) { _ = try await iterator.next() }
    await ticker.disconnect()
}

@Test func subscribeUnsubscribeValidationAndIndependentTickers() async throws {
    let a = ControlledWebSocket()
    let b = ControlledWebSocket()
    let first = try KiteTicker(apiKey: "first", accessToken: "a", transport: a)
    let second = try KiteTicker(apiKey: "second", accessToken: "b", transport: b)
    #expect(throws: KiteTickerError.self) {
        try KiteTicker(
            apiKey: "key", accessToken: "token", endpoint: URL(string: "wss://ws-sandbox.kite.trade")!,
            transport: a,
        )
    }
    await #expect(throws: KiteTickerError.self) { _ = try await first.ticks(bufferCapacity: 0) }
    try await first.connect()
    try await second.connect()
    await #expect(throws: KiteTickerError.alreadyConnected) { try await first.connect() }
    await #expect(throws: KiteTickerError.self) { try await first.subscribe([]) }
    await #expect(throws: KiteTickerError.self) { try await first.subscribe([0]) }
    await #expect(throws: KiteTickerError.self) { try await first.subscribe(Array(1 ... 3001)) }
    try await first.subscribe([408_065])
    try await first.unsubscribe([408_065])
    let socket = a.socket
    let writes = await socket.sent()
    #expect(
        try JSONSerialization.jsonObject(with: Data(writes.last!.utf8)) as? NSDictionary == [
            "a": "unsubscribe", "v": [408_065],
        ] as NSDictionary,
    )
    let secondTicks = try await second.ticks()
    await first.disconnect()
    let otherSocket = b.socket
    otherSocket.incoming.yield(sampleLTP())
    var iterator = secondTicks.makeAsyncIterator()
    #expect(try await iterator.next()?.instrumentToken == 408_065)
    await second.disconnect()
}

actor PausedWriteSocket: KiteWebSocketConnection {
    nonisolated let messages: AsyncThrowingStream<KiteWebSocketMessage, any Error>
    nonisolated let incoming: AsyncThrowingStream<KiteWebSocketMessage, any Error>.Continuation
    nonisolated let started: AsyncStream<Void>
    nonisolated let accepted: AsyncStream<Void>.Continuation
    nonisolated let release: AsyncStream<Void>
    nonisolated let resume: AsyncStream<Void>.Continuation
    private var firstWrite = true
    init() {
        (messages, incoming) = AsyncThrowingStream.makeStream()
        (started, accepted) = AsyncStream.makeStream()
        (release, resume) = AsyncStream.makeStream()
    }

    func send(text _: String) async throws {
        if firstWrite {
            firstWrite = false
            accepted.yield(())
            for await _ in release {}
        }
    }

    func close() async {
        resume.finish()
        incoming.finish()
    }
}

struct PausedWriteTransport: KiteWebSocketTransport {
    let socket = PausedWriteSocket()
    func connect(url _: URL) async throws -> any KiteWebSocketConnection {
        socket
    }
}

@Test func overlappingSubscriptionChangesCannotBypassConnectionLimit() async throws {
    let transport = PausedWriteTransport()
    let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
    try await ticker.connect()
    let first = Task { try await ticker.subscribe(Array(1 ... 2000)) }
    var started = transport.socket.started.makeAsyncIterator()
    _ = await started.next()
    await #expect(throws: KiteTickerError.self) { try await ticker.subscribe(Array(2001 ... 4000)) }
    transport.socket.resume.finish()
    try await first.value
    await ticker.disconnect()
}

@Test func pricesPreserveUnsignedWireRangeAsOfficialSDKDoes() async throws {
    let transport = ControlledWebSocket()
    let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
    let ticks = try await ticker.ticks()
    try await ticker.connect()
    let socket = transport.socket
    socket.incoming.yield(.binary(Data([0, 1, 0, 8, 0, 6, 58, 1, 255, 255, 255, 255])))
    var iterator = ticks.makeAsyncIterator()
    #expect(try await iterator.next()?.lastPrice == Decimal(string: "42949672.95"))
    await ticker.disconnect()
}

@Test(arguments: [28, 32, 44, 184]) func tickerProjectsLTPFromInitialDefaultQuoteBeforeModeChange(
    length: Int,
) async throws {
    let transport = ControlledWebSocket()
    let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
    let ticks = try await ticker.ticks()
    try await ticker.connect()
    try await ticker.subscribe([408_065])
    // Subscribe defaults to quote on the server; its in-flight quote can precede the LTP-mode command.
    let bytes: [UInt8] =
        [0, 1, 0, UInt8(length), 0, 6, 58, 1, 0, 0, 48, 57] + Array(repeating: 0, count: length - 8)
    let socket = transport.socket
    socket.incoming.yield(.binary(Data(bytes)))
    var iterator = ticks.makeAsyncIterator()
    #expect(try await iterator.next()?.lastPrice == Decimal(string: "123.45"))
    await ticker.disconnect()
}
