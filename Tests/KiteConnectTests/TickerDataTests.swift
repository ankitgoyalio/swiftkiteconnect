import Foundation
@testable import KiteConnect
import Testing

struct TickerDataTests {
    @Test func decodesPinnedQuoteAndFullPacketsAndBothIndexModes() async throws {
        let quote = try Self.packet("ticker_quote")
        let full = try Self.packet("ticker_full")
        // Index example from parses_index_packet in the pinned Rust packet.rs.
        // https://github.com/zerodha/kiteconnect-rs/blob/fce212f81d451ad3a3195a6abbe31058fc89520e/src/ticker/packet.rs
        let index = Self.words([256_265, 2_431_240, 2_440_000, 2_420_000, 2_425_000, 2_428_500, 0, 1_720_000_000])
        // Distinct timestamps, high-bit quantities, and nonzero depth padding on a CDS instrument.
        var currency = Self.words([
            259, 845_525_000, 0xFFFF_FFFC, 840_000_000, 0xFFFF_FFFD, 0xFFFF_FFFE, 0xFFFF_FFFF,
            830_000_000, 850_000_000, 820_000_000, 835_000_000,
            1_720_000_100, 0xFFFF_FFFF, 0xFFFF_FFFE, 0x8000_0000, 1_720_000_200,
        ])
        for _ in 0..<10 {
            currency.append(Self.words([0xFFFF_FFFF, 835_000_000, 0xFEDC_ABCD]))
        }

        try await LoopbackWebSocket.run { [currency] peer in
            _ = try await peer.acceptUpgrade()
            try await peer.sendFrame(opcode: 2, payload: Self.frame([quote, full, Data(index.prefix(28)), index, currency]))
            let close = try await peer.readFrame()
            try await peer.sendFrame(opcode: 8, payload: close.payload)
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            defer { Task { await ticker.close() } }
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            let received = try await events.next()
            guard case .ticks(let ticks) = received else {
                Issue.record("Expected one batch containing the quote and full ticks")
                return
            }
            try #require(ticks.count == 5)
            #expect(ticks.map(\.instrumentToken) == [408_065, 408_065, 256_265, 256_265, 259])
            let (quote, full, indexQuote, indexFull, currency) = (ticks[0], ticks[1], ticks[2], ticks[3], ticks[4])
            #expect(quote.mode == .quote)
            #expect(quote.lastPrice == 1573.15)
            #expect(quote.lastQuantity == 1)
            #expect(quote.averagePrice == 1570.33)
            #expect(quote.volume == 1_175_986)
            #expect(quote.buyQuantity == 256_511)
            #expect(quote.sellQuantity == 360_503)
            #expect(quote.open == 1569.15)
            #expect(quote.high == 1575)
            #expect(quote.low == 1561.05)
            #expect(quote.close == 1567.8)
            #expect(quote.depth == nil)
            #expect(quote.exchangeTime == nil)
            #expect(full.mode == .full)
            #expect(full.lastPrice == 1573.7)
            #expect(full.lastTradeTime == Date(timeIntervalSince1970: 1_625_461_887))
            #expect(full.exchangeTime == full.lastTradeTime)
            #expect(full.openInterest == 0)
            #expect(full.depth?.buy.map(\.quantity) == [5, 140, 2, 219, 50])
            #expect(full.depth?.sell.map(\.quantity) == [172, 44, 302, 141, 724])
            #expect(full.depth?.buy.map(\.price) == [1573.4, 1573, 1572.95, 1572.9, 1572.85])
            #expect(full.depth?.sell.map(\.orders) == [3, 3, 3, 2, 5])
            #expect(indexQuote.mode == .quote)
            #expect(indexQuote.isIndex)
            #expect(indexQuote.lastPrice == 24_312.4)
            #expect(indexQuote.high == 24_400)
            #expect(indexQuote.low == 24_200)
            #expect(indexQuote.open == 24_250)
            #expect(indexQuote.close == 24_285)
            #expect(indexQuote.exchangeTime == nil)
            #expect(indexFull.mode == .full)
            #expect(indexFull.isIndex)
            #expect(indexFull.exchangeTime == Date(timeIntervalSince1970: 1_720_000_000))
            #expect(indexFull.volume == nil)
            #expect(indexFull.depth == nil)
            #expect(currency.lastPrice == 84.5525)
            #expect(currency.averagePrice == 84)
            #expect(currency.lastQuantity == 4_294_967_292)
            #expect(currency.volume == 4_294_967_293)
            #expect(currency.buyQuantity == 4_294_967_294)
            #expect(currency.sellQuantity == 4_294_967_295)
            #expect(currency.openInterest == 4_294_967_295)
            #expect(currency.openInterestDayHigh == 4_294_967_294)
            #expect(currency.openInterestDayLow == 2_147_483_648)
            #expect(currency.lastTradeTime == Date(timeIntervalSince1970: 1_720_000_100))
            #expect(currency.exchangeTime == Date(timeIntervalSince1970: 1_720_000_200))
            #expect(currency.depth?.sell.last?.quantity == 4_294_967_295)
            #expect(currency.depth?.sell.last?.price == 83.5)
            #expect(currency.depth?.sell.last?.orders == 65_244)
            await ticker.close()
        }
    }

