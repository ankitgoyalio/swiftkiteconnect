import Foundation
import KiteConnect
import Testing

struct MarginCalculationTests {
    @Test func estimatesIndividualOrderMargins() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/order_margins.json
        let fixture = try HTTPStub.fixture("order_margins.json")

        try await withCalculation(
            path: "/margins/orders",
            requestJSON: """
            [{"exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","variety":"regular",
              "product":"CNC","order_type":"MARKET","quantity":1,"price":0,"trigger_price":0}]
            """,
            fixture: fixture
        ) { kite in
            let margins = try await kite.orderMargins([
                .init(
                    exchange: "NSE", tradingSymbol: "INFY", transactionType: "BUY",
                    variety: "regular", product: "CNC", orderType: "MARKET", quantity: 1,
                    price: 0, triggerPrice: 0
                ),
            ])
            #expect(margins.count == 1)
            let margin = try #require(margins.first)
            #expect(margin.marginType == "equity")
            #expect(margin.tradingSymbol == "INFY")
            #expect(margin.exchange == "NSE")
            #expect(margin.span == 0)
            #expect(margin.exposure == 0)
            #expect(margin.optionPremium == 0)
            #expect(margin.additional == 0)
            #expect(margin.bo == 0)
            #expect(margin.cash == 0)
            #expect(margin.varMargin == 1498)
            #expect(margin.pnl?.realised == 0)
            #expect(margin.pnl?.unrealised == 0)
            #expect(margin.leverage == 1)
            #expect(margin.charges?.total == 1.79255122)
            #expect(margin.total == 1498)
        }
    }

    @Test func estimatesCompactOrderMargins() async throws {
        // Total from order_margins.json, with detail omitted to simulate compact mode.
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/order_margins.json
        let fixture = Data(#"{"status":"success","data":[{"total":1498}]}"#.utf8)

        try await withCalculation(
            path: "/margins/orders",
            query: [.init(name: "mode", value: "compact")],
            requestJSON: """
            [{"exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","variety":"regular",
              "product":"CNC","order_type":"SL","quantity":1,"price":1500.25,"trigger_price":1499.75}]
            """,
            fixture: fixture
        ) { kite in
            let margins = try await kite.orderMargins([
                .init(
                    exchange: "NSE", tradingSymbol: "INFY", transactionType: "BUY",
                    variety: "regular", product: "CNC", orderType: "SL", quantity: 1,
                    price: 1500.25, triggerPrice: 1499.75
                ),
            ], compact: true)
            #expect(margins.count == 1)
            let margin = try #require(margins.first)
            #expect(margin.total == 1498)
            #expect(margin.tradingSymbol == nil)
            #expect(margin.charges == nil)
        }
    }

    @Test func estimatesBasketMarginsWithExistingPositions() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/basket_margins.json
        let fixture = try HTTPStub.fixture("basket_margins.json")

        try await withCalculation(
            path: "/margins/basket",
            query: [.init(name: "consider_positions", value: "true")],
            requestJSON: """
            [
              {"exchange":"NFO","tradingsymbol":"NIFTY23JUL20600CE","transaction_type":"SELL",
               "variety":"regular","product":"NRML","order_type":"MARKET","quantity":75},
              {"exchange":"NFO","tradingsymbol":"NIFTY23JUL20700CE","transaction_type":"BUY",
               "variety":"regular","product":"NRML","order_type":"MARKET","quantity":75}
            ]
            """,
            fixture: fixture
        ) { kite in
            let basket = try await kite.basketMargins([
                .init(
                    exchange: "NFO", tradingSymbol: "NIFTY23JUL20600CE", transactionType: "SELL",
                    variety: "regular", product: "NRML", orderType: "MARKET", quantity: 75
                ),
                .init(
                    exchange: "NFO", tradingSymbol: "NIFTY23JUL20700CE", transactionType: "BUY",
                    variety: "regular", product: "NRML", orderType: "MARKET", quantity: 75
                ),
            ], considerPositions: true)
            #expect(basket.initial.total == 96504.975)
            #expect(basket.final.total == 34786.725000000006)
            #expect(basket.final.optionPremium == -2152.5)
            #expect(basket.orders?.map(\.total) == [95983.725, 521.25])
            #expect(basket.charges?.brokerage == 40)
        }
    }

    @Test func estimatesCompactBasketMarginsWithoutExistingPositions() async throws {
        // Totals from basket_margins.json, with detail omitted to simulate compact mode.
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/basket_margins.json
        let fixture = Data("""
        {"status":"success","data":{"initial":{"total":96504.975},"final":{"total":34786.725000000006}}}
        """.utf8)

        try await withCalculation(
            path: "/margins/basket",
            query: [
                .init(name: "consider_positions", value: "false"),
                .init(name: "mode", value: "compact"),
            ],
            requestJSON: """
            [
              {"exchange":"NFO","tradingsymbol":"NIFTY23JUL20600CE","transaction_type":"SELL",
               "variety":"regular","product":"NRML","order_type":"MARKET","quantity":75},
              {"exchange":"NFO","tradingsymbol":"NIFTY23JUL20700CE","transaction_type":"BUY",
               "variety":"regular","product":"NRML","order_type":"MARKET","quantity":75}
            ]
            """,
            fixture: fixture
        ) { kite in
            let basket = try await kite.basketMargins([
                .init(
                    exchange: "NFO", tradingSymbol: "NIFTY23JUL20600CE", transactionType: "SELL",
                    variety: "regular", product: "NRML", orderType: "MARKET", quantity: 75
                ),
                .init(
                    exchange: "NFO", tradingSymbol: "NIFTY23JUL20700CE", transactionType: "BUY",
                    variety: "regular", product: "NRML", orderType: "MARKET", quantity: 75
                ),
            ], considerPositions: false, compact: true)
            #expect(basket.initial.total == 96504.975)
            #expect(basket.final.total == 34786.725000000006)
            #expect(basket.initial.span == nil)
            #expect(basket.final.pnl == nil)
            #expect(basket.orders == nil)
            #expect(basket.charges == nil)
        }
    }

    @Test func calculatesVirtualContractNotes() async throws {
        // First two orders from virtual_contract_note.json.
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/virtual_contract_note.json
        let fixture = try HTTPStub.fixture("virtual_contract_note.json")

        try await withCalculation(
            path: "/charges/orders",
            requestJSON: """
            [
              {"order_id":"111111111","exchange":"NSE","tradingsymbol":"SBIN","transaction_type":"BUY",
               "variety":"regular","product":"CNC","order_type":"MARKET","quantity":1,"average_price":560},
              {"order_id":"2222222222","exchange":"MCX","tradingsymbol":"GOLDPETAL23JULFUT","transaction_type":"SELL",
               "variety":"regular","product":"NRML","order_type":"LIMIT","quantity":1,"average_price":5862}
            ]
            """,
            fixture: fixture
        ) { kite in
            let notes = try await kite.orderCharges([
                .init(
                    orderID: "111111111", exchange: "NSE", tradingSymbol: "SBIN", transactionType: "BUY",
                    variety: "regular", product: "CNC", orderType: "MARKET", quantity: 1, averagePrice: 560
                ),
                .init(
                    orderID: "2222222222", exchange: "MCX", tradingSymbol: "GOLDPETAL23JULFUT", transactionType: "SELL",
                    variety: "regular", product: "NRML", orderType: "LIMIT", quantity: 1, averagePrice: 5862
                ),
            ])
            #expect(notes.map(\.tradingSymbol) == ["SBIN", "GOLDPETAL23JULFUT"])
            #expect(notes.map(\.charges.transactionTaxType) == ["stt", "ctt"])
            let note = try #require(notes.last)
            #expect(note.exchange == "MCX")
            #expect(note.transactionType == "SELL")
            #expect(note.variety == "regular")
            #expect(note.product == "NRML")
            #expect(note.orderType == "LIMIT")
            #expect(note.quantity == 1)
            #expect(note.price == 5862)
            #expect(note.charges.transactionTax == 0.5862)
            #expect(note.charges.exchangeTurnoverCharge == 0.152412)
            #expect(note.charges.sebiTurnoverCharge == 0.005862)
            #expect(note.charges.brokerage == 1.7586)
            #expect(note.charges.stampDuty == 0)
            #expect(note.charges.gst.igst == 0.34503732)
            #expect(note.charges.gst.cgst == 0)
            #expect(note.charges.gst.sgst == 0)
            #expect(note.charges.gst.total == 0.34503732)
            #expect(note.charges.total == 2.84811132)
        }
    }

    private func withCalculation(
        path: String,
        query: Set<URLQueryItem> = [],
        requestJSON: String,
        fixture: Data,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let queryItems = components.queryItems ?? []
            #expect(url.path == path)
            #expect(Set(queryItems) == query)
            #expect(queryItems.count == query.count)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            let body = try #require(try HTTPStub.body(of: request))
            let actual = try #require(JSONSerialization.jsonObject(with: body) as? NSArray)
            let expected = try #require(JSONSerialization.jsonObject(with: Data(requestJSON.utf8)) as? NSArray)
            #expect(actual == expected)
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            try await operation(.init(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session))
        }
    }
}
