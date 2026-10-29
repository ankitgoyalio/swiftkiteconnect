//
//  GTTTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func gttListDecodesOfficialActiveAndTriggeredExamples() async throws {
    let transport = ControlledHTTP(gttListJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let triggers = try await client.gttTriggers()
    #expect(triggers.count == 2)
    #expect(triggers[0].id == 112_127)
    #expect(triggers[0].status == .active)
    #expect(triggers[0].condition.instrumentToken == 408_065)
    #expect(triggers[0].orders[0].price == Decimal(string: "702.5"))
    #expect(triggers[0].orders[0].result == nil)
    #expect(triggers[1].type == .twoLeg)
    let result = try #require(triggers[1].orders[1].result)
    #expect(result.triggeredAt == Decimal(string: "103.7"))
    #expect(result.orderResult?.status == .failed)
    #expect(result.orderResult?.orderID == "")
    #expect(result.timestamp == triggers[1].updatedAt)
    #expect(triggers[0].createdAt == Date(timeIntervalSince1970: 1_568_274_916))
    let request = try #require(await transport.requests.first)
    #expect(request.url.absoluteString == "https://sandbox.kite.trade/oms/gtt/triggers")
    #expect(request.method == .get && request.body == nil)
    #expect(request.headers["Authorization"] == "token key:token")
    #expect(request.headers["X-Kite-Version"] == "3")
}

@Test func gttDetailPreservesUnknownValuesOptionalResultsAndTimestampOffsets() async throws {
    let body = try gttDetailJSON()
        .replacingOccurrences(of: "\"triggered\"", with: "\"future-state\"")
        .replacingOccurrences(of: "two-leg", with: "future-type")
        .replacingOccurrences(of: "failed", with: "future-result")
        .replacingOccurrences(of: "2019-09-09 15:13:22", with: "2019-09-09T09:43:22Z")
        .replacingOccurrences(of: "2019-09-09 15:15:08", with: "2019-09-09T15:15:08+05:30")
    let transport = ControlledHTTP(body)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let trigger = try await client.gttTrigger(id: 105_099)
    #expect(trigger.status == .unknown("future-state"))
    #expect(trigger.type == .unknown("future-type"))
    #expect(trigger.orders[1].result?.orderResult?.status == .unknown("future-result"))
    #expect(trigger.orders[1].result?.timestamp == trigger.updatedAt)
    #expect(trigger.createdAt == Date(timeIntervalSince1970: 1_568_022_202))
    #expect(await transport.requests.first?.url.path == "/oms/gtt/triggers/105099")
}

@Test func gttCreateEncodesSingleAndOCOAsJSONInsideFormWithDecimalPrices() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":{"trigger_id":123}}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    for twoLeg in [false, true] {
        let receipt = try await client.createGTT(gttRequest(twoLeg: twoLeg))
        #expect(receipt.triggerID == 123)
    }
    let sent = await transport.requests
    for (index, request) in sent.enumerated() {
        #expect(request.method == .post && request.url.path == "/oms/gtt/triggers")
        #expect(request.headers["Content-Type"] == "application/x-www-form-urlencoded")
        let body = String(decoding: request.body!, as: UTF8.self)
        let pairs = body.split(separator: "&").map {
            $0.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding! }
        }
        let fields = Dictionary(uniqueKeysWithValues: pairs.map { ($0[0], $0[1]) })
        #expect(Set(fields.keys) == ["type", "condition", "orders"])
        #expect(fields["type"] == (index == 0 ? "single" : "two-leg"))
        let condition =
            try JSONSerialization.jsonObject(with: Data(fields["condition"]!.utf8)) as! NSDictionary
        #expect(
            condition
                == (index == 0
                    ? ["exchange": "NSE", "tradingsymbol": "INFY", "trigger_values": [702], "last_price": 742]
                    : [
                        "exchange": "NSE", "tradingsymbol": "INFY", "trigger_values": [702, 798],
                        "last_price": 742,
                    ]) as NSDictionary,
        )
        let orders =
            try JSONSerialization.jsonObject(with: Data(fields["orders"]!.utf8)) as! [[String: Any]]
        #expect(orders.count == index + 1)
        #expect(
            Set(orders[0].keys) == [
                "exchange", "tradingsymbol", "transaction_type", "quantity", "order_type", "product",
                "price",
            ],
        )
        #expect(orders[0]["order_type"] as? String == "LIMIT")
        #expect(orders[0]["transaction_type"] as? String == "SELL")
        #expect(fields["orders"]!.contains("702.123456789123456789"))
        if index == 1 {
            #expect((orders[1]["quantity"] as? Int) == 2)
        }
    }
}

