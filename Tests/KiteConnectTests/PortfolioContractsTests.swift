//
//  PortfolioContractsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

private enum PortfolioOperation: CaseIterable, Sendable {
    case holdings, auctions, positions, conversion, authorisation
    var isMutation: Bool {
        self == .conversion || self == .authorisation
    }

    var fixture: String {
        switch self {
        case .holdings: portfolioHoldingsJSON
        case .auctions: portfolioAuctionsJSON
        case .positions: portfolioPositionsJSON
        case .conversion: portfolioConversionJSON
        case .authorisation: portfolioAuthorisationJSON
        }
    }

    func run(_ client: KiteClient) async throws {
        switch self {
        case .holdings: _ = try await client.holdings()
        case .auctions: _ = try await client.auctionHoldings()
        case .positions: _ = try await client.positions()
        case .conversion: _ = try await client.convertPosition(portfolioConversion())
        case .authorisation: _ = try await client.authoriseHoldings()
        }
    }
}

private func portfolioConversion() throws -> KitePositionConversion {
    try KitePositionConversion(
        instrument: KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY"),
        transactionType: .sell, positionType: .day, quantity: 3, oldProduct: .cnc, newProduct: .mis,
    )
}

private func contractClient(_ transport: any KiteHTTPTransport) throws -> KiteClient {
    try KiteClient(apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
}

@Test(arguments: PortfolioOperation.allCases, [401, 428, 429, 503])
private func portfolioConfirmedRejectionIsPreservedWithoutRetry(
    operation: PortfolioOperation, status: Int,
) async throws {
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FuturePortfolioException","message":"Rejected"}"#,
        status: status,
    )
    do {
        try await operation.run(contractClient(transport))
        Issue.record("Expected confirmed rejection")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == status)
        #expect(error.errorType == "FuturePortfolioException")
        #expect(error.message == "Rejected")
    }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: PortfolioOperation.allCases)
private func portfolioTransportFailureIsSingleAttemptAndMutationsAreUncertain(
    operation: PortfolioOperation,
) async throws {
    let transport = FailingHTTP()
    do {
        try await operation.run(contractClient(transport))
        Issue.record("Expected timeout")
    } catch let KiteError.uncertainOutcome(cause) {
        #expect(operation.isMutation)
        guard case let .transport(code, _) = cause else {
            Issue.record("Expected transport cause")
            return
        }
        #expect(code == URLError.timedOut.rawValue)
    } catch let KiteError.transport(code, _) {
        #expect(!operation.isMutation)
        #expect(code == URLError.timedOut.rawValue)
    }
    #expect(await transport.attempts == 1)
}

@Test(arguments: PortfolioOperation.allCases, ["gateway", "malformed-success"])
private func portfolioAmbiguousResponsesKeepMutationUncertainty(
    operation: PortfolioOperation, kind: String,
) async throws {
    let transport = ControlledHTTP(
        kind == "gateway" ? "gateway unavailable" : #"{"status":"success","data":null}"#,
        status: kind == "gateway" ? 502 : 200,
    )
    do {
        try await operation.run(contractClient(transport))
        Issue.record("Expected response failure")
    } catch let KiteError.uncertainOutcome(cause) {
        #expect(operation.isMutation)
        if kind == "gateway" {
            guard case let .api(error) = cause else {
                Issue.record("Expected HTTP failure")
                return
            }
            #expect(error.statusCode == 502)
        } else {
            guard case let .decoding(status, _) = cause else {
                Issue.record("Expected decoding failure")
                return
            }
            #expect(status == 200)
        }
    } catch let error as KiteError {
        #expect(!operation.isMutation)
        switch error {
        case let .api(api): #expect(api.statusCode == 502)
        case let .decoding(status, _): #expect(status == 200)
        default: Issue.record("Unexpected error: \(error)")
        }
    }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: PortfolioOperation.allCases)
