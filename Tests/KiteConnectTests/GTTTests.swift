import Foundation
import KiteConnect
import Testing

struct GTTTests {
    @Test func createsSingleTriggerWithFormEncodedConditionAndOrder() async throws {
        // Kite's single-trigger example with a symbol that exercises form escaping:
        // https://kite.trade/docs/connect/v3/gtt/#single
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/gtt_place_order.json
        let fixture = try HTTPStub.fixture("gtt_place_order.json")

        try await withKite(fixture: fixture, method: "POST", path: "/gtt/triggers", inspect: { request in
            let fields = try formFields(of: request)
            #expect(fields["type"] == "single")
            try expectJSON(fields["condition"], matches: """
                {"exchange":"NSE","tradingsymbol":"M&M","trigger_values":[702.0],"last_price":798.0}
                """)
            try expectJSON(fields["orders"], matches: """
                [{"exchange":"NSE","tradingsymbol":"M&M","transaction_type":"BUY","quantity":1,
                  "order_type":"LIMIT","product":"CNC","price":702.5}]
                """)
        }) { kite in
            let result = try await kite.createGTT(.init(
                exchange: "NSE",
                tradingSymbol: "M&M",
                lastPrice: 798,
                legs: .single(.init(
                    triggerValue: 702, limitPrice: 702.5, quantity: 1, transactionType: .buy, product: .cnc
                ))
            ))
            #expect(result.triggerID == 123)
        }
    }

    @Test func modifiesTwoLegTriggerPreservingOrderToTriggerPairing() async throws {
        // Distinct prices and quantities from the Rust SDK's two-leg request test:
        // https://github.com/zerodha/kiteconnect-rs/blob/fce212f81d451ad3a3195a6abbe31058fc89520e/src/gtt.rs
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/gtt_modify_order.json
        let fixture = try HTTPStub.fixture("gtt_modify_order.json")

        try await withKite(fixture: fixture, method: "PUT", path: "/gtt/triggers/123", inspect: { request in
            let fields = try formFields(of: request)
            #expect(fields["type"] == "two-leg")
            try expectJSON(fields["condition"], matches: """
                {"exchange":"NSE","tradingsymbol":"RAIN","trigger_values":[102.0,103.7],"last_price":102.6}
                """)
            try expectJSON(fields["orders"], matches: """
                [{"exchange":"NSE","tradingsymbol":"RAIN","transaction_type":"SELL","quantity":1,
                  "order_type":"LIMIT","product":"CNC","price":101.5},
                 {"exchange":"NSE","tradingsymbol":"RAIN","transaction_type":"SELL","quantity":2,
                  "order_type":"LIMIT","product":"CNC","price":104.0}]
                """)
        }) { kite in
            let result = try await kite.modifyGTT(triggerID: 123, request: .init(
                exchange: "NSE",
                tradingSymbol: "RAIN",
                lastPrice: 102.6,
                legs: .twoLeg(
                    lower: .init(
                        triggerValue: 102, limitPrice: 101.5, quantity: 1, transactionType: .sell, product: .cnc
                    ),
                    upper: .init(
                        triggerValue: 103.7, limitPrice: 104, quantity: 2, transactionType: .sell, product: .cnc
                    )
                )
            ))
            #expect(result.triggerID == 123)
        }
    }

    @Test func listsActiveAndTriggeredGTTs() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/gtt_get_orders.json
        let fixture = try HTTPStub.fixture("gtt_get_orders.json")

