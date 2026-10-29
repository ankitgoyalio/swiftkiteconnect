//
//  SandboxStreamingVerification.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

/// A real sandbox socket with an application-controlled interruption seam.
actor SandboxInterruptibleTransport: KiteWebSocketTransport {
    private var latest: any KiteWebSocketConnection?

    func connect(url: URL) async throws -> any KiteWebSocketConnection {
        let connection = try await NIOKiteWebSocketTransport().connect(url: url)
        latest = connection
        return connection
    }

    func interrupt() async {
        await latest?.close()
    }
}

func sandboxTicker(
    session: SandboxSessionInput,
    transport: any KiteWebSocketTransport = NIOKiteWebSocketTransport(),
) throws -> KiteTicker {
    try KiteTicker(
        apiKey: "sandboxdemo", accessToken: session.accessToken, userID: session.userID,
        endpoint: URL(string: "wss://ws-sandbox.kite.trade")!, transport: transport,
        reconnectPolicy: .init(initialDelay: .seconds(1), maximumDelay: .seconds(2), maximumAttempts: 2),
    )
}

func sandboxRequireTick(
    _ stream: AsyncThrowingStream<KiteMarketTick, any Error>, token: UInt32, mode: KiteTickerMode,
) async throws {
    for try await tick in stream where tick.instrumentToken == token {
        switch (mode, tick.details) {
        case (.ltp, .ltp), (.quote, .quote), (.full, .full): return
        default: continue
        }
    }
    throw SandboxVerificationFailure.tickTimeout
}

func sandboxRecoveryCheck(session: SandboxSessionInput, token: UInt32, mode: KiteTickerMode) async throws {
    let transport = SandboxInterruptibleTransport()
    let ticker = try sandboxTicker(session: session, transport: transport)
    let timeout = Task {
        try await Task.sleep(for: .seconds(45))
        await ticker.disconnect()
    }
    do {
        var lifecycle = try await ticker.lifecycleEvents().makeAsyncIterator()
        let initial = try await ticker.marketTicks()
        try await ticker.connect()
        guard try await lifecycle.next() == .connected else { throw SandboxVerificationFailure.unexpectedReceipt }
        try await ticker.subscribe([token], mode: mode)
        try await sandboxRequireTick(initial, token: token, mode: mode)
        await transport.interrupt()
        guard try await lifecycle.next() == .possibleDataGap,
              try await lifecycle.next() == .reconnected else { throw SandboxVerificationFailure.unexpectedReceipt }
        // Register after recovery, so buffered pre-interruption ticks cannot pass.
        let recovered = try await ticker.marketTicks()
        try await sandboxRequireTick(recovered, token: token, mode: mode)
        timeout.cancel()
        await ticker.disconnect()
    } catch {
        timeout.cancel()
        await ticker.disconnect()
        throw error
    }
}

func sandboxReplacementCheck(
    session: SandboxSessionInput, replacement: SandboxSessionInput, token: UInt32,
) async throws {
    guard session.accessToken != replacement.accessToken else { throw SandboxVerificationFailure.unexpectedReceipt }
    let ticker = try sandboxTicker(session: session)
    let timeout = Task {
        try await Task.sleep(for: .seconds(45))
        await ticker.disconnect()
    }
    do {
        var lifecycle = try await ticker.lifecycleEvents().makeAsyncIterator()
        let initial = try await ticker.marketTicks()
        try await ticker.connect()
        guard try await lifecycle.next() == .connected else { throw SandboxVerificationFailure.unexpectedReceipt }
        try await ticker.subscribe([token], mode: .full)
        try await sandboxRequireTick(initial, token: token, mode: .full)
        try await ticker.replaceCredentials(
            apiKey: "sandboxdemo", accessToken: replacement.accessToken, userID: replacement.userID,
        )
        guard try await lifecycle.next() == .possibleDataGap,
              try await lifecycle.next() == .reconnected else { throw SandboxVerificationFailure.unexpectedReceipt }
        try await sandboxRequireTick(ticker.marketTicks(), token: token, mode: .full)
        timeout.cancel()
        await ticker.disconnect()
    } catch {
        timeout.cancel()
        await ticker.disconnect()
        throw error
    }
}

actor SandboxOrderEvents {
    private var events: [KiteOrderUpdateEvent] = []
    func append(_ event: KiteOrderUpdateEvent) {
        events.append(event)
    }

    func received(orderID: String, status: KiteOrderStatus) -> Bool {
        events.contains { $0.update.orderID == orderID && $0.update.status == status }
    }
}

/// Observes wire shapes without retaining account, order, or credential values.
actor SandboxWireShapes {
    private var shapes: [String: Int] = [:]

    func record(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            shapes["non-JSON text", default: 0] += 1
            return
        }
        let type = object["type"] as? String ?? "missing"
        let safeType = ["order", "error", "message"].contains(type) ? type : "other"
        let knownFields: Set = ["order_id", "status", "exchange", "tradingsymbol", "quantity", "filled_quantity"]
        let fields: String
        if let data = object["data"] as? [String: Any] {
            let keys = Set(data.keys)
            fields = keys.intersection(knownFields).sorted().joined(separator: ",")
                + "; other fields: \(keys.subtracting(knownFields).count)"
        } else {
            fields = "non-object"
        }
        shapes["\(safeType): \(fields)", default: 0] += 1
    }

    func summary() -> [String: Int] {
        shapes
    }
}

struct SandboxObservedTransport: KiteWebSocketTransport {
    let shapes: SandboxWireShapes

    func connect(url: URL) async throws -> any KiteWebSocketConnection {
        let socket = try await NIOKiteWebSocketTransport().connect(url: url)
        return SandboxObservedConnection(socket: socket, shapes: shapes)
    }
}

private struct SandboxObservedConnection: KiteWebSocketConnection {
    let socket: any KiteWebSocketConnection
    let messages: AsyncThrowingStream<KiteWebSocketMessage, any Error>
    let forwarding: Task<Void, Never>

    init(socket: any KiteWebSocketConnection, shapes: SandboxWireShapes) {
        self.socket = socket
        let (stream, continuation) = AsyncThrowingStream<KiteWebSocketMessage, any Error>.makeStream(
            bufferingPolicy: .bufferingOldest(256),
        )
        messages = stream
        forwarding = Task {
            do {
                for try await message in socket.messages {
                    if case let .text(text) = message {
                        await shapes.record(text)
                    }
                    if case .dropped = continuation.yield(message) {
                        continuation.finish(throwing: KiteTickerError.bufferOverflow)
                        await socket.close()
                        return
                    }
                }
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
    }

    func send(text: String) async throws {
        try await socket.send(text: text)
    }

    func close() async {
        await socket.close()
        forwarding.cancel()
        await forwarding.value
    }
}
