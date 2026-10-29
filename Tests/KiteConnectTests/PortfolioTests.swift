//
//  PortfolioTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

private func portfolioClient(_ transport: any KiteHTTPTransport) throws -> KiteClient {
    try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token", configuration: .sandbox,
        transport: transport,
    )
}

@Test func portfolioHoldingsDecodeOfficialFinancialAndAuthorisationData() async throws {
    let transport = ControlledHTTP(portfolioHoldingsJSON)
    let values = try await portfolioClient(transport).holdings()
    #expect(values.count == 2)
    let holding = values[0]
    #expect(try holding.identity == KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "AARON"))
    #expect(holding.instrumentToken == 263_681)
    #expect(holding.isin == "INE721Z01010")
    #expect(holding.product == .cnc)
    #expect(holding.quantity == 1)
    #expect(holding.usedQuantity == 0)
    #expect(holding.shortQuantity == 0)
    #expect(holding.authorisedDate == Date(timeIntervalSince1970: 1_737_052_200))
    #expect(holding.authorisation == [:])
    #expect(holding.dayChange == Decimal(string: "0.5999999999999659"))
    #expect(holding.mtf?.quantity == 1000)
    #expect(holding.mtf?.value == 100_000)
    #expect(values[1].averagePrice == Decimal(string: "801.78125"))
    let requests = await transport.requests
    #expect(requests.count == 1)
    #expect(requests[0].url.absoluteString == "https://sandbox.kite.trade/oms/portfolio/holdings")
    #expect(requests[0].method == .get)
    #expect(requests[0].body == nil)
    #expect(requests[0].headers["X-Kite-Version"] == "3")
    #expect(requests[0].headers["Authorization"] == "token fixture-key:fixture-token")
}

@Test func portfolioAuctionHoldingsPreserveAuctionIdentityAndSparseMetadata() async throws {
    let transport = ControlledHTTP(portfolioAuctionsJSON)
    let values = try await portfolioClient(transport).auctionHoldings()
    #expect(values.count == 3)
    #expect(values[0].auctionNumber == "20")
    #expect(values[2].auctionNumber == "7529")
    #expect(values[0].holding.tradingSymbol == "ASHOKLEY")
    #expect(values[0].holding.pnl == Decimal(string: "10.550000000000011"))
    #expect(values[0].holding.mtf == nil)
    #expect(values[0].holding.usedQuantity == nil)
    #expect(values[0].holding.authorisation == nil)
    let requests = await transport.requests
    #expect(requests.count == 1)
    #expect(requests[0].method == .get)
    #expect(requests[0].url.path == "/oms/portfolio/holdings/auctions")
}

@Test func portfolioPositionsSeparateNetAndDayActivityWithSignedQuantities() async throws {
    let transport = ControlledHTTP(portfolioPositionsJSON)
    let values = try await portfolioClient(transport).positions()
    #expect(values.net.count == 3)
    #expect(values.day.count == 3)
    let position = values.net[0]
    #expect(
        try position.identity
            == KiteInstrumentIdentity(exchange: .mcx, tradingSymbol: "LEADMINI17DECFUT"),
    )
    #expect(position.instrumentToken == 53_496_327)
    #expect(position.product == .nrml)
    #expect(position.multiplier == 1000)
    #expect(position.averagePrice == Decimal(string: "161.05"))
    #expect(position.value == -161_050)
    #expect(position.buyM2M == 161_050)
    #expect(position.dayBuyQuantity == 1)
    #expect(values.day[0].quantity == -3)
    #expect(values.day[0].pnl == -93)
    let requests = await transport.requests
    #expect(requests.count == 1)
    #expect(requests[0].method == .get)
    #expect(requests[0].url.path == "/oms/portfolio/positions")
}

