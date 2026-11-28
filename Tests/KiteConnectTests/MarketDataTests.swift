import Foundation
import KiteConnect
import Testing

struct MarketDataTests {
    @Test func fetchesInstrumentsAcrossExchanges() async throws {
        // Header, CENTRALBK-BE and BANKNIFTY18JAN23500CE from instruments_all.csv:
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/instruments_all.csv
        try await withMarketResponse(path: "/instruments", fixture: "instruments_all.csv") { kite in
            let instruments = try await kite.instruments()
            #expect(instruments.map(\.exchange) == ["NSE", "NFO"])

            let equity = try #require(instruments.first)
            let token: UInt32 = equity.instrumentToken
            #expect(token == 3_813_889)
            #expect(equity.exchangeToken == 14_898)
            #expect(equity.tradingSymbol == "CENTRALBK-BE")
            #expect(equity.name == "CENTRAL BANK OF INDIA")
            #expect(equity.expiry == nil)

            let option = try #require(instruments.last)
            #expect(option.name.isEmpty)
            #expect(option.instrumentType == "CE")
            #expect(option.segment == "NFO-OPT")
            #expect(option.expiry == "2018-01-25")
            #expect(option.lastPrice == 2528.4)
            #expect(option.strike == 23_500)
            #expect(option.tickSize == 0.05)
            #expect(option.lotSize == 40)
        }
    }

    @Test func fetchesInstrumentsForAnExchange() async throws {
        // Header and CENTRALBK-BE from instruments_nse.csv:
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/instruments_nse.csv
        try await withMarketResponse(path: "/instruments/NSE", fixture: "instruments_nse.csv") { kite in
            let instruments = try await kite.instruments(exchange: "NSE")
            #expect(instruments.map(\.exchange) == ["NSE"])
            #expect(instruments.map(\.tradingSymbol) == ["CENTRALBK-BE"])
        }
    }

    @Test(arguments: ["/instruments", "/mf/instruments"])
    func reportsSessionExpiryOnSuccessfulHTTPStatus(path: String) async throws {
        let response = Data(#"{"status":"error","error_type":"TokenException","message":"expired"}"#.utf8)
        try await withMarketResponse(path: path, body: response, contentType: "application/json") { kite in
            do {
                if path == "/instruments" {
                    _ = try await kite.instruments()
                } else {
                    _ = try await kite.mutualFundInstruments()
                }
                Issue.record("Expected Kite's session error.")
            } catch KiteError.service(let error) {
                #expect(error.isSessionExpired)
                #expect(error.statusCode == 200)
            }
        }
    }

    @Test func preservesQuotedCSVContentAndEmptyFields() async throws {
        // Synthetic variant of the documented instrument header and an NFO futures row.
        let body = Data("""
            \u{FEFF}exchange,instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,extra\r
            NFO,5720322,22345,NIFTY15DECFUT,"Nifty, ""December""\r\nFutures",78.0,2015-12-31,,0.05,75,FUT,NFO-FUT,
            """.utf8)
        try await withMarketResponse(path: "/instruments/NFO", body: body, contentType: "text/csv") { kite in
            let instruments = try await kite.instruments(exchange: "NFO")
            #expect(instruments.count == 1)
            let instrument = try #require(instruments.first)
            #expect(instrument.name == "Nifty, \"December\"\r\nFutures")
            #expect(instrument.strike == nil)
            #expect(instrument.tickSize == 0.05)
            #expect(instrument.exchange == "NFO")
        }
    }

    @Test(arguments: [
        "5720322,22345,NIFTY15DECFUT,,78.0,2015-12-31,,0.05,75,FUT,NFO-FUT",
        "5720322,22345,NIFTY15DECFUT,\",78.0,2015-12-31,,0.05,75,FUT,NFO-FUT,NFO",
        "5720322,22345,NIFTY15DECFUT,\"Nifty\"X,78.0,2015-12-31,,0.05,75,FUT,NFO-FUT,NFO",
        "4294967296,22345,NIFTY15DECFUT,,78.0,2015-12-31,,0.05,75,FUT,NFO-FUT,NFO",
        "5720322,22345,NIFTY15DECFUT,,78.0,2015-12-31,,NaN,75,FUT,NFO-FUT,NFO",
        "5720322,22345,,,78.0,2015-12-31,,0.05,75,FUT,NFO-FUT,NFO",
    ])
    func rejectsMalformedCSVRows(afterValidRows malformedRow: String) async throws {
        var body = try HTTPStub.fixture("instruments_all.csv")
        body.append(contentsOf: malformedRow.utf8)
        try await withMarketResponse(path: "/instruments", body: body, contentType: "text/csv") { kite in
            do {
                _ = try await kite.instruments()
                Issue.record("Expected the malformed row to fail the request.")
            } catch KiteError.decoding {
                // The endpoint exposes CSV failures through the same error case as JSON failures.
            }
        }
    }

    @Test func fetchesMarketQuotesWithRepeatedInstrumentKeys() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/quote.json
        let infy = InstrumentKey(exchange: "NSE", tradingSymbol: "INFY")
        let missing = InstrumentKey(exchange: "NSE", tradingSymbol: "M&M")
        try await withMarketResponse(path: "/quote", fixture: "quote.json", query: "i=NSE%3AINFY&i=NSE%3AM%26M") { kite in
            let quotes = try await kite.quote(instruments: [infy, missing])
            #expect(quotes.count == 1)
            #expect(quotes[missing.rawValue] == nil)

            let quote = try #require(quotes[infy.rawValue])
            let token: UInt32 = quote.instrumentToken
            #expect(token == 408_065)
            #expect(quote.timestamp == "2021-06-08 15:45:56")
            #expect(quote.lastTradeTime == "2021-06-08 15:45:52")
            #expect(quote.lastPrice == 1412.95)
            #expect(quote.lastQuantity == 5)
            #expect(quote.buyQuantity == 0)
            #expect(quote.sellQuantity == 5191)
            #expect(quote.volume == 7_360_198)
            #expect(quote.averagePrice == 1412.47)
            #expect(quote.openInterest == 0)
            #expect(quote.openInterestDayHigh == 0)
            #expect(quote.openInterestDayLow == 0)
            #expect(quote.netChange == 0)
            #expect(quote.lowerCircuitLimit == 1250.7)
            #expect(quote.upperCircuitLimit == 1528.6)
            #expect(quote.ohlc.close == 1389.65)
            let bestAsk = try #require(quote.depth?.sell.first)
            #expect(bestAsk.price == 1412.95)
            #expect(bestAsk.quantity == 5191)
            #expect(bestAsk.orders == 13)
        }
    }

