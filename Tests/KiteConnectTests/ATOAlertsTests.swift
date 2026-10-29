//
//  ATOAlertsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

/// Literal official alerts documentation examples (2026-10-27 snapshot), not SDK output.
@Test func atoReadsDocumentedSparseBasketThroughSharedLifecycle() async throws {
    let transport = ControlledHTTP(documentedAlertList)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let alerts = try await client.alerts()
    #expect(alerts[0].basket == nil)
    let alert = try #require(alerts.last)
    #expect(alert.type == .ato && alert.status == .disabled)
    let basket = try #require(alert.basket)
    #expect(basket.name == nil && basket.type == nil && basket.tags == nil)
    let item = try #require(basket.items.first)
    #expect(item.id == 275_218_517 && item.instrumentToken == 3_693_569)
    #expect(item.type == nil && item.tradingSymbol == "GOLDBEES" && item.exchange == .nse)
    #expect(item.weight == 10000)
    #expect(item.params.price == Decimal(string: "72.22"))
    #expect(item.params.quantity == 10000 && item.params.validityTTL == 0)
    #expect(item.params.transactionType == .buy && item.params.orderType == .limit)
    #expect(item.params.product == .cnc && item.params.variety == .regular)
    #expect(item.params.validity == .day && item.params.disclosedQuantity == 0)
    #expect(item.params.triggerPrice == 0 && item.params.squareoff == 0)
    #expect(item.params.stoploss == 0 && item.params.trailingStoploss == 0)
    #expect(item.params.gtt?.target == 0 && item.params.gtt?.stoploss == 0)
    #expect(item.params.lastPrice == nil && item.params.icebergLegs == nil)
    #expect(item.params.marketProtection == nil && item.params.tags == [])
    #expect(alert.createdAt == Date(timeIntervalSince1970: 1_739_760_850))
    #expect(await transport.requests.first?.url.path == "/oms/alerts")
}

@Test func atoCreateSendsTheDocumentedBasketJSONInsideAlertForm() async throws {
    let transport = try ControlledHTTP(atoResponse())
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let receipt = try await client.createAlert(atoRequest())
    #expect(receipt.type == .ato && receipt.basket == nil)
    let sent = try #require(await transport.requests.first)
    #expect(
        sent.method == .post && sent.url.absoluteString == "https://sandbox.kite.trade/oms/alerts",
    )
    #expect(sent.headers["Content-Type"] == "application/x-www-form-urlencoded")
    #expect(
        sent.headers["Authorization"] == "token key:token" && sent.headers["X-Kite-Version"] == "3",
    )
    let fields = try formFields(sent.body)
    #expect(fields.count == 9)
    #expect(fields["type"] == "ato" && fields["name"] == "NIFTY 50")
    #expect(fields["lhs_exchange"] == "INDICES" && fields["lhs_tradingsymbol"] == "NIFTY 50")
    #expect(fields["lhs_attribute"] == "LastTradedPrice" && fields["operator"] == ">=")
    #expect(fields["rhs_type"] == "constant" && fields["rhs_constant"] == "27000")
    let basketData = try #require(fields["basket"])
    let actual =
        try JSONSerialization.jsonObject(with: Data(basketData.utf8))
            as! NSDictionary
    let expected =
        try JSONSerialization.jsonObject(with: Data(documentedBasket.utf8)) as! NSDictionary
    #expect(actual == expected)
}

