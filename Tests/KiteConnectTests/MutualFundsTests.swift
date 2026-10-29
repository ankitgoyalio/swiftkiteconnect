//
//  MutualFundsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func mfOrdersReturnsTypedDocumentedOrders() async throws {
    let transport = ControlledHTTP(mfOrdersJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let orders = try await client.mutualFundOrders()
    let order = try #require(orders.first)
    #expect(orders.count == 5)
    #expect(order.orderID == "271989e0-a64e-4cf3-b4e4-afb8f38dd203")
    #expect(order.status == .rejected)
    #expect(order.amount == 1000)
    #expect(order.quantity == 0)
    #expect(try order.exchangeTimestamp == KiteDateOnly("2021-06-30"))
    #expect(try order.lastPriceDate == KiteDateOnly("2021-06-29"))
    #expect(order.orderTimestamp == Date(timeIntervalSince1970: 1_625_022_187))
    #expect(order.price == nil) // Attribute table lists price; official examples omit it.
    let request = try #require(await transport.requests.first)
    #expect(request.url.path == "/oms/mf/orders")
    #expect(request.method == .get)
    #expect(request.headers["Authorization"] == "token key:token")
    #expect(request.headers["X-Kite-Version"] == "3")
    #expect(request.body == nil)
}

@Test func mfIndividualOrderSupportsExternalIDAndValidatesPath() async throws {
    let transport = ControlledHTTP(mfOrderJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let order = try await client.mutualFundOrder(orderID: "external-123")
    #expect(order.orderID == "2b6ad4b7-c84e-4c76-b459-f3a8994184f1")
    #expect(order.exchangeTimestamp == nil)
    #expect(order.transactionType == .buy)
    #expect(order.variety == .regular)
    #expect(order.purchaseType == .fresh)
    #expect(await transport.requests.first?.url.path == "/oms/mf/orders/external-123")
    for id in ["", "..", "a/b", "a?b", "a#b", "a\\b", "a b", "a\u{0}b"] {
        await #expect(throws: KiteError.self) { try await client.mutualFundOrder(orderID: id) }
    }
    #expect(await transport.requests.count == 1)
}

@Test func mfSIPsReturnsActiveAndPausedPlansWithDatesAndAmounts() async throws {
    let transport = ControlledHTTP(mfSIPsJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let sips = try await client.mutualFundSIPs()
    let sip = try #require(sips.first)
    #expect(sips.count == 5)
    #expect(sip.sipID == "892741486820670")
    #expect(sip.status == .active)
    #expect(sip.dividendType == .idcw)
    #expect(sip.frequency == .weekly)
    #expect(sip.instalmentAmount == 500)
    #expect(sip.instalments == -1)
    #expect(try sip.nextInstalment == KiteDateOnly("2021-05-12"))
    #expect(sip.created == Date(timeIntervalSince1970: 1_620_174_387))
    #expect(sip.lastInstalment == sip.created)
    #expect(sip.stepUp == ["05-05": 10])
    #expect(sips[2].sipType == .amcSIP)
    #expect(sips[2].registrationNumber == "15158182")
    let request = try #require(await transport.requests.first)
    #expect(request.url.path == "/oms/mf/sips")
    #expect(request.method == .get)
    #expect(request.headers["Authorization"] == "token key:token")
    #expect(request.headers["X-Kite-Version"] == "3")
}

@Test func mfHoldingsPreservesFractionalUnitsAndEmptyNAVDate() async throws {
    let transport = ControlledHTTP(mfHoldingsJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let holdings = try await client.mutualFundHoldings()
    let holding = try #require(holdings.first)
    #expect(holdings.count == 3)
    #expect(holding.quantity == Decimal(string: "382.488"))
    #expect(holding.pledgedQuantity == 0)
    #expect(holding.averagePrice == Decimal(string: "78.43"))
    #expect(holding.lastPrice == Decimal(string: "84.86"))
    #expect(holding.pnl == 0)
    #expect(holding.lastPriceDate == nil)
    #expect(holding.folio == "3108290884")
    let request = try #require(await transport.requests.first)
    #expect(request.url.path == "/oms/mf/holdings")
    #expect(request.method == .get)
    #expect(request.headers["Authorization"] == "token key:token")
    #expect(request.headers["X-Kite-Version"] == "3")
}

@Test func mfInstrumentsDownloadsIndependentTypedCatalogueUsingOMSPrefix() async throws {
    let transport = ControlledHTTP(mfCSV)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let instruments = try await client.mutualFundInstruments()
    let instrument = try #require(instruments.first)
    #expect(instruments.count == 4)
    #expect(instrument.tradingSymbol == "INF846K01DP8")
    #expect(instrument.amc == "AXISMUTUALFUND_MF")
    #expect(instrument.purchaseAllowed)
    #expect(instrument.redemptionAllowed)
    #expect(instrument.minimumPurchaseAmount == 5000)
    #expect(instrument.purchaseAmountMultiplier == 1)
    #expect(instrument.minimumAdditionalPurchaseAmount == 100)
    #expect(instrument.minimumRedemptionQuantity == 1)
    #expect(instrument.redemptionQuantityMultiplier == Decimal(string: "0.001"))
    #expect(instrument.dividendType == .growth)
    #expect(instrument.schemeType == .equity)
    #expect(instrument.plan == .direct)
    #expect(instrument.settlementType == "T3")
    #expect(instrument.lastPrice == Decimal(string: "20.09"))
    #expect(try instrument.lastPriceDate == KiteDateOnly("2016-11-11"))
    let request = try #require(await transport.requests.first)
    #expect(request.url.absoluteString == "https://sandbox.kite.trade/oms/mf/instruments")
    #expect(request.method == .get)
    #expect(request.headers["Authorization"] == "token key:token")
    #expect(request.headers["X-Kite-Version"] == "3")
    #expect(await transport.requests.count == 1)
}

@Test func mfOrderRejectsEmptyExchangeDateRatherThanHidingMalformedData() async throws {
    let body = mfOrderJSON.replacingOccurrences(
        of: "\"exchange_timestamp\": null", with: "\"exchange_timestamp\": \"\"",
    )
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: ControlledHTTP(body))
    await #expect(throws: KiteError.self) { try await client.mutualFundOrder(orderID: "123") }
}

private func mfRead(_ operation: Int, _ client: KiteClient) async throws {
    switch operation {
    case 0: _ = try await client.mutualFundOrders()
    case 1: _ = try await client.mutualFundOrder(orderID: "external")
    case 2: _ = try await client.mutualFundSIPs()
    case 3: _ = try await client.mutualFundHoldings()
    default: _ = try await client.mutualFundInstruments()
    }
}

private let mfBodies = [mfOrdersJSON, mfOrderJSON, mfSIPsJSON, mfHoldingsJSON, mfCSV]

@Test(arguments: 0 ..< 5) func mfReadsPreserveAPIErrorsAndNeverRetry(_ operation: Int) async throws {
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FutureLimit","message":"Wait"}"#, status: 429,
    )
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    do {
        try await mfRead(operation, client)
        Issue.record("Expected API error")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == 429)
        #expect(error.errorType == "FutureLimit")
        #expect(error.message == "Wait")
    }
    #expect(await transport.requests.count == 1)
    let failing = FailingHTTP()
    let failedClient = try KiteClient(apiKey: "key", accessToken: "token", transport: failing)
    do {
        try await mfRead(operation, failedClient)
        Issue.record("Expected transport error")
    } catch KiteError.transport {}
    #expect(await failing.attempts == 1)
}

