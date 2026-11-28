import Foundation
import KiteConnect
import Testing

struct TickerReconnectTests {
    @Test func restoresLatestSubscriptionsBeforeDeliveringRecoveredTicks() async throws {
        let receivedTick = AsyncStream<Void>.makeStream()
        let replayed = AsyncStream<Void>.makeStream()
        try await LoopbackWebSocket.run(servers: [
            { peer in
                _ = try await peer.acceptUpgrade()
                try await Self.expectCommand(#"{"a":"subscribe","v":[10,20]}"#, from: peer)
                try await Self.expectCommand(#"{"a":"mode","v":["ltp",[10,20]]}"#, from: peer)
                try await peer.sendFrame(opcode: 2, payload: Self.tick(for: 10))
                var receipt = receivedTick.stream.makeAsyncIterator()
                _ = await receipt.next()
                // Returning closes the TCP connection without a WebSocket close handshake.
            },
            { peer in
                _ = try await peer.acceptUpgrade()
                try await Self.expectCommand(#"{"a":"subscribe","v":[20,30]}"#, from: peer)
                try await Self.expectCommand(#"{"a":"mode","v":["ltp",[30]]}"#, from: peer)
                try await Self.expectCommand(#"{"a":"mode","v":["full",[20]]}"#, from: peer)
                replayed.continuation.yield(())
                try await peer.sendFrame(opcode: 2, payload: Self.tick(for: 30))
                let close = try await peer.readFrame()
                #expect(close.opcode == 8)
                try await peer.sendFrame(opcode: 8, payload: close.payload)
            },
        ]) { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            try await ticker.subscribe([10, 20], mode: .ltp)
            try #expect(await events.next() == .ticks([.init(instrumentToken: 10, lastPrice: 1)]))
            receivedTick.continuation.yield(())
            try await Self.expectInterruption(from: &events)
            try await ticker.unsubscribe([10])
            try await ticker.setMode(.full, for: [20])
            try await ticker.subscribe([30], mode: .ltp)
            var replay = replayed.stream.makeAsyncIterator()
            _ = await replay.next()
            try #expect(await events.next() == .recovered)
            try #expect(await events.next() == .ticks([.init(instrumentToken: 30, lastPrice: 1)]))
            await ticker.close()
            try #expect(await events.next() == nil)
        }
    }

    @Test func treatsAWebSocketPolicyCloseAsTerminal() async throws {
        let connected = AsyncStream<Void>.makeStream()
        try await LoopbackWebSocket.run { peer in
            _ = try await peer.acceptUpgrade()
            var ready = connected.stream.makeAsyncIterator()
            _ = await ready.next()
            let policyViolation = Data([0x03, 0xF0])
            try await peer.sendFrame(opcode: 8, payload: policyViolation)
            _ = try? await peer.readFrame()
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            connected.continuation.yield(())
            await #expect(throws: KiteTickerError.socketClosed(code: 1008)) {
                _ = try await events.next()
            }
            try #expect(await events.next() == nil)
        }
    }

    @Test func backsOffAfterTransientUpgradeFailureAndStopsOnAuthenticationRejection() async throws {
        let connected = AsyncStream<Void>.makeStream()
        let rejected = AsyncStream<ContinuousClock.Instant>.makeStream()
        try await LoopbackWebSocket.run(servers: [
            { peer in
                _ = try await peer.acceptUpgrade()
                var ready = connected.stream.makeAsyncIterator()
                _ = await ready.next()
            },
            { peer in
                rejected.continuation.yield(.now)
                try await peer.rejectUpgrade(status: "503 Service Unavailable")
            },
            { peer in
                var times = rejected.stream.makeAsyncIterator()
                let firstRetry = try #require(await times.next())
                #expect(firstRetry.duration(to: .now) >= .seconds(2))
                try await peer.rejectUpgrade(status: "401 Unauthorized")
            },
        ]) { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            let disconnected = ContinuousClock.now
            connected.continuation.yield(())
            try await Self.expectInterruption(from: &events)
            await #expect(throws: KiteTickerError.http(statusCode: 401)) {
                _ = try await events.next()
            }
            #expect(disconnected.duration(to: .now) >= .seconds(3))
            try #expect(await events.next() == nil)
        }
    }

    @Test func closeCancelsBackoffAndFinishesTheStream() async throws {
        let connected = AsyncStream<Void>.makeStream()
        try await LoopbackWebSocket.run { peer in
            _ = try await peer.acceptUpgrade()
            var ready = connected.stream.makeAsyncIterator()
            _ = await ready.next()
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            connected.continuation.yield(())
            try await Self.expectInterruption(from: &events)
            await ticker.close()
            try #expect(await events.next() == nil)
            await #expect(throws: KiteTickerError.closed) {
                try await ticker.subscribe([10], mode: .ltp)
            }
            // Leave the listener up past the first retry deadline to detect stray reconnects.
            try await Task.sleep(for: .milliseconds(1200))
        }
    }

    @Test func closeCancelsAnInFlightReconnectUpgrade() async throws {
        let connected = AsyncStream<Void>.makeStream()
        let upgrading = AsyncStream<Void>.makeStream()
        try await LoopbackWebSocket.run(servers: [
            { peer in
                _ = try await peer.acceptUpgrade()
                var ready = connected.stream.makeAsyncIterator()
                _ = await ready.next()
            },
            { peer in
                try await peer.readUpgradeRequest()
                upgrading.continuation.yield(())
                await #expect(throws: LoopbackWebSocket.Failure.unexpectedEOF) {
                    _ = try await peer.readFrame()
                }
            },
        ]) { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            async let consume: Void = {
                var events = ticker.makeAsyncIterator()
                try #expect(await events.next() == .connected)
                connected.continuation.yield(())
                try await Self.expectInterruption(from: &events)
                try #expect(await events.next() == nil)
            }()
            var upgrades = upgrading.stream.makeAsyncIterator()
            _ = await upgrades.next()
            await ticker.close()
            try await consume
        }
    }

    private static func expectInterruption(from events: inout KiteTicker.AsyncIterator) async throws {
        guard case .interrupted = try await events.next() else {
            Issue.record("Expected an interruption after the TCP disconnect")
            return
        }
    }

    private static func expectCommand(_ expected: String, from peer: LoopbackWebSocket.Peer) async throws {
        let frame = try await peer.readFrame()
        #expect(frame.opcode == 1)
        let command = try #require(JSONSerialization.jsonObject(with: frame.payload) as? NSDictionary)
        let expected = try #require(JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary)
        #expect(command == expected)
    }

    private static func tick(for token: UInt8) -> Data {
        Data([0, 1, 0, 8, 0, 0, 0, token, 0, 0, 0, 100])
    }
}