    @Test func deliversTypedOrderUpdatesBetweenBinaryTicks() async throws {
        let update = try Self.orderUpdate()
        let first = Self.frame([Self.words([408_065, 157_315])])
        let last = Self.frame([Self.words([408_065, 157_370])])

        try await LoopbackWebSocket.run { peer in
            _ = try await peer.acceptUpgrade()
            try await peer.sendFrame(opcode: 2, payload: first)
            try await peer.sendFrame(opcode: 1, payload: update)
            try await peer.sendFrame(opcode: 1, payload: Data(#"{"type":"order","data":{}}"#.utf8))
            try await peer.sendFrame(opcode: 2, payload: last)
            let close = try await peer.readFrame()
            try await peer.sendFrame(opcode: 8, payload: close.payload)
        } client: { url in
            let ticker = try await KiteTicker.connect(apiKey: "key", accessToken: "token", url: url)
            defer { Task { await ticker.close() } }
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            try #expect(await events.next() == .ticks([.init(instrumentToken: 408_065, lastPrice: 1573.15)]))
            guard case .orderUpdate(let order) = try await events.next() else {
                Issue.record("Expected the typed order in receive order")
                return
            }
            #expect(order.orderID == "220303000308932")
            #expect(order.status == .complete)
            #expect(order.tradingSymbol == "SBIN")
            #expect(order.filledQuantity == 1)
            #expect(order.averagePrice == 470)
            try #expect(await events.next() == .invalidOrderUpdate)
            try #expect(await events.next() == .ticks([.init(instrumentToken: 408_065, lastPrice: 1573.7)]))
            await ticker.close()
        }
    }

    @Test func reconnectsWhileReadsArePausedAndPreservesTheBufferedOrder() async throws {
        let observations = AsyncStream<KiteTicker.StreamObservation>.makeStream()
        let bufferFilled = AsyncStream<Void>.makeStream()
        let stillPaused = AsyncStream<Void>.makeStream()
        let replayed = AsyncStream<Void>.makeStream()
        let update = try Self.orderUpdate()
        let ticks = Self.frame([Self.words([408_065, 157_315])])

        try await LoopbackWebSocket.run(servers: [
            { peer in
                _ = try await peer.acceptUpgrade()
                _ = try await peer.readFrame()
                _ = try await peer.readFrame()
                try await peer.sendFrame(opcode: 1, payload: update)
                var full = bufferFilled.stream.makeAsyncIterator()
                _ = await full.next()
                let ping = try await peer.readFrame()
                #expect(ping.opcode == 9)
                try await peer.sendFrame(opcode: 10, payload: ping.payload)
                stillPaused.continuation.yield(())
                _ = await full.next()
            },
            { peer in
                _ = try await peer.acceptUpgrade()
                let subscribe = try await peer.readFrame()
                let command = try #require(JSONSerialization.jsonObject(with: subscribe.payload) as? NSDictionary)
                #expect(command == ["a": "subscribe", "v": [408_065]] as NSDictionary)
                _ = try await peer.readFrame()
                try await peer.sendFrame(opcode: 2, payload: ticks)
                replayed.continuation.yield(())
                _ = try? await peer.readFrame()
            },
        ]) { url in
            let ticker = try await KiteTicker.connect(
                apiKey: "key", accessToken: "token", url: url, eventCapacity: 2
            ) { observations.continuation.yield($0) }
            defer { Task { await ticker.close() } }
            try await ticker.subscribe([408_065], mode: .ltp)

            // A wire write alone cannot reveal whether Foundation was asked for another receive.
            var activity = observations.stream.makeAsyncIterator()
            try #require(await activity.next() == .willReceive)
            try #require(await activity.next() == .bufferFull)
            bufferFilled.continuation.yield(())
            var paused = stillPaused.stream.makeAsyncIterator()
            try #require(await paused.next() != nil)
            observations.continuation.finish()
            #expect(await activity.next() == nil)
            bufferFilled.continuation.yield(())

            var replay = replayed.stream.makeAsyncIterator()
            try #require(await replay.next() != nil)
            var events = ticker.makeAsyncIterator()
            try #expect(await events.next() == .connected)
            guard case .orderUpdate(let order) = try await events.next() else {
                Issue.record("Expected the buffered order before the interruption")
                return
            }
            #expect(order.orderID == "220303000308932")
            guard case .interrupted = try await events.next() else {
                Issue.record("Expected an interruption after the buffered order")
                return
            }
            try #expect(await events.next() == .recovered)
            try #expect(await events.next() == .ticks([.init(instrumentToken: 408_065, lastPrice: 1573.15)]))
            await ticker.close()
            try #expect(await events.next() == nil)
        }
    }

    private static func orderUpdate() throws -> Data {
        // The pinned Rust order_update_waits_for_capacity_instead_of_dropping test
        // wraps postback.json in the same WebSocket envelope.
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/postback.json
        let fixture = try #require(Bundle.module.url(
            forResource: "ticker_order_update", withExtension: "json", subdirectory: "Fixtures"
        ))
        return try Data(contentsOf: fixture)
    }

    private static func packet(_ name: String) throws -> Data {
        // ticker_quote.packet and ticker_full.packet are base64 payloads. Expected values
        // are from the corresponding ticker_quote.json and ticker_full.json.
        // https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "packet", subdirectory: "Fixtures"))
        let base64 = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        return try #require(Data(base64Encoded: base64))
    }

    private static func words(_ values: [UInt32]) -> Data {
        var bytes = Data()
        for value in values {
            withUnsafeBytes(of: value.bigEndian) { bytes.append(contentsOf: $0) }
        }
        return bytes
    }

    private static func frame(_ packets: [Data]) -> Data {
        var bytes = Data([0, UInt8(packets.count)])
        for packet in packets {
            bytes.append(contentsOf: [0, UInt8(packet.count)])
            bytes.append(packet)
        }
        return bytes
    }
}