    @Test func fetchesOHLCQuotesAndEncodesSpaces() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/ohlc.json
        let infy = InstrumentKey(exchange: "NSE", tradingSymbol: "INFY")
        let missing = InstrumentKey(exchange: "NSE", tradingSymbol: "NIFTY 50")
        try await withMarketResponse(
            path: "/quote/ohlc", fixture: "ohlc.json", query: "i=NSE%3AINFY&i=NSE%3ANIFTY%2050"
        ) { kite in
            let quotes = try await kite.ohlc(instruments: [infy, missing])
            #expect(quotes[missing.rawValue] == nil)
            let quote = try #require(quotes[infy.rawValue])
            let token: UInt32 = quote.instrumentToken
            #expect(token == 408_065)
            #expect(quote.lastPrice == 1075)
            #expect(quote.ohlc.open == 1085.8)
            #expect(quote.ohlc.high == 1085.9)
            #expect(quote.ohlc.low == 1070.9)
            #expect(quote.ohlc.close == 1075.8)
        }
    }

    @Test func fetchesLastTradedPricesAndEncodesLiteralPlus() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/ltp.json
        let infy = InstrumentKey(exchange: "NSE", tradingSymbol: "INFY")
        let missing = InstrumentKey(exchange: "BSE", tradingSymbol: "A+B")
        try await withMarketResponse(
            path: "/quote/ltp", fixture: "ltp.json", query: "i=NSE%3AINFY&i=BSE%3AA%2BB"
        ) { kite in
            let quotes = try await kite.ltp(instruments: [infy, missing])
            #expect(quotes[missing.rawValue] == nil)
            let quote = try #require(quotes[infy.rawValue])
            let token: UInt32 = quote.instrumentToken
            #expect(token == 408_065)
            #expect(quote.lastPrice == 1074.35)
        }
    }

    private func withMarketResponse(
        path: String,
        fixture: String,
        query: String? = nil,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        let body = try HTTPStub.fixture(fixture)
        let contentType = fixture.hasSuffix(".csv") ? "text/csv" : "application/json"
        try await withMarketResponse(path: path, body: body, contentType: contentType, query: query, operation: operation)
    }

    private func withMarketResponse(
        path: String,
        body: Data,
        contentType: String,
        query: String? = nil,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            #expect(request.httpMethod == "GET")
            #expect(url.path == path)
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery == query)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            try #expect(HTTPStub.body(of: request) == nil)
            return .init(statusCode: 200, body: body, headers: ["Content-Type": contentType])
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            try await operation(kite)
        }
    }
}
