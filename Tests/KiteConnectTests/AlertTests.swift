import Foundation
import KiteConnect
import Testing

struct AlertTests {
    private static let simpleUUID = "550e8400-e29b-41d4-a716-446655440000"
    private static let atoUUID = "a5a2b03d-4851-44b3-9d85-0123baa4a273"
    private static let nifty = AlertInstrument(exchange: "INDICES", tradingSymbol: "NIFTY 50")
    private static let condition = AlertCondition(
        name: "NIFTY 50", lhs: nifty, comparison: .greaterThanOrEqual, rhs: .constant(27000)
    )

    @Test func createsSimpleAlert() async throws {
        let alert = try await withAlertFixture("alerts_create.json", method: "POST", path: "/alerts") { request in
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
            let body = try #require(try HTTPStub.body(of: request))
            let fields = String(decoding: body, as: UTF8.self).split(separator: "&").sorted()
            #expect(fields == [
                "lhs_attribute=LastTradedPrice", "lhs_exchange=INDICES", "lhs_tradingsymbol=NIFTY+50",
                "name=NIFTY+50", "operator=%3E%3D", "rhs_constant=27000", "rhs_type=constant", "type=simple",
            ])
        } operation: { kite in
            try await kite.createAlert(Self.condition)
        }

        #expect(alert.uuid == Self.simpleUUID)
        #expect(alert.type == .simple)
        #expect(alert.status == .enabled)
        #expect(alert.userID == "AB1234")
        #expect(alert.rhsConstant == 27000)
    }

    @Test func createsATOWithBasketJSONInForm() async throws {
        let order = AlertBasketOrder(
            transactionType: "BUY", product: "CNC", orderType: "MARKET", quantity: 1,
            validityTTL: 1, lastPrice: 0, icebergLegs: 0, marketProtection: -1
        )
        let basket = AlertBasketCreate(name: "alerts-basket", items: [
            .init(exchange: "NSE", tradingSymbol: "RELIANCE", weight: 10000, order: order),
        ])
        let alert = try await withAlertFixture("alerts_create_ato.json", method: "POST", path: "/alerts") { request in
            var form = try Self.formBody(request)
            let basketField = form.removeValue(forKey: "basket")
            let basket = try #require(basketField)
            #expect(form == [
                "name": "NIFTY 50", "type": "ato", "lhs_exchange": "INDICES",
                "lhs_tradingsymbol": "NIFTY 50", "lhs_attribute": "LastTradedPrice",
                "operator": ">=", "rhs_type": "constant", "rhs_constant": "27000",
            ])
            try Self.expectJSON(basket, equals: """
                {"name":"alerts-basket","type":"alert","tags":[],"items":[
                  {"type":"insert","tradingsymbol":"RELIANCE","exchange":"NSE","weight":10000,"params":{
                    "transaction_type":"BUY","product":"CNC","order_type":"MARKET","validity":"DAY",
                    "validity_ttl":1,"quantity":1,"price":0,"trigger_price":0,"disclosed_quantity":0,
                    "last_price":0,"variety":"regular","tags":[],"squareoff":0,"stoploss":0,
                    "trailing_stoploss":0,"iceberg_legs":0,"market_protection":-1
                  }}
                ]}
                """)
        } operation: { kite in
            try await kite.createAlert(Self.condition, basket: basket)
        }

        #expect(alert.uuid == Self.atoUUID)
        #expect(alert.type == .ato)
        #expect(alert.basket == nil)
    }

    @Test(arguments: [false, true]) func listsSimpleAndATOAlerts(filtered: Bool) async throws {
        let alerts = try await withAlertFixture(
            "alerts_get.json", method: "GET", path: "/alerts",
            query: filtered ? "status=disabled&page=2&page_size=10" : nil
        ) { kite in
            if filtered {
                return try await kite.alerts(status: .disabled, page: 2, pageSize: 10)
            }
            return try await kite.alerts()
        }

        #expect(alerts.map(\.type) == [.simple, .ato])
        #expect(alerts.first?.basket == nil)
        let ato = try #require(alerts.last)
        #expect(ato.rhsConstant == 71.8)
        #expect(ato.status == .disabled)
        let item = try #require(ato.basket?.items.first)
        #expect(item.id == 275218517)
        #expect(item.instrumentToken == 3693569)
        #expect(item.tradingSymbol == "GOLDBEES")
        #expect(item.order.price == 72.22)
        #expect(item.order.gtt?.target == 0)
    }

    @Test func retrievesAlertByUUID() async throws {
        let uuid = Self.simpleUUID
        let alert = try await withAlertFixture(
            "alerts_get_one.json", method: "GET", path: "/alerts/\(uuid)"
        ) { kite in
            try await kite.alert(uuid: uuid)
        }
        #expect(alert.uuid == uuid)
        #expect(alert.lhsTradingSymbol == "NIFTY 50")
        #expect(alert.comparison == .greaterThanOrEqual)
        #expect(alert.createdAt == "2025-05-26 12:07:50")
    }

    @Test func retrievesATOBasketByUUID() async throws {
        // alerts_get_one_ato.json wraps the ATO row of pinned alerts_get.json as a single-alert response.
        let uuid = "e888ed4a-6801-406f-bdc2-002db5a8411d"
        let alert = try await withAlertFixture(
            "alerts_get_one_ato.json", method: "GET", path: "/alerts/\(uuid)"
        ) { kite in
            try await kite.alert(uuid: uuid)
        }
        #expect(alert.uuid == uuid)
        #expect(alert.type == .ato)
        #expect(alert.basket?.items.first?.order.quantity == 10000)
    }

    @Test func forwardsFetchedSparseBasketParamsWithoutChangingTheirJSON() async throws {
        // Envelope from the pinned alerts_get.json ATO row, with sparse params adapted from Rust's Preserved test.
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/alerts_get.json
        // https://github.com/zerodha/kiteconnect-rs/blob/fce212f81d451ad3a3195a6abbe31058fc89520e/src/alerts.rs
        let fixture = "alerts_get_one_ato_sparse.json"
        let uuid = "e888ed4a-6801-406f-bdc2-002db5a8411d"
        let expectedParams = """
            {"order_type":"SL-M","quantity":10,"price":0,"disclosed_quantity":4,"trigger_price":null,
             "gtt":{"target":2.5,"extension":{"enabled":true,"thresholds":[null,-1.25,9007199254740993]}},
             "future_param":["preserved",{"legs":[1,2]}]}
            """
        let alert = try await withAlertFixture(fixture, method: "GET", path: "/alerts/\(uuid)") { kite in
            try await kite.alert(uuid: uuid)
        }

        let item = try #require(alert.basket?.items.first)
        #expect(item.order.orderType == "SL-M")
        #expect(item.order.quantity == 10)
        #expect(item.order.disclosedQuantity == 4)
        #expect(item.order.gtt?.target == 2.5)
        let encoded = try JSONEncoder().encode(item.order)
        try Self.expectJSON(String(decoding: encoded, as: UTF8.self), equals: expectedParams)

        let moved = AlertBasketCreate.Item(
            exchange: item.exchange, tradingSymbol: item.tradingSymbol, weight: 2, order: item.order
        )
        let id = try #require(item.id)
        _ = try await withAlertFixture(fixture, method: "PUT", path: "/alerts/\(uuid)") { request in
            let form = try Self.formBody(request)
            let basket = try #require(form["basket"])
            try Self.expectJSON(basket, equals: """
                {"items":[{"type":"update","id":275218517,"exchange":"NSE","tradingsymbol":"GOLDBEES",
                           "weight":2,"params":\(expectedParams)}]}
                """)
        } operation: { kite in
            try await kite.modifyAlert(
                uuid: uuid, condition: Self.condition, kind: .ato(basketOperations: [.update(id: id, item: moved)])
            )
        }
    }

    @Test func modifiesSimpleAlert() async throws {
        let uuid = Self.simpleUUID
        let condition = AlertCondition(
            name: "NIFTY 50", lhs: Self.nifty, comparison: .greaterThanOrEqual, rhs: .constant(27500)
        )
        let alert = try await withAlertFixture(
            "alerts_modify.json", method: "PUT", path: "/alerts/\(uuid)"
        ) { request in
            let form = try Self.formBody(request)
            #expect(form == [
                "name": "NIFTY 50", "type": "simple", "lhs_exchange": "INDICES",
                "lhs_tradingsymbol": "NIFTY 50", "lhs_attribute": "LastTradedPrice",
                "operator": ">=", "rhs_type": "constant", "rhs_constant": "27500",
            ])
        } operation: { kite in
            try await kite.modifyAlert(uuid: uuid, condition: condition)
        }
        #expect(alert.uuid == uuid)
        #expect(alert.rhsConstant == 27500)
        #expect(alert.updatedAt == "2025-05-26 12:10:15")
    }

    @Test(arguments: [false, true]) func modifiesATOWithInstrumentCondition(updateBasket: Bool) async throws {
        // alerts_modify_ato.json adapts the ATO row of pinned alerts_get.json to an instrument RHS.
        // Basket update shape and explicit status are covered by the pinned Rust implementation:
        // https://github.com/zerodha/kiteconnect-rs/blob/fce212f81d451ad3a3195a6abbe31058fc89520e/src/alerts.rs
        let uuid = "e888ed4a-6801-406f-bdc2-002db5a8411d"
        let condition = AlertCondition(
            name: "buy gold", lhs: .init(exchange: "NSE", tradingSymbol: "GOLDBEES"),
            comparison: .lessThanOrEqual, rhs: .instrument(.init(exchange: "BSE", tradingSymbol: "GOLDBEES"))
        )
        let replacement = AlertBasketCreate.Item(
            exchange: "NSE", tradingSymbol: "GOLDBEES", weight: 10000,
            order: .init(transactionType: "BUY", product: "CNC", orderType: "LIMIT", quantity: 10000, price: 72.22)
        )
        let alert = try await withAlertFixture(
            "alerts_modify_ato.json", method: "PUT", path: "/alerts/\(uuid)"
        ) { request in
            var form = try Self.formBody(request)
            let basket = form.removeValue(forKey: "basket")
            #expect(form == [
                "name": "buy gold", "type": "ato", "lhs_exchange": "NSE",
                "lhs_tradingsymbol": "GOLDBEES", "lhs_attribute": "LastTradedPrice",
                "operator": "<=", "rhs_type": "instrument", "rhs_exchange": "BSE",
                "rhs_tradingsymbol": "GOLDBEES", "rhs_attribute": "LastTradedPrice",
                "status": "disabled",
            ])
            if updateBasket {
                try Self.expectJSON(#require(basket), equals: """
                    {"items":[
                      {"type":"update","id":275218517,"tradingsymbol":"GOLDBEES","exchange":"NSE",
                       "weight":10000,"params":{
                        "transaction_type":"BUY","product":"CNC","order_type":"LIMIT","validity":"DAY",
                        "validity_ttl":0,"quantity":10000,"price":72.22,"trigger_price":0,
                        "disclosed_quantity":0,"variety":"regular","tags":[],"squareoff":0,
                        "stoploss":0,"trailing_stoploss":0
                       }},
                      {"type":"delete","id":99}
                    ]}
                    """)
            } else {
                #expect(basket == nil)
            }
        } operation: { kite in
            let operations: [AlertBasketOperation]? = updateBasket
                ? [.update(id: 275218517, item: replacement), .delete(id: 99)]
                : nil
            return try await kite.modifyAlert(
                uuid: uuid, condition: condition, kind: .ato(basketOperations: operations), status: .disabled
            )
        }

        #expect(alert.type == .ato)
        #expect(alert.status == .disabled)
        #expect(alert.rhsType == .instrument)
        #expect(alert.rhsExchange == "BSE")
        #expect(alert.rhsTradingSymbol == "GOLDBEES")
        #expect(alert.rhsAttribute == "LastTradedPrice")
    }

    @Test(arguments: [false, true]) func deletesAlertsUsingRepeatedUUIDQueryItems(multiple: Bool) async throws {
        let first = Self.simpleUUID
        let second = Self.atoUUID
        try await withAlertFixture(
            "alerts_delete.json", method: "DELETE", path: "/alerts",
            query: multiple ? "uuid=\(first)&uuid=\(second)" : "uuid=\(first)"
        ) { kite in
            if multiple {
                try await kite.deleteAlerts(uuids: [first, second])
            } else {
                try await kite.deleteAlert(uuid: first)
            }
        }
    }

    @Test(arguments: [[], [""]]) func rejectsDeletionWithoutUUIDs(uuids: [String]) async {
        await HTTPStub.withSession { _ in
            Issue.record("A deletion with a missing UUID reached the server")
            return .init(statusCode: 500, body: Data())
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            await #expect(throws: AlertDeletionError.missingUUID) {
                try await kite.deleteAlerts(uuids: uuids)
            }
        }
    }

    @Test(arguments: [false, true]) func retrievesAlertTriggerHistory(ato: Bool) async throws {
        // The ATO fixture adds synthetic order metadata to the pinned alerts_history.json quote.
        let uuid = ato ? Self.atoUUID : Self.simpleUUID
        let fixture = ato ? "alerts_history_ato.json" : "alerts_history.json"
        let history = try await withAlertFixture(fixture, method: "GET", path: "/alerts/\(uuid)/history") { kite in
            try await kite.alertHistory(uuid: uuid)
        }

        let trigger = try #require(history.first)
        #expect(trigger.uuid == uuid)
        #expect(trigger.type == (ato ? .ato : .simple))
        #expect(trigger.createdAt == "2025-02-17 09:16:46")
        #expect(trigger.condition == #"LastTradedPrice("INDICES:NIFTY NEXT 50") <= 58290.35"#)
        let quote = try #require(trigger.meta.first)
        #expect(quote.instrumentToken == 270857)
        #expect(quote.tradingSymbol == "NIFTY NEXT 50")
        #expect(quote.timestamp == "2025-02-17 09:16:46")
        #expect(quote.lastTradeTime == "0001-01-01 00:00:00")
        #expect(quote.lastPrice == 58288.05)
        #expect(quote.ohlc.close == 59557.95)
        #expect(quote.netChange == -1269.9)
        #expect(quote.openInterestDayHigh == 0)
        if ato {
            #expect(trigger.orderMeta == .object(["orders": .array([.object([
                "order_id": .string("250217000000001"), "status": .string("COMPLETE"), "quantity": .number(1),
            ])])]))
        } else {
            #expect(trigger.orderMeta == nil)
        }
    }

    private static func expectJSON(_ actual: String, equals expected: String) throws {
        let actualObject = try #require(try JSONSerialization.jsonObject(with: Data(actual.utf8)) as? NSDictionary)
        let expectedObject = try #require(try JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary)
        #expect(actualObject == expectedObject)
    }

    // Endpoint examples: https://kite.trade/docs/connect/v3/alerts/
    // Unmodified fixtures retain their original filenames from Zerodha's pinned fixture set:
    // https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5
    private func withAlertFixture<Value>(
        _ fixture: String,
        method: String,
        path: String,
        query: String? = nil,
        check: @escaping @Sendable (URLRequest) throws -> Void = { request in
            try #expect(HTTPStub.body(of: request) == nil)
        },
        operation: (KiteConnectClient) async throws -> Value
    ) async throws -> Value {
        let response = try HTTPStub.fixture(fixture)
        return try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            #expect(request.httpMethod == method)
            #expect(url.path == path)
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery == query)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            try check(request)
            return .init(statusCode: 200, body: response)
        } operation: { session, baseURL in
            try await operation(
                KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            )
        }
    }

    private static func formBody(_ request: URLRequest) throws -> [String: String] {
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let data = try #require(try HTTPStub.body(of: request))
        var components = URLComponents()
        components.percentEncodedQuery = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "+", with: "%20")
        let items = try #require(components.queryItems)
        var values: [String: String] = [:]
        for item in items {
            #expect(values.updateValue(try #require(item.value), forKey: item.name) == nil)
        }
        return values
    }
}