@Test func gttModifyReplacesDefinitionAndDeleteReturnsDocumentedReceipt() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":{"trigger_id":123}}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    for twoLeg in [false, true] {
        let receipt = try await client.modifyGTT(id: 123, trigger: gttRequest(twoLeg: twoLeg))
        #expect(receipt.triggerID == 123)
    }
    #expect(try await client.deleteGTT(id: 123).triggerID == 123)
    let sent = await transport.requests
    #expect(sent.map(\.method) == [.put, .put, .delete])
    #expect(sent.allSatisfy { $0.url.path == "/oms/gtt/triggers/123" && $0.url.query == nil })
    #expect(String(decoding: sent[0].body!, as: UTF8.self).hasPrefix("type=single&condition="))
    #expect(String(decoding: sent[1].body!, as: UTF8.self).hasPrefix("type=two-leg&condition="))
    #expect(sent[2].body == nil)
}

@Test func gttValidatesDocumentedCountsAndOrderShapeBeforeSending() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":{"trigger_id":123}}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var invalid: [KiteGTTRequest] = []
    var request = try gttRequest()
    request.condition.triggerValues = []
    invalid.append(request)
    request = try gttRequest()
    request.condition.triggerValues = [702, 798]
    invalid.append(request)
    request = try gttRequest(twoLeg: true)
    request.orders.removeLast()
    invalid.append(request)
    request = try gttRequest(twoLeg: true)
    request.condition.triggerValues = [702]
    invalid.append(request)
    request = try gttRequest()
    request.orders = []
    invalid.append(request)
    request = try gttRequest()
    request.type = .unknown("future")
    invalid.append(request)
    request = try gttRequest()
    request.orders[0].orderType = .market
    invalid.append(request)
    request = try gttRequest()
    request.orders[0].transactionType = .unknown("HOLD")
    invalid.append(request)
    request = try gttRequest()
    request.orders[0].quantity = 0
    invalid.append(request)
    request = try gttRequest()
    request.orders[0].product = .unknown("")
    invalid.append(request)
    request = try gttRequest()
    request.condition.lastPrice = .nan
    invalid.append(request)
    request = try gttRequest()
    request.condition.triggerValues = [.nan]
    invalid.append(request)
    request = try gttRequest()
    request.orders[0].price = .nan
    invalid.append(request)
    for request in invalid {
        do {
            _ = try await client.createGTT(request)
            Issue.record("Expected validation")
        } catch KiteError.validation {}
        do {
            _ = try await client.modifyGTT(id: 123, trigger: request)
            Issue.record("Expected validation")
        } catch KiteError.validation {}
    }
    for id: Int64 in [0, -1] {
        do {
            _ = try await client.gttTrigger(id: id)
            Issue.record("Expected validation")
        } catch KiteError.validation {}
        do {
            _ = try await client.modifyGTT(id: id, trigger: gttRequest())
            Issue.record("Expected validation")
        } catch KiteError.validation {}
        do {
            _ = try await client.deleteGTT(id: id)
            Issue.record("Expected validation")
        } catch KiteError.validation {}
    }
    #expect(await transport.requests.isEmpty)
}

