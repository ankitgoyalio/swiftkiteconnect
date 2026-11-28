import Foundation
import KiteConnect
import Testing

struct AccountReadTests {
    @Test func fetchesMarginsAcrossSegments() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/margins.json
        try await withAccountResponse("account_margins.json", path: "/user/margins") { kite in
            let margins = try await kite.margins()

            #expect(margins.equity.enabled)
            #expect(margins.equity.net == 99725.05000000002)
            #expect(margins.equity.available.cash == 245431.6)
            #expect(margins.equity.available.liveBalance == 99725.05000000002)
            #expect(margins.equity.utilised.m2mRealised == 761.7)
            #expect(margins.equity.utilised.span == 101989)
            #expect(margins.commodity?.net == 100661.7)
            #expect(margins.commodity?.utilised.debits == 0)
        }
    }

    @Test(arguments: [MarginSegment.equity, .commodity])
    func fetchesMarginsForSingleSegment(segment: MarginSegment) async throws {
        // Omit live_balance for equity and set it to null for commodity.
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/margins_equity.json
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/margin_commodity.json
        try await withAccountResponse(
            "account_margins_\(segment.rawValue).json",
            path: "/user/margins/\(segment == .equity ? "equity" : "commodity")"
        ) { kite in
            let margins = try await kite.margins(segment: segment)

            #expect(margins.enabled)
            #expect(margins.available.liveBalance == nil)
            switch segment {
            case .equity:
                #expect(margins.net == 99725.05000000002)
                #expect(margins.utilised.span == 101989)
            case .commodity:
                #expect(margins.net == 96426.33)
                #expect(margins.utilised.span == 563)
            }
        }
    }

    @Test func preservesNetAndDayPositions() async throws {
        // GOLDGUINEA rows from the net and day sets:
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/positions.json
        try await withAccountResponse("account_positions.json", path: "/portfolio/positions") { kite in
            let positions = try await kite.positions()

            #expect(positions.net.count == 1)
            #expect(positions.day.count == 1)
            let net = try #require(positions.net.first)
            let day = try #require(positions.day.first)
            #expect(net.tradingSymbol == "GOLDGUINEA17DECFUT")
            #expect(net.exchange == "MCX")
            #expect(net.instrumentToken == 53_505_799)
            #expect(net.product == "NRML")
            #expect(net.quantity == 0)
            #expect(net.overnightQuantity == 3)
            #expect(net.multiplier == 1)
            #expect(net.averagePrice == 0)
            #expect(net.closePrice == 23_232)
            #expect(net.lastPrice == 23_355)
            #expect(net.value == 801)
            #expect(net.pnl == 801)
            #expect(net.m2m == 276)
            #expect(net.unrealised == 801)
            #expect(net.realised == 0)
            #expect(net.buyQuantity == 4)
            #expect(net.buyPrice == 23_139.75)
            #expect(net.buyValue == 92_559)
            #expect(net.buyM2M == 93_084)
            #expect(net.sellQuantity == 4)
            #expect(net.sellPrice == 23_340)
            #expect(net.sellValue == 93_360)
            #expect(net.sellM2M == 93_360)
            #expect(net.dayBuyQuantity == 1)
            #expect(net.dayBuyPrice == 23_388)
            #expect(net.dayBuyValue == 23_388)
            #expect(net.daySellQuantity == 4)
            #expect(net.daySellPrice == 23_340)
            #expect(net.daySellValue == 93_360)
            #expect(day.tradingSymbol == "GOLDGUINEA17DECFUT")
            #expect(day.quantity == -3)
            #expect(day.overnightQuantity == 0)
            #expect(day.buyQuantity == 1)
            #expect(day.pnl == -93)
        }
    }

    @Test func fetchesEquityHoldingsWithOptionalDetails() async throws {
        // The second holding has null collateral_type, authorised_date and day changes.
        // It omits mtf, short_quantity and authorisation. The first has an example pre-trade authorisation.
        // https://kite.trade/forum/discussion/15315/why-quantity-t1-quantity-realised-quantity-for-this-holding
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/holdings.json
        try await withAccountResponse("account_holdings.json", path: "/portfolio/holdings") { kite in
            let holdings = try await kite.holdings()

            try #require(holdings.count == 2)
            let holding = holdings[0]
            #expect(holding.tradingSymbol == "AARON")
            #expect(holding.exchange == "NSE")
            #expect(holding.instrumentToken == 263_681)
            #expect(holding.isin == "INE721Z01010")
            #expect(holding.product == "CNC")
            #expect(holding.price == 0)
            #expect(holding.quantity == 1)
            #expect(holding.usedQuantity == 0)
            #expect(holding.t1Quantity == 0)
            #expect(holding.realisedQuantity == 1)
            #expect(holding.authorisedQuantity == 1)
            #expect(holding.authorisedDate == "2025-01-17 00:00:00")
            #expect(holding.authorisation?["pre"]?["2025-01-17 00:00:00"] == 1)
            #expect(holding.openingQuantity == 1)
            #expect(holding.shortQuantity == 0)
            #expect(holding.collateralQuantity == 0)
            #expect(holding.collateralType == "")
            #expect(!holding.discrepancy)
            #expect(holding.averagePrice == 161)
            #expect(holding.lastPrice == 352.95)
            #expect(holding.closePrice == 352.35)
            #expect(holding.pnl == 191.95)
            #expect(holding.dayChange == 0.5999999999999659)
            #expect(holding.dayChangePercentage == 0.17028522775648244)
            let mtf = try #require(holding.mtf)
            #expect(mtf.quantity == 1000)
            #expect(mtf.usedQuantity == 0)
            #expect(mtf.averagePrice == 100)
            #expect(mtf.value == 100_000)
            #expect(mtf.initialMargin == 0)

            let withoutDetails = holdings[1]
            #expect(withoutDetails.tradingSymbol == "SBIN")
            #expect(withoutDetails.quantity == 16)
            #expect(withoutDetails.authorisedDate == nil)
            #expect(withoutDetails.authorisation == nil)
            #expect(withoutDetails.shortQuantity == nil)
            #expect(withoutDetails.collateralType == nil)
            #expect(withoutDetails.dayChange == nil)
            #expect(withoutDetails.dayChangePercentage == nil)
            #expect(withoutDetails.mtf == nil)
        }
    }

    private func withAccountResponse(
        _ filename: String,
        path: String,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        let fixture = try HTTPStub.fixture(filename)
        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == path)
            #expect(request.url?.query == nil)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            try #expect(HTTPStub.body(of: request) == nil)
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            try await operation(kite)
        }
    }
}