@Test(arguments: 0 ..< 5) func mfReadsRequireSessionAndPreserveCancellation(_ operation: Int)
    async throws
{
    let transport = ControlledHTTP(mfBodies[operation])
    let client = try KiteClient(apiKey: "key", transport: transport)
    await #expect(throws: KiteError.self) { try await mfRead(operation, client) }
    #expect(await transport.requests.isEmpty)
    let cancelled = try KiteClient(apiKey: "key", accessToken: "token", transport: CancelledHTTP())
    await #expect(throws: CancellationError.self) { try await mfRead(operation, cancelled) }
}

@Test(arguments: 0 ..< 5) func mfReadsUseReplacedIsolatedSessionsAndTimeout(_ operation: Int)
    async throws
{
    let transport = ControlledHTTP(mfBodies[operation])
    let config = try KiteConfiguration(timeout: 7)
    let first = try KiteClient(
        apiKey: "a", accessToken: "old", configuration: config, transport: transport,
    )
    let second = try KiteClient(apiKey: "b", accessToken: "other", transport: transport)
    try await first.replaceAccessToken("new")
    try await mfRead(operation, first)
    try await mfRead(operation, second)
    let requests = await transport.requests
    #expect(requests.map { $0.headers["Authorization"] } == ["token a:new", "token b:other"])
    #expect(requests.first?.timeout == 7)
}

