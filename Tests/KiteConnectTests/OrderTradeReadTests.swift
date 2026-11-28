import Foundation
import KiteConnect
import Testing

struct OrderTradeReadTests {
    @Test func readsOrderBookWithRejectedAndFilledOrders() async throws {
        // Subset of orders.json at https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        try await withOrderResponse("order_reads_book.json", path: "/orders") { client in
            let orders = try await client.orders()
            #expect(orders.map(\.status) == [.rejected, .cancelled, .complete])

            let rejected = try #require(orders.first)
            #expect(rejected.orderID == "220524001859672")
            #expect(rejected.exchangeOrderID == nil)
            #expect(rejected.parentOrderID == nil)
            #expect(rejected.exchangeTimestamp == nil)
            #expect(rejected.exchangeUpdateTimestamp == nil)
            #expect(rejected.statusMessage?.hasPrefix("Insufficient funds.") == true)
            #expect(rejected.statusMessageRaw?.hasPrefix("RMS:Margin Exceeds") == true)
            #expect(rejected.variety == .iceberg)
            #expect(rejected.validity == .ttl)
            #expect(rejected.validityTTL == 2)
            #expect(rejected.tags == ["icebergord"])
            #expect(rejected.meta == .object([
                "iceberg": .object([
                    "leg": .number(1),
                    "legs": .number(5),
                    "leg_quantity": .number(200),
                    "total_quantity": .number(1_000),
                    "remaining_quantity": .number(800),
                ]),
            ]))
            #expect(orders.first { $0.variety == .auction }?.auctionNumber == "22")

            let filled = try #require(orders.last)
            #expect(filled.orderID == "1953367517686685697")
            #expect(filled.exchangeOrderID == "1500000159758742")
            #expect(filled.terminalID == "111111111111100")
            #expect(filled.accountID == "XXXXXX")
            #expect(filled.orderType == .market)
            #expect(filled.transactionType == .buy)
            #expect(filled.product == .nrml)
            #expect(filled.instrumentToken == 10_189_826)
            #expect(filled.filledQuantity == 150)
            #expect(filled.pendingQuantity == 0)
            #expect(filled.averagePrice == 12.3)
            #expect(filled.orderTimestamp == "2025-08-07 13:38:02")
            #expect(filled.tags == ["autoslice", "autoslice:1953367517640548352"])
        }
    }

    @Test func readsOrderHistoryInServiceOrder() async throws {
        // Subset of order_info.json at https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        // The first entry also exercises Kite's blank optional fields and nullable tags.
        try await withOrderResponse("order_reads_history.json", path: "/orders/171229000724687") { client in
            let history = try await client.orderHistory(orderID: "171229000724687")
            #expect(history.map(\.orderID) == Array(repeating: "171229000724687", count: 4))
            #expect(history.map(\.status) == [.putOrderRequestReceived, .open, .modified, .open])

            let first = try #require(history.first)
            #expect(first.exchangeOrderID == nil)
            #expect(first.exchangeTimestamp == nil)
            #expect(first.exchangeUpdateTimestamp == nil)
            #expect(first.tags == nil)
            #expect(first.meta == .string(""))

            let latest = try #require(history.last)
            #expect(latest.exchangeOrderID == "1300000001887410")
            #expect(latest.exchangeTimestamp == "2017-12-29 11:08:16")
            #expect(latest.orderType == .limit)
            #expect(latest.tradingSymbol == "SBIN")
            #expect(latest.exchange == "NSE")
            #expect(latest.pendingQuantity == 1)
        }
    }

    @Test func readsDailyTradeExecutions() async throws {
        // Subset of trades.json at https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        // The second entry uses the documented filled field and absent exchange details.
        try await withOrderResponse("order_reads_all_trades.json", path: "/trades") { client in
            let trades = try await client.trades()
            #expect(trades.map(\.tradeID) == ["10000000", "40000000"])

            let first = try #require(trades.first)
            #expect(first.orderID == "200000000000000")
            #expect(first.exchangeOrderID == "300000000000000")
            #expect(first.exchange == "NSE")
            #expect(first.tradingSymbol == "SBIN")
            #expect(first.instrumentToken == 779_521)
            #expect(first.product == .cnc)
            #expect(first.transactionType == .buy)
            #expect(first.quantity == 1)
            #expect(first.averagePrice == 420.65)
            #expect(first.fillTimestamp == "2021-05-31 09:16:39")
            #expect(first.orderTimestamp == "09:16:39")
            #expect(first.exchangeTimestamp == "2021-05-31 09:16:39")

            let second = try #require(trades.last)
            #expect(second.quantity == 1)
            #expect(second.averagePrice == 72.755)
            #expect(second.exchangeOrderID == nil)
            #expect(second.orderTimestamp == nil)
            #expect(second.exchangeTimestamp == nil)
        }
    }

    @Test func readsExecutionsForOneOrder() async throws {
        // From order_trades.json at https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        try await withOrderResponse("order_reads_single_order_trades.json", path: "/orders/200000000000000/trades") { client in
            let trades = try await client.orderTrades(orderID: "200000000000000")
            #expect(trades.count == 1)
            let trade = try #require(trades.first)
            #expect(trade.tradeID == "10000000")
            #expect(trade.orderID == "200000000000000")
            #expect(trade.exchange == "MCX")
            #expect(trade.quantity == 1)
            #expect(trade.averagePrice == 4_852)
            #expect(trade.fillTimestamp == "2021-05-31 16:00:36")
        }
    }

    private func withOrderResponse(
        _ filename: String,
        path: String,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        let fixture = try HTTPStub.fixture(filename)
        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == "GET")
            let url = try #require(request.url)
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            #expect(components.percentEncodedPath == path)
            #expect(components.query == nil)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            #expect(try HTTPStub.body(of: request) == nil)
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let client = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            try await operation(client)
        }
    }
}