@Test func atoFetchModifyRetainsSparseBasketAndDecimalValues() async throws {
    let transport = try ControlledHTTP(atoResponse(basket: true))
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let current = try await client.alert(uuid: atoID)
    var definition = atoRequest()
    definition.basket = try #require(current.basket)
    definition.name = "buy gold +&"
    definition.condition.rhs = .instrument(
        KiteAlertInstrument(exchange: .nse, tradingSymbol: "A+B", attribute: "LastTradedPrice"),
    )
    definition.basket.items[0].params.price = Decimal(string: "72.220000001")!
    definition.basket.items[0].params.marketProtection = Decimal(string: "0.123456789")!
    definition.basket.items[0].weight = Decimal(string: "9999.123456789")!
    definition.basket.items[0].params.gtt = .init(
        target: Decimal(string: "100.000000001")!, stoploss: Decimal(string: "70.000000001")!,
    )
    let modified = try await client.modifyAlert(uuid: atoID, alert: definition)
    #expect(modified.uuid == current.uuid)
    let sent = await transport.requests
    #expect(sent.count == 2 && sent[1].method == .put)
    #expect(sent[0].url.path == "/oms/alerts/\(atoID)" && sent[1].url.path == sent[0].url.path)
    let fields = try formFields(sent[1].body)
    #expect(fields["name"] == "buy gold +&" && fields["type"] == "ato")
    #expect(fields["rhs_constant"] == nil && fields["rhs_type"] == "instrument")
    #expect(fields["rhs_exchange"] == "NSE" && fields["rhs_tradingsymbol"] == "A+B")
    let encoded = try #require(fields["basket"])
    #expect(encoded.contains("72.220000001") && encoded.contains("0.123456789"))
    #expect(
        encoded.contains("9999.123456789") && encoded.contains("100.000000001")
            && encoded.contains("70.000000001"),
    )
    let basket = try JSONDecoder().decode(KiteAlertBasket.self, from: Data(encoded.utf8))
    #expect(basket == definition.basket)
    #expect(basket.items[0].params.validityTTL == 0)
    #expect(basket.items[0].type == nil && basket.name == nil)
}

@Test func atoRejectsInvalidMutableBasketStructureBeforeSending() async throws {
    let transport = try ControlledHTTP(atoResponse())
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let faults: [(inout KiteATOAlertRequest) -> Void] = [
        { $0.basket.items = [] }, { $0.basket.name = " " }, { $0.basket.type = "\n" },
        { $0.basket.tags = ["\n"] }, { $0.basket.items[0].type = "" },
        { $0.basket.items[0].tradingSymbol = " " }, { $0.basket.items[0].exchange = .unknown("") },
        { $0.basket.items[0].weight = .nan }, { $0.basket.items[0].params.quantity = 0 },
        { $0.basket.items[0].params.price = -1 }, { $0.basket.items[0].params.triggerPrice = .nan },
        { $0.basket.items[0].params.validityTTL = -1 },
        { $0.basket.items[0].params.disclosedQuantity = -1 },
        { $0.basket.items[0].params.lastPrice = .nan }, { $0.basket.items[0].params.squareoff = -1 },
        { $0.basket.items[0].params.stoploss = .nan },
        { $0.basket.items[0].params.trailingStoploss = -1 },
        { $0.basket.items[0].params.icebergLegs = -1 },
        { $0.basket.items[0].params.marketProtection = .nan },
        { $0.basket.items[0].params.gtt = .init(target: .nan, stoploss: 0) },
        { $0.basket.items[0].params.gtt = .init(target: 0, stoploss: -1) },
        { $0.basket.items[0].params.product = .unknown("") },
        { $0.basket.items[0].params.orderType = .unknown("") },
        { $0.basket.items[0].params.transactionType = .unknown("") },
        { $0.basket.items[0].params.validity = .unknown("") },
        { $0.basket.items[0].params.variety = .unknown("") },
        { $0.basket.items[0].params.tags = ["\n"] },
        { $0.name = " " }, { $0.condition.rhs = .constant(.nan) },
    ]
    for fault in faults {
        var request = atoRequest()
        fault(&request)
        do {
            _ = try await client.createAlert(request)
            Issue.record("Expected ATO validation")
        } catch KiteError.validation {}
        do {
            _ = try await client.modifyAlert(uuid: atoID, alert: request)
            Issue.record("Expected ATO validation")
        } catch KiteError.validation {}
    }
    do {
        _ = try await client.modifyAlert(uuid: "../alerts", alert: atoRequest())
        Issue.record("Expected identifier validation")
    } catch KiteError.validation {}
    #expect(await transport.requests.isEmpty)
}

