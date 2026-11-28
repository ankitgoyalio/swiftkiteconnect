import Foundation
import KiteConnect
import Testing

struct PortfolioOperationTests {
    // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/holdings_auth.json
    @Test func authorisesSelectedHoldingsWithRepeatedFormFields() async throws {
        try await withPortfolioResponse(
            "holdings_authorisation.json",
            method: "POST",
            path: "/portfolio/holdings/authorise",
            form: "isin=INE002A01018&quantity=50&isin=INE009A01021&quantity=3"
        ) { kite in
            let authorisation = try await kite.authoriseHoldings([
                .init(isin: "INE002A01018", quantity: 50),
                .init(isin: "INE009A01021", quantity: 3),
            ])

            #expect(authorisation.requestID == "na8QgCeQm05UHG6NL9sAGRzdfSF64UdB")
            #expect(authorisation.redirectURL.absoluteString ==
                "https://kite.zerodha.com/connect/portfolio/authorise/holdings/test-key/na8QgCeQm05UHG6NL9sAGRzdfSF64UdB")
        }
    }

    @Test func authorisesAllHoldingsWithoutFormFields() async throws {
        try await withPortfolioResponse(
            "holdings_authorisation.json",
            method: "POST",
            path: "/portfolio/holdings/authorise",
            form: ""
        ) { kite in
            let authorisation = try await kite.authoriseHoldings()
            #expect(authorisation.requestID == "na8QgCeQm05UHG6NL9sAGRzdfSF64UdB")
        }
    }

    @Test func authorisesQuantityFromRetrievedHolding() async throws {
        try await withPortfolioResponse(
            "holdings_authorisation.json",
            method: "POST",
            path: "/portfolio/holdings/authorise",
            form: "isin=INE062A01020&quantity=2",
            precedingRead: ("/portfolio/holdings", "account_holdings.json")
        ) { kite in
            let holdings = try await kite.holdings()
            let holding = try #require(holdings.first { $0.tradingSymbol == "SBIN" })
            let authorisation = try await kite.authoriseHoldings([.init(holding: holding, quantity: 2)])
            #expect(authorisation.requestID == "na8QgCeQm05UHG6NL9sAGRzdfSF64UdB")
        }
    }

    // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/convert_position.json
    @Test func convertsPositionWithDocumentedForm() async throws {
        try await withPortfolioResponse(
            "position_conversion.json",
            method: "PUT",
            path: "/portfolio/positions",
            form: "tradingsymbol=INFY&exchange=NSE&transaction_type=BUY&position_type=overnight&quantity=3&old_product=NRML&new_product=MIS"
        ) { kite in
            let converted = try await kite.convertPosition(.init(
                tradingSymbol: "INFY",
                exchange: "NSE",
                transactionType: .buy,
                positionType: .overnight,
                quantity: 3,
                oldProduct: "NRML",
                newProduct: "MIS"
            ))

            #expect(converted)
        }
    }

    @Test func convertsQuantityFromRetrievedDayPosition() async throws {
        try await withPortfolioResponse(
            "position_conversion.json",
            method: "PUT",
            path: "/portfolio/positions",
            form: "tradingsymbol=GOLDGUINEA17DECFUT&exchange=MCX&transaction_type=SELL&position_type=day&quantity=2&old_product=NRML&new_product=MIS",
            precedingRead: ("/portfolio/positions", "account_positions.json")
        ) { kite in
            let positions = try await kite.positions()
            let position = try #require(positions.day.first)
            let converted = try await kite.convertPosition(.init(
                position: position,
                transactionType: .sell,
                positionType: .day,
                quantity: 2,
                newProduct: "MIS"
            ))

            #expect(converted)
        }
    }

    // First two entries from the pinned fixture:
    // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/auctions_list.json
    @Test func listsAuctionsWithInstrumentAndAuctionIdentifiers() async throws {
        try await withPortfolioResponse(
            "holdings_auctions.json",
            method: "GET",
            path: "/portfolio/holdings/auctions"
        ) { kite in
            let auctions = try await kite.auctions()

            try #require(auctions.count == 2)
            let first = auctions[0]
            #expect(first.auctionNumber == "20")
            #expect(first.tradingSymbol == "ASHOKLEY")
            #expect(first.exchange == "NSE")
            #expect(first.instrumentToken == 54_282)
            #expect(first.isin == "INE208A01029")
            #expect(first.quantity == 1)
            #expect(first.lastPrice == 142.5)
            #expect(auctions[1].auctionNumber == "34")
            #expect(auctions[1].instrumentToken == 112_138)
            #expect(auctions[1].quantity == 5)
        }
    }

    private func withPortfolioResponse(
        _ filename: String,
        method: String,
        path: String,
        form: String? = nil,
        precedingRead: (path: String, fixture: String)? = nil,
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        let fixture = try HTTPStub.fixture(filename)
        try await HTTPStub.withSession { request in
            #expect(request.url?.query == nil)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            let body = try HTTPStub.body(of: request)
            if let precedingRead, request.httpMethod == "GET", request.url?.path == precedingRead.path {
                #expect(body == nil)
                return .init(statusCode: 200, body: try HTTPStub.fixture(precedingRead.fixture))
            }
            #expect(request.httpMethod == method)
            #expect(request.url?.path == path)
            if let form {
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
                #expect((body ?? Data()) == Data(form.utf8))
            } else {
                #expect(body == nil)
            }
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            try await operation(kite)
        }
    }
}
