//
//  AlertsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

private let alertJSON = #"""
{"type":"simple","user_id":"AB1234","uuid":"550e8400-e29b-41d4-a716-446655440000",
"name":"NIFTY 50","status":"enabled","disabled_reason":"","lhs_attribute":"LastTradedPrice",
"lhs_exchange":"INDICES","lhs_tradingsymbol":"NIFTY 50","operator":">=","rhs_type":"constant",
"rhs_attribute":"","rhs_exchange":"","rhs_tradingsymbol":"","rhs_constant":27000.123456789,
"alert_count":0,"created_at":"2025-05-26 12:07:50","updated_at":"2025-05-26T12:07:50+05:30","future":true}
"""#
private let alertID = "550e8400-e29b-41d4-a716-446655440000"

@Test func alertsRetrieveCompleteSimpleModelWithSharedTimestampPolicy() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":\#(alertJSON)}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let alert = try await client.alert(uuid: alertID)
    #expect(alert.uuid == alertID)
    #expect(alert.type == .simple)
    #expect(alert.userID == "AB1234")
    #expect(alert.name == "NIFTY 50")
    #expect(alert.status == .enabled)
    #expect(alert.disabledReason == "")
    #expect(alert.lhsExchange == .unknown("INDICES"))
    #expect(alert.lhsTradingSymbol == "NIFTY 50")
    #expect(alert.lhsAttribute == "LastTradedPrice")
    #expect(alert.comparison == .greaterThanOrEqual)
    #expect(alert.rhsType == .constant)
    #expect(
        alert.rhsAttribute == "" && alert.rhsTradingSymbol == "" && alert.rhsExchange.rawValue == "",
    )
    #expect(alert.rhsConstant == Decimal(string: "27000.123456789"))
    #expect(alert.alertCount == 0)
    #expect(alert.createdAt == Date(timeIntervalSince1970: 1_748_241_470))
    #expect(alert.updatedAt == alert.createdAt)
    let sent = try #require(await transport.requests.first)
    #expect(sent.method == .get)
    #expect(sent.url.absoluteString == "https://sandbox.kite.trade/oms/alerts/\(alertID)")
    #expect(sent.headers["Authorization"] == "token key:token")
    #expect(sent.headers["X-Kite-Version"] == "3")
}

@Test func alertsListFiltersAndPreservesUnknownServerValues() async throws {
    let future = alertJSON.replacingOccurrences(of: "\"enabled\"", with: "\"paused\"")
        .replacingOccurrences(of: "\"simple\"", with: "\"future\"")
        .replacingOccurrences(of: "\">=\"", with: "\"!=\"")
        .replacingOccurrences(of: "\"constant\"", with: "\"expression\"")
    let transport = ControlledHTTP(#"{"status":"success","data":[\#(future)]}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    for status: KiteAlertStatus in [.enabled, .disabled, .deleted] {
        let alerts = try await client.alerts(status: status, page: 2, pageSize: 25)
        let alert = try #require(alerts.first)
        #expect(alert.status == .unknown("paused"))
        #expect(alert.type.rawValue == "future")
        #expect(alert.comparison == .unknown("!="))
        #expect(alert.rhsType.rawValue == "expression")
    }
    _ = try await client.alerts()
    let sent = await transport.requests
    #expect(
        sent.map(\.url.absoluteString) == [
            "https://sandbox.kite.trade/oms/alerts?status=enabled&page=2&page_size=25",
            "https://sandbox.kite.trade/oms/alerts?status=disabled&page=2&page_size=25",
            "https://sandbox.kite.trade/oms/alerts?status=deleted&page=2&page_size=25",
            "https://sandbox.kite.trade/oms/alerts",
        ],
    )
    #expect(sent.allSatisfy { $0.method == .get && $0.body == nil })
}

private func simpleAlertRequest() -> KiteSimpleAlertRequest {
    KiteSimpleAlertRequest(
        name: "NIFTY +&",
        condition: KiteAlertCondition(
            lhs: KiteAlertInstrument(
                exchange: .unknown("INDICES"), tradingSymbol: "NIFTY 50", attribute: "LastTradedPrice",
            ),
            comparison: .greaterThanOrEqual, rhs: .constant(Decimal(string: "27000.123456789")!),
        ),
    )
}

@Test func alertsCreateAndModifyEncodeConstantAndInstrumentConditions() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":\#(alertJSON)}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let created = try await client.createAlert(simpleAlertRequest())
    #expect(created.uuid == alertID)
    for comparison in [
        KiteAlertOperator.lessThanOrEqual, .greaterThanOrEqual, .lessThan, .greaterThan, .equal,
    ] {
        var change = simpleAlertRequest()
        change.condition.comparison = comparison
        change.condition.rhs = .instrument(
            KiteAlertInstrument(exchange: .nse, tradingSymbol: "A+B", attribute: "LastTradedPrice"),
        )
        let modified = try await client.modifyAlert(uuid: alertID, alert: change)
        #expect(modified.status == .enabled)
    }
    let sent = await transport.requests
    #expect(sent[0].method == .post)
    #expect(sent[0].url.path == "/oms/alerts")
    #expect(sent[0].headers["Content-Type"] == "application/x-www-form-urlencoded")
    #expect(
        String(decoding: sent[0].body!, as: UTF8.self)
            == "name=NIFTY%20%2B%26&type=simple&lhs_exchange=INDICES&lhs_tradingsymbol=NIFTY%2050&lhs_attribute=LastTradedPrice&operator=%3E%3D&rhs_type=constant&rhs_constant=27000.123456789",
    )
    for (index, encoded) in ["%3C%3D", "%3E%3D", "%3C", "%3E", "%3D%3D"].enumerated() {
        #expect(sent[index + 1].method == .put)
        #expect(sent[index + 1].url.path == "/oms/alerts/\(alertID)")
        #expect(
            String(decoding: sent[index + 1].body!, as: UTF8.self)
                == "name=NIFTY%20%2B%26&type=simple&lhs_exchange=INDICES&lhs_tradingsymbol=NIFTY%2050&lhs_attribute=LastTradedPrice&operator=\(encoded)&rhs_type=instrument&rhs_exchange=NSE&rhs_tradingsymbol=A%2BB&rhs_attribute=LastTradedPrice",
        )
    }
}

@Test func alertsDeleteSingleAndBulkUseRepeatedQueryAndNullReceipt() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":null}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    try await client.deleteAlert(uuid: alertID)
    try await client.deleteAlerts(uuids: [alertID, "a5a2b03d-4851-44b3-9d85-0123baa4a273"])
    let sent = await transport.requests
    #expect(sent.count == 2)
    #expect(
        sent.allSatisfy { $0.method == .delete && $0.body == nil && $0.url.path == "/oms/alerts" },
    )
    #expect(sent[0].url.query == "uuid=\(alertID)")
    #expect(sent[1].url.query == "uuid=\(alertID)&uuid=a5a2b03d-4851-44b3-9d85-0123baa4a273")
}

private let alertHistoryJSON = #"""
[{"uuid":"550e8400-e29b-41d4-a716-446655440000","type":"simple","meta":[{
"instrument_token":270857,"tradingsymbol":"NIFTY NEXT 50","timestamp":"2025-02-17 09:16:46",
"last_price":58288.05,"ohlc":{"open":59221.95,"high":59241.8,"low":58283.7,"close":59557.95},
"net_change":-1269.9,"exchange":"INDICES","last_trade_time":"0001-01-01 00:00:00",
"last_quantity":0,"buy_quantity":0,"sell_quantity":0,"volume":0,"volume_tick":0,"average_price":0,
"oi":0,"oi_day_high":0,"oi_day_low":0,"lower_circuit_limit":0,"upper_circuit_limit":0}],
"condition":"LastTradedPrice(\"INDICES:NIFTY NEXT 50\") <= 58290.35",
"created_at":"2025-02-17 09:16:46","order_meta":null}]
"""#

@Test func alertsHistoryDecodesDocumentedMarketDataIncludingYearOneSentinel() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":\#(alertHistoryJSON)}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let entries = try await client.alertHistory(uuid: alertID)
    let entry = try #require(entries.first)
    #expect(entry.uuid == alertID && entry.type == .simple)
    #expect(entry.condition == "LastTradedPrice(\"INDICES:NIFTY NEXT 50\") <= 58290.35")
    #expect(entry.orderMeta == nil)
    let tick = try #require(entry.meta.first)
    #expect(tick.instrumentToken == 270_857)
    #expect(tick.tradingSymbol == "NIFTY NEXT 50")
    #expect(tick.exchange.rawValue == "INDICES")
    #expect(tick.timestamp == entry.createdAt)
    #expect(tick.lastTradeTime < Date(timeIntervalSince1970: -60_000_000_000))
    #expect(tick.lastPrice == Decimal(string: "58288.05"))
    #expect(tick.ohlc.open == Decimal(string: "59221.95"))
    #expect(tick.ohlc.high == Decimal(string: "59241.8"))
    #expect(tick.ohlc.low == Decimal(string: "58283.7"))
    #expect(tick.ohlc.close == Decimal(string: "59557.95"))
    #expect(tick.netChange == Decimal(string: "-1269.9"))
    #expect(tick.lastQuantity == 0 && tick.buyQuantity == 0 && tick.sellQuantity == 0)
    #expect(tick.volume == 0 && tick.volumeTick == 0 && tick.averagePrice == 0)
    #expect(tick.oi == 0 && tick.oiDayHigh == 0 && tick.oiDayLow == 0)
    #expect(tick.lowerCircuitLimit == 0 && tick.upperCircuitLimit == 0)
    #expect(await transport.requests.first?.url.path == "/oms/alerts/\(alertID)/history")
}

@Test func alertsValidateStructureBeforeTransport() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":\#(alertJSON)}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var bad: [KiteSimpleAlertRequest] = []
    var request = simpleAlertRequest()
    request.name = " "
    bad.append(request)
    request = simpleAlertRequest()
    request.condition.lhs.attribute = ""
    bad.append(request)
    request = simpleAlertRequest()
    request.condition.lhs.exchange = .unknown("")
    bad.append(request)
    request = simpleAlertRequest()
    request.condition.lhs.tradingSymbol = "\n"
    bad.append(request)
    request = simpleAlertRequest()
    request.condition.rhs = .constant(.nan)
    bad.append(request)
    request = simpleAlertRequest()
    request.condition.rhs = .instrument(
        KiteAlertInstrument(exchange: .nse, tradingSymbol: "", attribute: "LastTradedPrice"),
    )
    bad.append(request)
    request = simpleAlertRequest()
    request.condition.comparison = .unknown("")
    bad.append(request)
    for request in bad {
        do {
            _ = try await client.createAlert(request)
            Issue.record("Expected structural validation")
        } catch KiteError.validation {}
        do {
            _ = try await client.modifyAlert(uuid: alertID, alert: request)
            Issue.record("Expected structural validation")
        } catch KiteError.validation {}
    }
    for uuid in ["", " ", "../alerts", "a/b", "a?x", "a#x", "a%2Fb", "a\nb"] {
        do {
            _ = try await client.alert(uuid: uuid)
            Issue.record("Expected identifier validation")
        } catch KiteError.validation {}
        do {
            _ = try await client.alertHistory(uuid: uuid)
            Issue.record("Expected identifier validation")
        } catch KiteError.validation {}
        do {
            _ = try await client.modifyAlert(uuid: uuid, alert: simpleAlertRequest())
            Issue.record("Expected identifier validation")
        } catch KiteError.validation {}
        do {
            try await client.deleteAlert(uuid: uuid)
            Issue.record("Expected identifier validation")
        } catch KiteError.validation {}
    }
    do {
        try await client.deleteAlerts(uuids: [])
        Issue.record("Expected nonempty list")
    } catch KiteError.validation {}
    for value in [0, -1] {
        do {
            _ = try await client.alerts(page: value)
            Issue.record("Expected positive page")
        } catch KiteError.validation {}
        do {
            _ = try await client.alerts(pageSize: value)
            Issue.record("Expected positive size")
        } catch KiteError.validation {}
    }
    #expect(await transport.requests.isEmpty)
}

@Test(arguments: ["missing", "threshold", "timestamp", "uuid"])
func alertsMalformedRequiredDataFailsClearly(fault: String) async throws {
    let malformed: String = switch fault {
    case "missing":
        alertJSON.replacingOccurrences(of: "\"status\":\"enabled\",", with: "")
    case "threshold":
        alertJSON.replacingOccurrences(of: "27000.123456789", with: "\"invalid\"")
    case "timestamp":
        alertJSON.replacingOccurrences(
            of: "2025-05-26 12:07:50", with: "2025-02-30 12:00:00",
        )
    default: alertJSON.replacingOccurrences(of: alertID, with: "")
    }
    let transport = ControlledHTTP(#"{"status":"success","data":\#(malformed)}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        _ = try await client.alert(uuid: alertID)
        Issue.record("Expected decoding failure")
    } catch let KiteError.decoding(code, _) { #expect(code == 200) }
}

private func performAlertOperation(_ operation: String, client: KiteClient) async throws {
    switch operation {
    case "create": _ = try await client.createAlert(simpleAlertRequest())
    case "modify": _ = try await client.modifyAlert(uuid: alertID, alert: simpleAlertRequest())
    case "delete": try await client.deleteAlert(uuid: alertID)
    case "bulk": try await client.deleteAlerts(uuids: [alertID, "another-id"])
    case "get": _ = try await client.alert(uuid: alertID)
    case "list": _ = try await client.alerts()
    default: _ = try await client.alertHistory(uuid: alertID)
    }
}

@Test(arguments: ["create", "modify", "delete", "bulk"], ["timeout", "gateway", "malformed"])
func alertsMutationsAreSingleAttemptAndUncertain(operation: String, failure: String) async throws {
    if failure == "timeout" {
        let transport = FailingHTTP()
        let client = try KiteClient(
            apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
        )
        do {
            try await performAlertOperation(operation, client: client)
            Issue.record("Expected uncertainty")
        } catch let KiteError.uncertainOutcome(.transport(code, _)) {
            #expect(code == URLError.timedOut.rawValue)
        }
        #expect(await transport.attempts == 1)
    } else {
        let transport = ControlledHTTP(
            failure == "gateway" ? "Bad Gateway" : #"{"status":"success","data":{}}"#,
            status: failure == "gateway" ? 502 : 200,
        )
        let client = try KiteClient(
            apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
        )
        do {
            try await performAlertOperation(operation, client: client)
            Issue.record("Expected uncertainty")
        } catch let KiteError.uncertainOutcome(error) {
            switch error {
            case let .api(error): #expect(failure == "gateway" && error.statusCode == 502)
            case let .decoding(code, _): #expect(failure == "malformed" && code == 200)
            default: Issue.record("Unexpected uncertainty cause")
            }
        }
        #expect(await transport.requests.count == 1)
    }
}

@Test(
    arguments: ["create", "modify", "delete", "bulk", "get", "list", "history"], [400, 401, 429, 503],
)
func alertsConfirmedAPIErrorsPreserveRawTypeAndNeverRetry(operation: String, status: Int)
    async throws
{
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FutureAlertException","message":"Rejected"}"#, status: status,
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        try await performAlertOperation(operation, client: client)
        Issue.record("Expected rejection")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == status)
        #expect(error.errorType == "FutureAlertException")
        #expect(error.message == "Rejected")
    }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: ["create", "modify", "delete", "bulk", "get", "list", "history"])
func alertsCancellationRemainsRecognizable(operation: String) async throws {
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: CancelledHTTP(),
    )
    await #expect(throws: CancellationError.self) {
        try await performAlertOperation(operation, client: client)
    }
    let suspended = SuspendedHTTP()
    let cancellable = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: suspended,
    )
    let task = Task { try await performAlertOperation(operation, client: cancellable) }
    for await _ in suspended.started {
        break
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func alertsSessionsTimeoutAndTradingTimezoneAreRespected() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":\#(alertJSON)}"#)
    let config = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 13,
        tradingTimeZone: TimeZone(secondsFromGMT: 0)!,
    )
    let first = try KiteClient(
        apiKey: "one", accessToken: "old", configuration: config, transport: transport,
    )
    let second = try KiteClient(
        apiKey: "two", accessToken: "other", configuration: .sandbox, transport: transport,
    )
    let utc = try await first.alert(uuid: alertID)
    try await first.replaceAccessToken("new")
    _ = try await first.modifyAlert(uuid: alertID, alert: simpleAlertRequest())
    let ist = try await second.createAlert(simpleAlertRequest())
    #expect(utc.createdAt.timeIntervalSince(ist.createdAt) == 19800)
    #expect(utc.updatedAt == ist.updatedAt)
    try await first.replaceAccessToken(nil)
    do {
        _ = try await first.alert(uuid: alertID)
        Issue.record("Expected missing credentials")
    } catch let KiteError.validation(field, _) { #expect(field == "accessToken") }
    let sent = await transport.requests
    #expect(
        sent.map { $0.headers["Authorization"] } == [
            "token one:old", "token one:new", "token two:other",
        ],
    )
    #expect(sent[0].timeout == 13)
}

@Test func alertsAllowServerOwnedAttributesExchangesAndNegativeComparisons() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":\#(alertJSON)}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var request = simpleAlertRequest()
    request.condition.lhs.attribute = "FutureAttribute"
    request.condition.lhs.exchange = .unknown("FUTURE")
    request.condition.rhs = .constant(Decimal(string: "-0.0001")!)
    _ = try await client.createAlert(request)
    #expect(await transport.requests.first?.body?.contains(Data("rhs_constant=-0.0001".utf8)) == true)
}

@Test(arguments: ["get", "list", "history"])
func alertsReadTransportFailuresAreSingleAttempt(operation: String) async throws {
    let transport = FailingHTTP()
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        try await performAlertOperation(operation, client: client)
        Issue.record("Expected transport failure")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    #expect(await transport.attempts == 1)
}