private func portfolioCancellationRemainsRecognisable(operation: PortfolioOperation) async throws {
    let client = try contractClient(CancelledHTTP())
    await #expect(throws: CancellationError.self) { try await operation.run(client) }
    let suspended = SuspendedHTTP()
    let cancellable = try contractClient(suspended)
    let task = Task { try await operation.run(cancellable) }
    for await _ in suspended.started {
        break
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test(arguments: PortfolioOperation.allCases)
private func portfolioSessionsAreIsolatedAndReplacementAndTimeoutApply(
    operation: PortfolioOperation,
) async throws {
    let transport = ControlledHTTP(operation.fixture)
    let configuration = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 7,
    )
    let first = try KiteClient(
        apiKey: "first", accessToken: "old", configuration: configuration, transport: transport,
    )
    let second = try KiteClient(
        apiKey: "second", accessToken: "other", configuration: .sandbox, transport: transport,
    )
    async let a: Void = operation.run(first)
    async let b: Void = operation.run(second)
    _ = try await (a, b)
    try await first.replaceAccessToken("new")
    try await operation.run(first)
    let requests = await transport.requests
    #expect(
        Set(requests.prefix(2).compactMap { $0.headers["Authorization"] }) == [
            "token first:old", "token second:other",
        ],
    )
    #expect(requests.last?.headers["Authorization"] == "token first:new")
    #expect(requests.last?.timeout == 7)
    try await first.replaceAccessToken(nil)
    do {
        try await operation.run(first)
        Issue.record("Expected absent credential rejection")
    } catch let KiteError.validation(field, _) { #expect(field == "accessToken") }
    #expect(await transport.requests.count == 3)
}

@Test func portfolioMutationsValidateCurrentStructureBeforeTransport() async throws {
    let transport = ControlledHTTP(portfolioConversionJSON)
    let client = try contractClient(transport)
    for quantity in [Int64(0), -1] {
        var request = try portfolioConversion()
        request.quantity = quantity
        await #expect(throws: KiteError.self) { try await client.convertPosition(request) }
        await #expect(throws: KiteError.self) {
            try await client.authoriseHoldings(instruments: [
                .init(isin: "INE002A01018", quantity: quantity),
            ])
        }
    }
    for value in ["", "  ", "X\nY"] {
        var request = try portfolioConversion()
        request.oldProduct = .unknown(value)
        await #expect(throws: KiteError.self) { try await client.convertPosition(request) }
        request = try portfolioConversion()
        request.newProduct = .unknown(value)
        await #expect(throws: KiteError.self) { try await client.convertPosition(request) }
        await #expect(throws: KiteError.self) {
            try await client.authoriseHoldings(instruments: [.init(isin: value, quantity: 1)])
        }
    }
    #expect(await transport.requests.isEmpty)
}

@Test(arguments: ["2025-01-17 00:00:00", "2025-01-17T00:00:00+05:30", "2025-01-16T18:30:00Z"])
private func portfolioAuthorisedTimestampUsesSharedZonePolicy(timestamp: String) async throws {
    let json = portfolioHoldingsJSON.replacingOccurrences(of: "2025-01-17 00:00:00", with: timestamp)
    let transport = ControlledHTTP(json)
    let client = try contractClient(transport)
    #expect(
        try await client.holdings()[0].authorisedDate == Date(timeIntervalSince1970: 1_737_052_200),
    )
    let utc = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms",
        tradingTimeZone: TimeZone(secondsFromGMT: 0)!,
    )
    let custom = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: utc, transport: transport,
    )
    let expected: TimeInterval = timestamp == "2025-01-17 00:00:00" ? 1_737_072_000 : 1_737_052_200
    #expect(try await custom.holdings()[0].authorisedDate == Date(timeIntervalSince1970: expected))
}