@Test func atoHistoryTypesDocumentedAbsenceAndRetainsUndocumentedMetadata() async throws {
    let transport = ControlledHTTP(documentedHistory)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let history = try await client.alertHistory(uuid: atoID)
    #expect(history[0].type == .simple)
    #expect(history[0].orderMetadata == .notReported)
    #expect(history[0].meta[0].lastPrice == Decimal(string: "58288.05"))
    #expect(history[0].meta[0].timestamp == history[0].createdAt)
    for value in [
        #"{"future_status":"queued","amount":72.220000001}"#, "[]", #""pending""#, "false",
        "0.123456789",
    ] {
        // Compatibility probes, not purported official ATO history examples.
        let fixture = documentedHistory.replacingOccurrences(
            of: #""type": "simple""#, with: #""type": "ato""#,
        )
        .replacingOccurrences(of: #""order_meta": null"#, with: #""order_meta":\#(value)"#)
        let probe = ControlledHTTP(fixture)
        let probeClient = try KiteClient(
            apiKey: "key", accessToken: "token", configuration: .sandbox, transport: probe,
        )
        let result = try await probeClient.alertHistory(uuid: atoID)
        let raw = try #require(result[0].orderMeta)
        #expect(result[0].type == .ato)
        #expect(result[0].orderMetadata == .undocumented(raw))
        if value.hasPrefix("{") {
            #expect(
                raw
                    == .object([
                        "future_status": .string("queued"), "amount": .number(Decimal(string: "72.220000001")!),
                    ]),
            )
        }
    }
}

@Test(
    arguments: ["create", "modify"], ["timeout", "gateway", "malformed", "rejected", "rateLimit"],
)
func atoMutationsRetainSingleAttemptAndUncertainOutcomeContract(operation: String, failure: String)
    async throws
{
    if failure == "timeout" {
        let transport = FailingHTTP()
        let client = try KiteClient(
            apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
        )
        do {
            try await performATO(operation, client: client)
            Issue.record("Expected uncertainty")
        } catch let KiteError.uncertainOutcome(.transport(code, _)) {
            #expect(code == URLError.timedOut.rawValue)
        }
        #expect(await transport.attempts == 1)
        return
    }
    let isRejection = failure == "rejected" || failure == "rateLimit"
    let status =
        failure == "gateway"
            ? 502 : (failure == "rejected" ? 400 : (failure == "rateLimit" ? 429 : 200))
    let body =
        isRejection
            ? #"{"status":"error","error_type":"FutureATOException","message":"Rejected"}"#
            : (failure == "gateway" ? "Bad Gateway" : #"{"status":"success","data":{}}"#)
    let transport = ControlledHTTP(body, status: status)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        try await performATO(operation, client: client)
        Issue.record("Expected failure")
    } catch let KiteError.api(error) {
        #expect(isRejection && error.statusCode == status && error.errorType == "FutureATOException")
    } catch let KiteError.uncertainOutcome(cause) {
        switch cause {
        case let .api(error): #expect(failure == "gateway" && error.statusCode == 502)
        case let .decoding(code, _): #expect(failure == "malformed" && code == 200)
        default: Issue.record("Unexpected uncertainty cause")
        }
    }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: ["create", "modify"])