@Test(arguments: ["create", "modify", "delete"], ["timeout", "gateway", "malformed"])
func gttMutationFailureIsUncertainAndNeverResubmitted(operation: String, failure: String)
    async throws
{
    if failure == "timeout" {
        let transport = FailingHTTP()
        let client = try KiteClient(
            apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
        )
        do {
            try await performGTTOperation(operation, client: client)
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
            try await performGTTOperation(operation, client: client)
            Issue.record("Expected uncertainty")
        } catch let KiteError.uncertainOutcome(cause) {
            switch cause {
            case let .api(error): #expect(failure == "gateway" && error.statusCode == 502)
            case let .decoding(status, _): #expect(failure == "malformed" && status == 200)
            default: Issue.record("Unexpected uncertainty cause")
            }
        }
        #expect(await transport.requests.count == 1)
    }
}

@Test(arguments: ["create", "modify", "delete", "get", "list"], [200, 400, 401, 429, 503])
func gttConfirmedRejectionPreservesRawAPIError(operation: String, status: Int) async throws {
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FutureGTTException","message":"Rejected"}"#, status: status,
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        try await performGTTOperation(operation, client: client)
        Issue.record("Expected confirmed rejection")
    } catch let KiteError.api(error) {
        #expect(
            error.statusCode == status && error.errorType == "FutureGTTException"
                && error.message == "Rejected",
        )
    }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: ["create", "modify", "delete", "get", "list"])
func gttCancellationRemainsRecognizable(operation: String) async throws {
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: CancelledHTTP(),
    )
    await #expect(throws: CancellationError.self) {
        try await performGTTOperation(operation, client: client)
    }
    let transport = SuspendedHTTP()
    let suspended = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let task = Task { try await performGTTOperation(operation, client: suspended) }
    for await _ in transport.started {
        break
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test(arguments: ["get", "list"])
func gttReadsAreSingleAttemptAndKeepTransportFailureDistinct(operation: String) async throws {
    let transport = FailingHTTP()
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        try await performGTTOperation(operation, client: client)
        Issue.record("Expected transport error")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    #expect(await transport.attempts == 1)
}

@Test(arguments: ["active", "triggered", "disabled", "expired", "cancelled", "rejected", "deleted"])
func gttKnownStatusesAndNullableExecutionFieldsDecode(status: String) async throws {
    var envelope =
        try JSONSerialization.jsonObject(with: Data(gttDetailJSON().utf8)) as! [String: Any]
    var trigger = envelope["data"] as! [String: Any]
    trigger["status"] = status
    trigger["future_field"] = ["anything": true]
    trigger["parent_trigger"] = 99
    var orders = trigger["orders"] as! [[String: Any]]
    orders[0].removeValue(forKey: "result")
    var result = orders[1]["result"] as! [String: Any]
    result["order_result"] = ["status": NSNull(), "order_id": NSNull()]
    result.removeValue(forKey: "meta")
    orders[1]["result"] = result
    trigger["orders"] = orders
    envelope["data"] = trigger
    let body = try String(decoding: JSONSerialization.data(withJSONObject: envelope), as: UTF8.self)
    let transport = ControlledHTTP(body)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let decoded = try await client.gttTrigger(id: 105_099)
    #expect(decoded.status.rawValue == status)
    #expect(decoded.status != .unknown(status))
    #expect(decoded.parentTrigger == 99)
    #expect(decoded.orders[0].result == nil)
    #expect(decoded.orders[1].result?.meta == nil)
    let orderResult = try #require(decoded.orders[1].result?.orderResult)
    #expect(
        orderResult.status == nil && orderResult.orderID == nil && orderResult.rejectionReason == nil,
    )
}