@Test func portfolioConversionUsesDocumentedPutFormAndBooleanResult() async throws {
    let transport = ControlledHTTP(portfolioConversionJSON)
    let conversion = try KitePositionConversion(
        instrument: KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY"),
        transactionType: .buy, positionType: .overnight, quantity: 3,
        oldProduct: .nrml, newProduct: .mis,
    )
    #expect(try await portfolioClient(transport).convertPosition(conversion))
    let requests = await transport.requests
    #expect(requests.count == 1)
    #expect(requests[0].url.path == "/oms/portfolio/positions")
    #expect(requests[0].method == .put)
    #expect(requests[0].headers["Content-Type"] == "application/x-www-form-urlencoded")
    #expect(
        String(decoding: requests[0].body!, as: UTF8.self)
            == "tradingsymbol=INFY&exchange=NSE&transaction_type=BUY&position_type=overnight&quantity=3&old_product=NRML&new_product=MIS",
    )
    let declined = try portfolioClient(ControlledHTTP(#"{"status":"success","data":false}"#))
    #expect(try await declined.convertPosition(conversion) == false)
}

@Test func portfolioAuthorisationSendsOptionalRepeatedPairsInDocumentedOrder() async throws {
    let transport = ControlledHTTP(portfolioAuthorisationJSON)
    let client = try portfolioClient(transport)
    let receipt = try await client.authoriseHoldings(instruments: [
        KiteHoldingsAuthorisationItem(isin: "INE002A01018", quantity: 50),
        KiteHoldingsAuthorisationItem(isin: "INE009A01021", quantity: 50),
    ])
    #expect(receipt.requestID == "na8QgCeQm05UHG6NL9sAGRzdfSF64UdB")
    _ = try await client.authoriseHoldings()
    let requests = await transport.requests
    #expect(requests.count == 2)
    #expect(requests[0].url.path == "/oms/portfolio/holdings/authorise")
    #expect(requests[0].method == .post)
    #expect(requests[0].headers["Authorization"] == "token fixture-key:fixture-token")
    #expect(requests[0].headers["X-Kite-Version"] == "3")
    #expect(requests[0].headers["Content-Type"] == "application/x-www-form-urlencoded")
    #expect(
        String(decoding: requests[0].body!, as: UTF8.self)
            == "isin=INE002A01018&quantity=50&isin=INE009A01021&quantity=50",
    )
    #expect(requests[1].body == Data())
}

@Test func portfolioAuthorisationBrowserFlowBuildsAndRecognisesOnlyItsOwnFinishURL() throws {
    let transport = ControlledHTTP()
    let client = try portfolioClient(transport)
    let flow = try client.holdingsAuthorisationFlow(requestID: "request&one")
    #expect(
        flow.url.absoluteString
            == "https://kite.zerodha.com/connect/portfolio/authorise/holdings/fixture-key/request%26one",
    )
    let finish =
        "https://kite.zerodha.com/connect/portfolio/authorise/holdings/fixture-key/request%26one/finish"
    #expect(flow.completionStatus(for: URL(string: finish + "?status=success")!) == .success)
    #expect(flow.completionStatus(for: URL(string: finish + "?status=error")!) == .error)
    #expect(flow.completionStatus(for: URL(string: finish + "?status=future")!) == .unknown("future"))
    for url in [
        finish, finish + "?status=", finish + "?status=success&status=error",
        finish.replacingOccurrences(of: "https:", with: "http:") + "?status=success",
        finish.replacingOccurrences(of: "kite.zerodha.com", with: "example.test") + "?status=success",
        finish.replacingOccurrences(of: "fixture-key", with: "another-key") + "?status=success",
        finish.replacingOccurrences(of: "request%26one", with: "another-request") + "?status=success",
        finish + "/other?status=success",
    ] {
        #expect(flow.completionStatus(for: URL(string: url)!) == nil)
    }
    #expect(throws: KiteError.self) { try client.holdingsAuthorisationFlow(requestID: " ") }
}

@Test func portfolioBrowserFlowRejectsDotPathSegments() throws {
    let client = try portfolioClient(ControlledHTTP())
    for value in [".", ".."] {
        #expect(throws: KiteError.self) { try client.holdingsAuthorisationFlow(requestID: value) }
    }
}
