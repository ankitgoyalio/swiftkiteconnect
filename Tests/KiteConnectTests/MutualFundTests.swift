import Foundation
import KiteConnect
import Testing

struct MutualFundTests {
    @Test func fetchesMutualFundOrderHistory() async throws {
        // First two entries from https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/mf_orders.json
        try await withMutualFundResponse(path: "/mf/orders", fixture: "mf_orders.json") { kite in
            let orders = try await kite.mutualFundOrders()
            #expect(orders.count == 2)
            let first = try #require(orders.first)
            let last = try #require(orders.last)
            #expect(first.orderID == "271989e0-a64e-4cf3-b4e4-afb8f38dd203")
            #expect(first.exchangeOrderID == "254657127")
            #expect(first.exchangeTimestamp == "2021-06-30")
            #expect(first.tradingSymbol == "INF179K01VY8")
            #expect(first.amount == 1000)
            #expect(last.lastPrice == 52.798)
            #expect(last.exchangeOrderID == nil)
            #expect(last.folio == nil)
        }
    }

    @Test func fetchesAnIndividualMutualFundOrder() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/mf_orders_info.json
        let orderID = "2b6ad4b7-c84e-4c76-b459-f3a8994184f1"
        try await withMutualFundResponse(path: "/mf/orders/\(orderID)", fixture: "mf_orders_info.json") { kite in
            let order = try await kite.mutualFundOrder(orderID: orderID)
            #expect(order.orderID == orderID)
            #expect(order.status == "OPEN")
            #expect(order.quantity == 0)
            #expect(order.amount == 5000)
            #expect(order.lastPriceDate == "2021-06-29")
            #expect(order.settlementID == nil)
        }
    }

    @Test func fetchesOpenSIPsFromAResponseWithoutStatus() async throws {
        // First and third entries from https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/mf_sips.json
        try await withMutualFundResponse(path: "/mf/sips", fixture: "mf_sips.json") { kite in
            let sips = try await kite.mutualFundSIPs()
            #expect(sips.count == 2)
            let first = try #require(sips.first)
            let last = try #require(sips.last)
            #expect(first.sipID == "892741486820670")
            #expect(first.registrationNumber == nil)
            #expect(first.instalmentAmount == 500)
            #expect(first.pendingInstalments == -1)
            #expect(first.nextInstalment == "2021-05-12")
            #expect(first.stepUp == ["05-05": 10])
            #expect(last.registrationNumber == "15158182")
            #expect(last.stepUp == [:])
        }
    }

    @Test func fetchesMutualFundHoldingsWithFractionalUnits() async throws {
        // First entry from https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/mf_holdings.json
        try await withMutualFundResponse(path: "/mf/holdings", fixture: "mf_holdings.json") { kite in
            let holdings = try await kite.mutualFundHoldings()
            #expect(holdings.count == 1)
            let holding = try #require(holdings.first)
            #expect(holding.folio == "3108290884")
            #expect(holding.tradingSymbol == "INF205K01NT8")
            #expect(holding.quantity == 382.488)
            #expect(holding.pledgedQuantity == 0)
            #expect(holding.averagePrice == 78.43)
            #expect(holding.lastPrice == 84.86)
            #expect(holding.lastPriceDate == "")
            #expect(holding.pnl == 0)
        }
    }

    @Test func fetchesTheMutualFundInstrumentCSV() async throws {
        // Header and first and fourth entries from https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/mf_instruments.csv
        try await withMutualFundResponse(path: "/mf/instruments", fixture: "mf_instruments.csv") { kite in
            let instruments = try await kite.mutualFundInstruments()
            #expect(instruments.count == 2)
            let first = try #require(instruments.first)
            let last = try #require(instruments.last)
            #expect(first.tradingSymbol == "INF209K01157")
            #expect(first.amc == "BirlaSunLifeMutualFund_MF")
            #expect(first.purchaseAllowed)
            #expect(first.redemptionAllowed)
            #expect(first.minimumPurchaseAmount == 1000)
            #expect(first.minimumAdditionalPurchaseAmount == 1000)
            #expect(first.minimumRedemptionQuantity == 0.001)
            #expect(first.redemptionQuantityMultiplier == 0.001)
            #expect(first.settlementType == "T3")
            #expect(first.lastPrice == 106.8)
            #expect(first.lastPriceDate == "2017-11-23")
            #expect(last.name == "Aditya Birla Sun Life Advantage Fund - Direct Plan")
            #expect(last.plan == "direct")
        }
    }

    @Test(arguments: [200, 403])
    func sipRequestsSurfaceKiteServiceErrors(statusCode: Int) async throws {
        let body = Data(#"{"status":"error","error_type":"TokenException","message":"Invalid session.","data":[]}"#.utf8)
        try await withMutualFundResponse(path: "/mf/sips", body: body, statusCode: statusCode) { kite in
            do {
                _ = try await kite.mutualFundSIPs()
                Issue.record("Expected a Kite service error")
            } catch KiteError.service(let error) {
                #expect(error.statusCode == statusCode)
                #expect(error.isSessionExpired)
            }
        }
    }

    @Test func mutualFundOrderHistoryRequiresASuccessStatus() async throws {
        let body = Data(#"{"data":[]}"#.utf8)
        try await withMutualFundResponse(path: "/mf/orders", body: body) { kite in
            do {
                _ = try await kite.mutualFundOrders()
                Issue.record("Expected a decoding failure")
            } catch KiteError.decoding(let error) {
                guard case DecodingError.keyNotFound(let key, _) = error else {
                    Issue.record("Expected a missing status key: \(error)")
                    return
                }
                #expect(key.stringValue == "status")
            }
        }
    }

    private func withMutualFundResponse(
        path: String,
        fixture: String,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        let body = try HTTPStub.fixture(fixture)
        let contentType = fixture.hasSuffix(".csv") ? "text/csv" : "application/json"
        try await withMutualFundResponse(path: path, body: body, contentType: contentType, operation: operation)
    }

    private func withMutualFundResponse(
        path: String,
        body: Data,
        contentType: String = "application/json",
        statusCode: Int = 200,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            #expect(request.httpMethod == "GET")
            #expect(components.percentEncodedPath == path)
            #expect(components.percentEncodedQuery == nil)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            try #expect(HTTPStub.body(of: request) == nil)
            return .init(statusCode: statusCode, body: body, headers: ["Content-Type": contentType])
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            try await operation(kite)
        }
    }
}