func atoCancellationRemainsRecognizable(operation: String) async throws {
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: CancelledHTTP(),
    )
    await #expect(throws: CancellationError.self) { try await performATO(operation, client: client) }
    let transport = SuspendedHTTP()
    let suspended = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let task = Task { try await performATO(operation, client: suspended) }
    for await _ in transport.started {
        break
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func atoReadUnknownValuesAndExtraFieldsRemainCompatible() async throws {
    let future = try atoResponse(basket: true)
        .replacingOccurrences(of: #""disabled""#, with: #""future-status""#)
        .replacingOccurrences(of: "CNC", with: "FUTURE_PRODUCT")
        .replacingOccurrences(of: "LIMIT", with: "FUTURE_ORDER")
        .replacingOccurrences(of: "BUY", with: "FUTURE_SIDE")
        .replacingOccurrences(of: "DAY", with: "FUTURE_VALIDITY")
        .replacingOccurrences(of: "regular", with: "future-variety")
        .replacingOccurrences(of: #""params":{"#, with: #""params":{"future_parameter":true,"#)
    let transport = ControlledHTTP(future)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let alert = try await client.alert(uuid: atoID)
    #expect(alert.status == .unknown("future-status"))
    let params = try #require(alert.basket?.items.first?.params)
    #expect(
        params.product == .unknown("FUTURE_PRODUCT") && params.orderType == .unknown("FUTURE_ORDER"),
    )
    #expect(
        params.transactionType == .unknown("FUTURE_SIDE")
            && params.validity == .unknown("FUTURE_VALIDITY"),
    )
    #expect(params.variety == .unknown("future-variety"))
}

@Test(arguments: ["quantity", "params", "price", "items", "gtt", "basket"])
func atoMalformedRequiredBasketDataFailsClearly(fault: String) async throws {
    let response = try atoResponse(basket: true)
    var object = try JSONSerialization.jsonObject(with: Data(response.utf8)) as! [String: Any]
    var alert = object["data"] as! [String: Any]
    var basket = alert["basket"] as! [String: Any]
    var items = basket["items"] as! [[String: Any]]
    var params = items[0]["params"] as! [String: Any]
    switch fault {
    case "quantity": params.removeValue(forKey: "quantity")
    case "price": params["price"] = "not a price"
    case "gtt": params["gtt"] = ["target": 0] // present nested data must be complete
    default: break
    }
    items[0]["params"] = fault == "params" ? NSNull() : params
    basket["items"] = fault == "items" ? "not an array" : items
    alert["basket"] = fault == "basket" ? "not an object" : basket
    object["data"] = alert
    let fixture = try String(decoding: JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    let transport = ControlledHTTP(fixture)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        _ = try await client.alert(uuid: atoID)
        Issue.record("Expected malformed basket rejection")
    } catch let KiteError.decoding(code, _) { #expect(code == 200) }
}

@Test func atoSessionsTimeoutAndSharedDeletionAreRespected() async throws {
    let transport = try ControlledHTTP(atoResponse())
    let config = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 14,
        tradingTimeZone: TimeZone(secondsFromGMT: 0)!,
    )
    let first = try KiteClient(
        apiKey: "one", accessToken: "old", configuration: config, transport: transport,
    )
    let second = try KiteClient(
        apiKey: "two", accessToken: "other", configuration: .sandbox, transport: transport,
    )
    let utc = try await first.createAlert(atoRequest())
    try await first.replaceAccessToken("new")
    _ = try await first.modifyAlert(uuid: atoID, alert: atoRequest())
    let ist = try await second.createAlert(atoRequest())
    #expect(utc.createdAt.timeIntervalSince(ist.createdAt) == 19800)
    let sent = await transport.requests
    #expect(
        sent.map { $0.headers["Authorization"] } == [
            "token one:old", "token one:new", "token two:other",
        ],
    )
    #expect(sent[0].timeout == 14)
    try await first.replaceAccessToken(nil)
    do {
        _ = try await first.createAlert(atoRequest())
        Issue.record("Expected missing credentials")
    } catch let KiteError.validation(field, _) { #expect(field == "accessToken") }
    #expect(await transport.requests.count == 3)
    let deletion = ControlledHTTP(#"{"status":"success","data":null}"#)
    let deleter = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: deletion,
    )
    try await deleter.deleteAlert(uuid: atoID)
    #expect(await deletion.requests.first?.method == .delete)
    #expect(
        await deletion.requests.first?.url.absoluteString
            == "https://sandbox.kite.trade/oms/alerts?uuid=\(atoID)",
    )
}