@Test func mfOrderPreservesUnknownEnumsPreciseFinancialValuesAndConfiguredInstants() async throws {
    var body = mfOrderJSON.replacingOccurrences(of: "\"OPEN\"", with: "\"FUTURE_STATUS\"")
        .replacingOccurrences(of: "\"BUY\"", with: "\"TRANSFER\"")
        .replacingOccurrences(of: "\"regular\"", with: "\"future_variety\"")
        .replacingOccurrences(of: "\"FRESH\"", with: "\"future_purchase\"")
        .replacingOccurrences(of: "\"amount\": 5000.0", with: "\"amount\": 5000.1234567890123456789")
        .replacingOccurrences(
            of: "\"quantity\": 0", with: "\"future\": true, \"quantity\": 0.1234567890123456789",
        )
    let config = try KiteConfiguration(tradingTimeZone: TimeZone(secondsFromGMT: 0)!)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: config, transport: ControlledHTTP(body),
    )
    let order = try await client.mutualFundOrder(orderID: "123")
    #expect(order.status == .unknown("FUTURE_STATUS"))
    #expect(order.transactionType == .unknown("TRANSFER"))
    #expect(order.variety == .unknown("future_variety"))
    #expect(order.purchaseType == .unknown("future_purchase"))
    #expect(order.amount == Decimal(string: "5000.1234567890123456789"))
    #expect(order.quantity == Decimal(string: "0.1234567890123456789"))
    #expect(order.orderTimestamp == Date(timeIntervalSince1970: 1_624_969_228))
    body = body.replacingOccurrences(of: "2021-06-29 12:20:28", with: "2021-06-29T12:20:28+05:30")
    let explicit = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: config, transport: ControlledHTTP(body),
    )
    #expect(
        try await explicit.mutualFundOrder(orderID: "123").orderTimestamp
            == Date(timeIntervalSince1970: 1_624_949_428),
    )
}

@Test func mfSIPsPreserveUnknownValuesAndOptionalUntriggeredInstalment() async throws {
    let body = mfSIPsJSON.replacingOccurrences(of: "\"ACTIVE\"", with: "\"FUTURE\"")
        .replacingOccurrences(of: "\"idcw\"", with: "\"new_dividend\"")
        .replacingOccurrences(of: "\"weekly\"", with: "\"daily\"")
        .replacingOccurrences(of: "\"sip\"", with: "\"new_sip\"")
        .replacingOccurrences(
            of: "\"last_instalment\": \"2021-05-05 05:56:27\"", with: "\"last_instalment\": null",
        )
        .replacingOccurrences(
            of: "\"instalment_amount\": 500.0", with: "\"instalment_amount\": 500.01234567890123456789",
        )
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: ControlledHTTP(body))
    let sip = try #require(try await client.mutualFundSIPs().first)
    #expect(sip.status == .unknown("FUTURE"))
    #expect(sip.dividendType == .unknown("new_dividend"))
    #expect(sip.frequency == .unknown("daily"))
    #expect(sip.sipType == .unknown("new_sip"))
    #expect(sip.lastInstalment == nil)
    #expect(sip.instalmentAmount == Decimal(string: "500.01234567890123456789"))
}

@Test func mfJSONRejectsMalformedRequiredFieldsAndBadEnvelope() async throws {
    for (operation, original, replacements) in [
        (
            1, mfOrderJSON,
            [
                ("\"order_id\"", "\"missing\""), ("\"amount\": 5000.0", "\"amount\": null"),
                ("2021-06-29 12:20:28", "2021-02-30 12:20:28"),
                ("\"last_price_date\": \"2021-06-29\"", "\"last_price_date\": \"2021-02-29\""),
            ],
        ),
        (
            2, mfSIPsJSON,
            [
                ("\"sip_id\"", "\"missing\""), ("\"instalments\": -1", "\"instalments\": 1.5"),
                ("2021-05-12", "2021-13-01"),
                ("\"instalment_amount\": 500.0", "\"instalment_amount\": \"bad\""),
            ],
        ),
        (
            3, mfHoldingsJSON,
            [
                ("\"quantity\"", "\"missing\""),
                ("\"last_price_date\": \"\"", "\"last_price_date\": \"invalid\""),
            ],
        ),
    ] {
        for (old, new) in replacements {
            let client = try KiteClient(
                apiKey: "key", accessToken: "token",
                transport: ControlledHTTP(original.replacingOccurrences(of: old, with: new)),
            )
            do {
                try await mfRead(operation, client)
                Issue.record("Expected decoding failure for \(old)")
            } catch KiteError.decoding {}
        }
    }
    for operation in 0 ..< 4 {
        for body in [
            #"{"status":"unexpected","data":[]}"#, #"{"status":"success"}"#,
            #"{"status":"success","data":null}"#,
        ] {
            let client = try KiteClient(
                apiKey: "key", accessToken: "token", transport: ControlledHTTP(body),
            )
            do {
                try await mfRead(operation, client)
                Issue.record("Expected malformed envelope failure")
            } catch KiteError.decoding {}
        }
    }
}

