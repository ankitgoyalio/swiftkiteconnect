import Foundation
import KiteConnect
import Testing

struct TickerTests {
    @Test func authenticatesAndClosesTheEventSequenceNormally() async throws {
        try await LoopbackWebSocket.run { peer in
            let target = try await peer.acceptUpgrade()
            let fields = try #require(URLComponents(string: target)?.percentEncodedQueryItems)
            #expect(fields == [
                URLQueryItem(name: "api_key", value: "sample%2Bkey%26%3D"),
                URLQueryItem(name: "access_token", value: "sample%20token%2F%25%3F%C3%A9"),
            ])
            do {
                let close = try await peer.readFrame()
                #expect(close.opcode == 8)
                try await peer.sendFrame(opcode: 8, payload: close.payload)
            } catch LoopbackWebSocket.Failure.unexpectedEOF {
                // Foundation can tear down a freshly upgraded connection before writing a frame.
            }
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "sample+key&=", accessToken: "sample token/%?é", url: url)
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            await ticker.close()
            await ticker.close()
            try #expect(await events.next() == nil)
        }
    }

    @Test func sendsSubscriptionCommandsInWireOrder() async throws {
        try await LoopbackWebSocket.run { peer in
            _ = try await peer.acceptUpgrade()
            for expected in [
                #"{"a":"subscribe","v":[408065,884737]}"#,
                #"{"a":"mode","v":["ltp",[408065,884737]]}"#,
                #"{"a":"mode","v":["quote",[884737]]}"#,
                #"{"a":"mode","v":["full",[884737]]}"#,
                #"{"a":"unsubscribe","v":[408065]}"#,
            ] {
                let frame = try await peer.readFrame()
                #expect(frame.opcode == 1)
                let received = try #require(JSONSerialization.jsonObject(with: frame.payload) as? NSDictionary)
                let command = try #require(JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary)
                #expect(received == command)
            }
            let close = try await peer.readFrame()
            #expect(close.opcode == 8)
            #expect(close.payload == Data([0x03, 0xE8]))
            try await peer.sendFrame(opcode: 8, payload: close.payload)
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            do {
                try await ticker.subscribe([408_065, 884_737], mode: .ltp)
                try await ticker.setMode(.quote, for: [884_737])
                try await ticker.setMode(.full, for: [884_737])
                try await ticker.unsubscribe([408_065])
            } catch {
                await ticker.close()
                throw error
            }
            await ticker.close()
        }
    }

    @Test func emitsOrderedLTPBatchesAndSkipsHeartbeatsAndInvalidPackets() async throws {
        try await LoopbackWebSocket.run { peer in
            _ = try await peer.acceptUpgrade()
            try await peer.sendFrame(opcode: 2, payload: Data([0]))
            try await peer.sendFrame(opcode: 2, payload: Data([0, 1, 0, 8, 0]))
            // INFY token and price from ticker_ltp.json at c7a81238f93b4057c07257823b1bfaf30cba9ae5.
            // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/ticker_ltp.json
            try await peer.sendFrame(opcode: 2, payload: Data([
                0, 1, 0, 8, 0x00, 0x06, 0x3A, 0x01, 0x00, 0x02, 0x66, 0x83,
            ]))
            try await peer.sendFrame(opcode: 2, payload: Data([0]))
            try await peer.sendFrame(opcode: 2, payload: Data([
                0, 4,
                0, 8, 0x00, 0x00, 0x01, 0x03, 0x32, 0x65, 0xB0, 0x08,
                0, 1, 0xFF,
                0, 8, 0x00, 0x00, 0x01, 0x06, 0x06, 0x4C, 0x17, 0x50,
                0, 8, 0x00, 0x00, 0x01, 0x0C, 0x06, 0x4C, 0x17, 0x50,
            ]))
            let close = try await peer.readFrame()
            try await peer.sendFrame(opcode: 8, payload: close.payload)
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            try #expect(await events.next() == .ticks([.init(instrumentToken: 408_065, lastPrice: 1_573.15)]))
            try #expect(await events.next() == .ticks([
                .init(instrumentToken: 259, lastPrice: 84.5525),
                .init(instrumentToken: 262, lastPrice: 10_565),
                .init(instrumentToken: 268, lastPrice: 10_565),
            ]))
            await ticker.close()
            try #expect(await events.next() == nil)
        }
    }

    @Test func rejectsDuplicateConsumptionAndClosesWhenParkedNextIsCancelled() async throws {
        try await LoopbackWebSocket.run { peer in
            _ = try await peer.acceptUpgrade()
            do {
                let close = try await peer.readFrame()
                #expect(close.opcode == 8)
                try await peer.sendFrame(opcode: 8, payload: close.payload)
            } catch LoopbackWebSocket.Failure.unexpectedEOF {
                // Foundation sometimes closes a freshly upgraded socket without a close frame.
            }
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            defer { Task { await ticker.close() } }
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)

            var duplicate = ticker.makeAsyncIterator()
            await #expect(throws: KiteTickerError.iteratorAlreadyCreated) {
                _ = try await duplicate.next()
            }

            await withThrowingTaskGroup(of: KiteTicker.Event?.self) { reads in
                for _ in 0..<2 {
                    reads.addTask { [events] in
                        var iterator = events
                        return try await iterator.next()
                    }
                }
                // Either task can begin first. The other proves a next call is parked.
                await #expect(throws: KiteTickerError.concurrentNext) {
                    _ = try await reads.next()
                }
                reads.cancelAll()
                await #expect(throws: CancellationError.self) {
                    _ = try await reads.next()
                }
            }
            try #expect(await events.next() == nil)
        }
    }

    @Test func reportsHandshakeRejectionWithoutCredentials() async throws {
        try await LoopbackWebSocket.run { peer in
            try await peer.rejectUpgrade(status: "403 Forbidden")
        } client: { url in
            do {
                _ = try await KiteTicker.connect(
                    apiKey: "sample-api-key",
                    accessToken: "sample-access-token",
                    url: url
                )
                Issue.record("Expected the WebSocket handshake to be rejected")
            } catch let error as KiteTickerError {
                #expect(error == .http(statusCode: 403))
                let description = String(reflecting: error)
                #expect(!description.contains("sample-api-key"))
                #expect(!description.contains("sample-access-token"))
            }
        }
    }
}