@Test func gttSessionsTimeoutTimezoneAndFutureFinancialValuesArePreserved() async throws {
    let json = try gttDetailJSON()
        .replacingOccurrences(of: "102.6", with: "102.123456789123456789")
        .replacingOccurrences(of: "\"NSE\"", with: "\"NEW_EXCHANGE\"")
        .replacingOccurrences(of: "\"CNC\"", with: "\"NEW_PRODUCT\"")
        .replacingOccurrences(of: "\"LIMIT\"", with: "\"NEW_ORDER_TYPE\"")
    let transport = ControlledHTTP(json)
    let config = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 17,
        tradingTimeZone: TimeZone(secondsFromGMT: 0)!,
    )
    let first = try KiteClient(
        apiKey: "one", accessToken: "old", configuration: config, transport: transport,
    )
    let second = try KiteClient(
        apiKey: "two", accessToken: "other", configuration: .sandbox, transport: transport,
    )
    let utc = try await first.gttTrigger(id: 105_099)
    try await first.replaceAccessToken("new")
    _ = try await first.gttTrigger(id: 105_099)
    let ist = try await second.gttTrigger(id: 105_099)
    #expect(utc.createdAt.timeIntervalSince(ist.createdAt) == 19800)
    #expect(utc.updatedAt.timeIntervalSince(ist.updatedAt) == 19800)
    #expect(utc.expiresAt.timeIntervalSince(ist.expiresAt) == 19800)
    #expect(
        utc.orders[1].result!.timestamp.timeIntervalSince(ist.orders[1].result!.timestamp) == 19800,
    )
    #expect(ist.condition.lastPrice == Decimal(string: "102.123456789123456789"))
    #expect(ist.condition.exchange == .unknown("NEW_EXCHANGE"))
    #expect(ist.orders[0].product == .unknown("NEW_PRODUCT"))
    #expect(ist.orders[0].orderType == .unknown("NEW_ORDER_TYPE"))
    try await first.replaceAccessToken(nil)
    do {
        _ = try await first.gttTriggers()
        Issue.record("Expected missing session")
    } catch let KiteError.validation(field, _) { #expect(field == "accessToken") }
    let requests = await transport.requests
    #expect(
        requests.map { $0.headers["Authorization"] } == [
            "token one:old", "token one:new", "token two:other",
        ],
    )
    #expect(requests[0].timeout == 17)
}

@Test(arguments: ["id", "condition", "orders", "status", "price", "timestamp", "result"])
func gttMalformedRequiredResponseDataFailsClearly(field: String) async throws {
    var envelope =
        try JSONSerialization.jsonObject(with: Data(gttDetailJSON().utf8)) as! [String: Any]
    var trigger = envelope["data"] as! [String: Any]
    switch field {
    case "price":
        var condition = trigger["condition"] as! [String: Any]
        condition["last_price"] = "invalid"
        trigger["condition"] = condition
    case "timestamp": trigger["expires_at"] = "2025-02-30 00:00:00"
    case "result":
        var orders = trigger["orders"] as! [[String: Any]]
        orders[0]["result"] = "invalid"
        trigger["orders"] = orders
    default: trigger.removeValue(forKey: field)
    }
    envelope["data"] = trigger
    let transport = try ControlledHTTP(
        String(decoding: JSONSerialization.data(withJSONObject: envelope), as: UTF8.self),
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        _ = try await client.gttTrigger(id: 123)
        Issue.record("Expected decoding error")
    } catch let KiteError.decoding(code, _) { #expect(code == 200) }
}

@Test func gttEncodingEscapesSymbolsAndLeavesBrokerRulesToServer() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":{"trigger_id":123}}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var request = try gttRequest(twoLeg: true)
    request.condition.instrument = try KiteInstrumentIdentity(
        exchange: .unknown("FUTURE"), tradingSymbol: "A+B & \"é\"",
    )
    // Equal triggers and prices away from market are the server's decision, not local policy.
    request.condition.triggerValues = [702, 702]
    request.condition.lastPrice = 702
    request.orders[0].product = .unknown("FUTURE_PRODUCT")
    _ = try await client.createGTT(request)
    let sent = try #require(await transport.requests.first)
    let body = String(decoding: sent.body!, as: UTF8.self)
    #expect(body.contains("A%2BB%20%26%20%5C%22%C3%A9%5C%22"))
    #expect(body.contains("FUTURE_PRODUCT"))
}