@Test func portfolioReadsPreserveUnknownEnumsPreciseDecimalsAndOptionalAbsence() async throws {
    let changed =
        portfolioHoldingsJSON
            .replacingOccurrences(of: #""NSE""#, with: #""FUTURE_EXCHANGE""#)
            .replacingOccurrences(of: #""CNC""#, with: #""FUTURE_PRODUCT""#)
            .replacingOccurrences(of: "352.95", with: "352.950000000000000001")
            .replacingOccurrences(
                of: #""authorisation": {}"#,
                with: #""authorisation": {"future": {"status":"new", "rate":0.123456789012345678}}"#,
            )
    let holding = try await contractClient(ControlledHTTP(changed)).holdings()[0]
    #expect(holding.exchange == .unknown("FUTURE_EXCHANGE"))
    #expect(holding.product == .unknown("FUTURE_PRODUCT"))
    #expect(holding.lastPrice == Decimal(string: "352.950000000000000001"))
    #expect(
        holding.authorisation?["future"]
            == .object([
                "status": .string("new"), "rate": .number(Decimal(string: "0.123456789012345678")!),
            ]),
    )
    var root =
        try JSONSerialization.jsonObject(with: Data(portfolioHoldingsJSON.utf8)) as! [String: Any]
    var rows = root["data"] as! [[String: Any]]
    for key in [
        "authorised_date", "collateral_type", "authorisation", "mtf", "short_quantity", "used_quantity",
    ] {
        rows[0][key] = NSNull()
        rows[1].removeValue(forKey: key)
    }
    rows[0]["future"] = ["anything": true]
    root["data"] = rows
    let body = try String(decoding: JSONSerialization.data(withJSONObject: root), as: UTF8.self)
    let sparse = try await contractClient(ControlledHTTP(body)).holdings()
    for item in sparse {
        #expect(item.authorisedDate == nil)
        #expect(item.collateralType == nil)
        #expect(item.mtf == nil)
        #expect(item.authorisation == nil)
        #expect(item.shortQuantity == nil)
        #expect(item.usedQuantity == nil)
    }
    let positions =
        portfolioPositionsJSON
            .replacingOccurrences(of: #""MCX""#, with: #""FUTURE""#)
            .replacingOccurrences(of: #""NRML""#, with: #""FUTURE_PRODUCT""#)
            .replacingOccurrences(of: "161.05", with: "161.050000000000000001")
    let result = try await contractClient(ControlledHTTP(positions)).positions()
    #expect(result.net[0].exchange == .unknown("FUTURE"))
    #expect(result.net[0].product == .unknown("FUTURE_PRODUCT"))
    #expect(result.net[0].averagePrice == Decimal(string: "161.050000000000000001"))
}

private let holdingRequiredKeys = [
    "tradingsymbol", "exchange", "instrument_token", "isin", "product", "quantity", "t1_quantity",
    "realised_quantity", "authorised_quantity", "opening_quantity", "collateral_quantity",
    "discrepancy", "price", "average_price", "last_price", "close_price", "pnl", "day_change",
    "day_change_percentage",
]
private let positionRequiredKeys = [
    "tradingsymbol", "exchange", "instrument_token", "product", "quantity", "overnight_quantity",
    "multiplier", "average_price", "close_price", "last_price", "value", "pnl", "m2m", "unrealised",
    "realised", "buy_quantity", "buy_price", "buy_value", "buy_m2m", "sell_quantity", "sell_price",
    "sell_value", "sell_m2m", "day_buy_quantity", "day_buy_price", "day_buy_value",
    "day_sell_quantity", "day_sell_price", "day_sell_value",
]
private let malformedPortfolioFields =
    holdingRequiredKeys.map { "holding:" + $0 }
        + positionRequiredKeys.map { "position:" + $0 }
        + [
            "auction:auction_number", "holding:mtf.quantity", "holding:mtf.used_quantity",
            "holding:mtf.average_price", "holding:mtf.value", "holding:mtf.initial_margin",
        ]

@Test(arguments: malformedPortfolioFields, ["missing", "null", "wrong-type"])
private func portfolioRejectsMalformedRequiredFields(field: String, corruption: String) async throws {
    let parts = field.split(separator: ":").map(String.init)
    let kind = parts[0]
    let key = parts[1]
    let fixture =
        kind == "holding"
            ? portfolioHoldingsJSON : (kind == "auction" ? portfolioAuctionsJSON : portfolioPositionsJSON)
    var root = try JSONSerialization.jsonObject(with: Data(fixture.utf8)) as! [String: Any]
    var rows: [[String: Any]] = if kind == "position" {
        (root["data"] as! [String: Any])["net"] as! [[String: Any]]
    } else {
        root["data"] as! [[String: Any]]
    }
    let replacement: Any? =
        corruption == "missing" ? nil : (corruption == "null" ? NSNull() as Any : ["invalid"] as Any)
    let path = key.split(separator: ".").map(String.init)
    if path.count == 2 {
        var nested = rows[0][path[0]] as! [String: Any]
        nested[path[1]] = replacement
        rows[0][path[0]] = nested
    } else {
        rows[0][key] = replacement
    }
    if kind == "position" {
        var data = root["data"] as! [String: Any]
        data["net"] = rows
        root["data"] = data
    } else {
        root["data"] = rows
    }
    let transport = try ControlledHTTP(
        String(decoding: JSONSerialization.data(withJSONObject: root), as: UTF8.self),
    )
    do {
        if kind == "holding" {
            _ = try await contractClient(transport).holdings()
        } else if kind == "auction" {
            _ = try await contractClient(transport).auctionHoldings()
        } else {
            _ = try await contractClient(transport).positions()
        }
        Issue.record("Expected malformed required data rejection")
    } catch let KiteError.decoding(status, message) {
        #expect(status == 200)
        #expect(message.contains(path.last!))
    }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: ["net", "day"])
private func portfolioRequiresBothPositionCollections(key: String) async throws {
    let json = #"{"status":"success","data":{"KEY":[]}}"#.replacingOccurrences(of: "KEY", with: key)
    await #expect(throws: KiteError.self) {
        try await contractClient(ControlledHTTP(json)).positions()
    }
}

@Test(arguments: [
    #"{"status":"success","data":{}}"#, #"{"status":"success","data":{"request_id":""}}"#,
    #"{"status":"success","data":{"request_id":null}}"#,
])
private func portfolioMalformedAuthorisationReceiptIsUncertain(json: String) async throws {
    let transport = ControlledHTTP(json)
    do {
        _ = try await contractClient(transport).authoriseHoldings()
        Issue.record("Expected uncertain receipt")
    } catch let KiteError.uncertainOutcome(cause) {
        guard case let .decoding(status, _) = cause else {
            Issue.record("Expected decoding cause")
            return
        }
        #expect(status == 200)
    }
    #expect(await transport.requests.count == 1)
}