        try await withKite(fixture: fixture, method: "GET", path: "/gtt/triggers", inspect: { request in
            try #expect(HTTPStub.body(of: request) == nil)
        }) { kite in
            let triggers = try await kite.gttTriggers()

            #expect(triggers.map(\.id) == [112_127, 105_099])
            #expect(triggers.map(\.type) == ["single", "two-leg"])
            #expect(triggers.map(\.status) == ["active", "triggered"])

            let active = try #require(triggers.first)
            #expect(active.condition.tradingSymbol == "INFY")
            #expect(active.condition.instrumentToken == 408_065)
            #expect(active.condition.triggerValues == [702])
            #expect(active.orders.count == 1)
            #expect(active.orders.first?.result == nil)
            let meta = try #require(active.meta)
            #expect(meta.rejectionReason == nil)

            let triggered = try #require(triggers.last)
            #expect(triggered.condition.triggerValues == [102, 103.7])
            #expect(triggered.orders.count == 2)
            #expect(triggered.orders.first?.result == nil)
            #expect(triggered.orders.last?.result?.triggeredAt == 103.7)
            #expect(triggered.meta == nil)
        }
    }

    @Test func retrievesTriggerWithRejectedOrderResult() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/gtt_get_order.json
        let fixture = try HTTPStub.fixture("gtt_get_order.json")

        try await withKite(fixture: fixture, method: "GET", path: "/gtt/triggers/123", inspect: { request in
            try #expect(HTTPStub.body(of: request) == nil)
        }) { kite in
            let trigger = try await kite.gtt(triggerID: 123)

            #expect(trigger.id == 123)
            #expect(trigger.userID == "XX0000")
            #expect(trigger.parentTriggerID == nil)
            #expect(trigger.createdAt == "2019-09-09 15:13:22")
            #expect(trigger.updatedAt == "2019-09-09 15:15:08")
            #expect(trigger.expiresAt == "2020-01-01 12:00:00")
            #expect(trigger.condition.exchange == "NSE")
            #expect(trigger.condition.lastPrice == 102.6)

            let order = try #require(trigger.orders.last)
            #expect(order.tradingSymbol == "RAIN")
            #expect(order.transactionType == "SELL")
            #expect(order.orderType == "LIMIT")
            #expect(order.quantity == 1)

            let result = try #require(order.result)
            #expect(result.accountID == "XX0000")
            #expect(result.validity == "DAY")
            #expect(result.timestamp == "2019-09-09 15:15:08")
            #expect(result.meta == #"{"app_id":12617,"gtt":105099}"#)

            let orderResult = try #require(result.orderResult)
            #expect(orderResult.status == "failed")
            #expect(orderResult.orderID == "")
            #expect(orderResult.rejectionReason?.contains("lower circuit limit of 70.65") == true)
        }
    }

    @Test func deletesTriggerWithoutRequestBody() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/gtt_delete_order.json
        let fixture = try HTTPStub.fixture("gtt_delete_order.json")

        try await withKite(fixture: fixture, method: "DELETE", path: "/gtt/triggers/123", inspect: { request in
            try #expect(HTTPStub.body(of: request) == nil)
        }) { kite in
            let result = try await kite.deleteGTT(triggerID: 123)
            #expect(result.triggerID == 123)
        }
    }

    private func withKite(
        fixture: Data,
        method: String,
        path: String,
        inspect: @escaping @Sendable (URLRequest) throws -> Void,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == method)
            #expect(request.url?.path == path)
            #expect(request.url?.query == nil)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            try inspect(request)
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            try await operation(KiteConnectClient(
                apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session
            ))
        }
    }

    private func formFields(of request: URLRequest) throws -> [String: String] {
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let body = try #require(try HTTPStub.body(of: request))
        var components = URLComponents()
        components.percentEncodedQuery = String(decoding: body, as: UTF8.self)
            .replacingOccurrences(of: "+", with: "%20")
        let items = try #require(components.queryItems)
        #expect(items.map(\.name).sorted() == ["condition", "orders", "type"])
        return items.reduce(into: [:]) { $0[$1.name] = $1.value }
    }

    private func expectJSON(_ actual: String?, matches expected: String) throws {
        let actual = try #require(actual)
        let actualObject = try JSONSerialization.jsonObject(with: Data(actual.utf8)) as? NSObject
        let expectedObject = try JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSObject
        let expectedJSON = try #require(expectedObject)
        #expect(actualObject == expectedJSON)
    }
}