@Test func mfCSVSupportsBOMReorderedColumnsEscapedMultilineAndUnknownEnums() async throws {
    let lines = mfCSV.split(separator: "\n").map(String.init)
    let header = lines[0].split(separator: ",").map(String.init)
    var row = lines[1].split(separator: ",").map(String.init)
    row[2] = "\"Fund, \"\"Quoted\"\"\r\nGrowth\""
    row[3] = "0"
    row[10] = "future_dividend"
    row[11] = "future_scheme"
    row[12] = "future_plan"
    row[13] = "T_NEW"
    row[14] = "20.1234567890123456789"
    let csv =
        "\u{FEFF}future," + header.reversed().joined(separator: ",") + "\r\nignored,"
            + row.reversed().joined(separator: ",") + "\r\n\r\n"
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: ControlledHTTP(csv))
    let instrument = try #require(try await client.mutualFundInstruments().first)
    #expect(instrument.name == "Fund, \"Quoted\"\r\nGrowth")
    #expect(!instrument.purchaseAllowed)
    #expect(instrument.dividendType == .unknown("future_dividend"))
    #expect(instrument.schemeType == .unknown("future_scheme"))
    #expect(instrument.plan == .unknown("future_plan"))
    #expect(instrument.settlementType == "T_NEW")
    #expect(instrument.lastPrice == Decimal(string: "20.1234567890123456789"))
}

@Test func mfCSVRejectsMalformedRequiredData() async throws {
    let lines = mfCSV.split(separator: "\n").map(String.init)
    let header = lines[0]
    let valid = lines[1].split(separator: ",").map(String.init)
    var invalid = [
        "", "name\nFund", header + ",name\n" + lines[1] + ",Fund", header + "\n" + lines[1] + ",extra",
        header + "\nshort,row",
    ]
    for (index, value) in [
        (0, ""), (3, "true"), (4, "2"), (5, "1oops"), (6, "NaN"), (7, "1e999"),
        (8, "0.00000000000000000000000000000000000000123456789012345678901234567890123456789"),
        (14, "123456789012345678901234567890123456789"), (15, "2026-02-29"), (2, "\"unterminated"),
        (2, "bad\"quote"), (2, "\"closed\"junk"),
    ] {
        var row = valid
        row[index] = value
        invalid.append(header + "\n" + row.joined(separator: ","))
    }
    for body in invalid {
        let client = try KiteClient(
            apiKey: "key", accessToken: "token", transport: ControlledHTTP(body),
        )
        do {
            _ = try await client.mutualFundInstruments()
            Issue.record("Expected invalid CSV failure: \(body)")
        } catch KiteError.decoding {}
    }
    let empty = try KiteClient(apiKey: "key", accessToken: "token", transport: ControlledHTTP(header))
    #expect(try await empty.mutualFundInstruments().isEmpty)
}

@Test func mfNullableOrderFieldsAndDatedHoldingsRemainTyped() async throws {
    let body = mfOrderJSON.replacingOccurrences(of: "\"status\": \"OPEN\"", with: "\"status\": null")
        .replacingOccurrences(of: "\"purchase_type\": \"FRESH\"", with: "\"purchase_type\": null")
        .replacingOccurrences(
            of: "\"quantity\": 0", with: "\"price\": 12.1234567890123456789, \"quantity\": 0",
        )
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: ControlledHTTP(body))
    let order = try await client.mutualFundOrder(orderID: "external")
    #expect(order.status == nil)
    #expect(order.purchaseType == nil)
    #expect(order.price == Decimal(string: "12.1234567890123456789"))
    let holdingBody = mfHoldingsJSON.replacingOccurrences(
        of: "\"last_price_date\": \"\"", with: "\"last_price_date\": \"2024-02-29\"",
    )
    .replacingOccurrences(of: "\"folio\": \"3108290884\"", with: "\"folio\": null")
    .replacingOccurrences(of: "\"pledged_quantity\": 0", with: "\"pledged_quantity\": 0.00123")
    let holder = try KiteClient(
        apiKey: "key", accessToken: "token", transport: ControlledHTTP(holdingBody),
    )
    let holding = try #require(try await holder.mutualFundHoldings().first)
    #expect(try holding.lastPriceDate == KiteDateOnly("2024-02-29"))
    #expect(holding.folio == nil)
    #expect(holding.pledgedQuantity == Decimal(string: "0.00123"))
}
