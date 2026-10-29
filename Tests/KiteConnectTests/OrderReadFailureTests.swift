//
//  OrderReadFailureTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

private enum OrderRead: CaseIterable, Sendable {
    case book, history, trades, orderTrades
    func perform(_ client: KiteClient) async throws {
        switch self {
        case .book: _ = try await client.orders()
        case .history: _ = try await client.orderHistory(orderID: "external_A-7%2F")
        case .trades: _ = try await client.trades()
        case .orderTrades: _ = try await client.orderTrades(orderID: "external_A-7%2F")
        }
    }
}

@Test(arguments: OrderRead.allCases)
private func ordersEmptyCollectionsAndOpaqueCallerIDs(operation: OrderRead) async throws {
    let (client, transport) = try orderClient(#"{"status":"success","data":[]}"#)
    try await operation.perform(client)
    let request = try #require(await transport.requests.first)
    switch operation {
    case .book: #expect(request.url.absoluteString == "https://sandbox.kite.trade/oms/orders")
    case .history:
        #expect(request.url.absoluteString == "https://sandbox.kite.trade/oms/orders/external_A-7%252F")
    case .trades: #expect(request.url.absoluteString == "https://sandbox.kite.trade/oms/trades")
    case .orderTrades:
        #expect(
            request.url.absoluteString == "https://sandbox.kite.trade/oms/orders/external_A-7%252F/trades",
        )
    }
    #expect(await transport.requests.count == 1)
}

@Test(
    arguments: OrderRead.allCases,
    [
        #"{"status":"success","data":null}"#, #"{"status":"success","data":{}}"#,
        #"{"status":"success","data":[null]}"#, #"{"status":"success","data":[{}]}"#,
        #"{"status":"success"}"#, #"{"status":"future","data":[]}"#, "invalid JSON",
    ],
)
private func ordersRejectMalformedEnvelopes(operation: OrderRead, body: String) async throws {
    let (client, transport) = try orderClient(body)
    do {
        try await operation.perform(client)
        Issue.record("Malformed collection/envelope must fail")
    } catch let KiteError.decoding(status, _) { #expect(status == 200) }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: OrderRead.allCases, [401, 429, 503])
private func ordersPreserveAPIErrorsWithoutRetry(operation: OrderRead, status: Int) async throws {
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FutureOrderException","message":"Unavailable"}"#,
        status: status,
    )
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token",
        configuration: .sandbox, transport: transport,
    )
    do {
        try await operation.perform(client)
        Issue.record("Expected API error")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == status)
        #expect(error.errorType == "FutureOrderException")
        #expect(error.message == "Unavailable")
    }
    #expect(await transport.requests.count == 1)
}

@Test(arguments: OrderRead.allCases)
private func ordersPreserveSingleAttemptTransportErrorsAndCancellation(operation: OrderRead)
    async throws
{
    let transport = FailingHTTP()
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token",
        configuration: .sandbox, transport: transport,
    )
    do {
        try await operation.perform(client)
        Issue.record("Expected transport error")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    #expect(await transport.attempts == 1)
    let cancelled = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token",
        configuration: .sandbox, transport: CancelledHTTP(),
    )
    await #expect(throws: CancellationError.self) { try await operation.perform(cancelled) }
    let (preCancelled, beforeTransport) = try orderClient()
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await operation.perform(preCancelled)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(await beforeTransport.requests.isEmpty)
}

@Test(arguments: OrderRead.allCases)
private func ordersCancellationReachesInFlightTransport(operation: OrderRead) async throws {
    let transport = SuspendedHTTP()
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token",
        configuration: .sandbox, transport: transport,
    )
    let task = Task { try await operation.perform(client) }
    for await _ in transport.started {
        break
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func ordersIsolateSessionsAndApplyReplacementCredentials() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":[]}"#)
    let first = try KiteClient(
        apiKey: "first", accessToken: "old", configuration: .sandbox, transport: transport,
    )
    let second = try KiteClient(
        apiKey: "second", accessToken: "other", configuration: .sandbox, transport: transport,
    )
    async let a = first.orders()
    async let b = second.trades()
    _ = try await (a, b)
    try await first.replaceAccessToken("new")
    _ = try await first.orderHistory(orderID: "external-order")
    _ = try await second.orderTrades(orderID: "external-order")
    let requests = await transport.requests
    #expect(
        Set(requests.prefix(2).compactMap { $0.headers["Authorization"] }) == [
            "token first:old", "token second:other",
        ],
    )
    #expect(requests[2].headers["Authorization"] == "token first:new")
    #expect(requests[3].headers["Authorization"] == "token second:other")
    try await first.replaceAccessToken(nil)
    for operation in OrderRead.allCases {
        do {
            try await operation.perform(first)
            Issue.record("Missing credentials must fail")
        } catch let KiteError.validation(field, _) { #expect(field == "accessToken") }
    }
    #expect(await transport.requests.count == 4)
}

@Test(arguments: ["trade_id", "order_id"])
func ordersRejectEmptyRequiredIdentifiers(field: String) async throws {
    let tradeBody = try changingFirstRow(allTradesJSON) { $0[field] = "" }
    let (tradeClient, _) = try orderClient(tradeBody)
    do {
        _ = try await tradeClient.trades()
        Issue.record("Empty required trade identifier must fail")
    } catch KiteError.decoding {}
    if field == "order_id" {
        let body = try changingFirstRow(orderBookJSON) { $0[field] = "" }
        let (client, _) = try orderClient(body)
        do {
            _ = try await client.orders()
            Issue.record("Empty required order identifier must fail")
        } catch KiteError.decoding {}
    }
}

@Test func ordersPreserveLargeQuantitiesIdentifiersAndNullableDetails() async throws {
    let body = try changingFirstRow(orderBookJSON) {
        $0["quantity"] = Int64.max
        $0["order_id"] = "001953367517686685697"
        $0["parent_order_id"] = "external-parent"
        $0["status_message"] = "Broker explanation"
        $0["status_message_raw"] = "OMS explanation"
        $0["meta"] = ["nested": [true, NSNull(), "annotation"]]
    }
    let (client, _) = try orderClient(body)
    let order = try #require(try await client.orders().first)
    #expect(order.quantity == Int64.max)
    #expect(order.orderID == "001953367517686685697")
    #expect(order.parentOrderID == "external-parent")
    #expect(order.statusMessage == "Broker explanation")
    #expect(order.statusMessageRaw == "OMS explanation")
    #expect(order.meta == .object(["nested": .array([.bool(true), .null, .string("annotation")])]))
    let precisionBody = orderBookJSON.replacingOccurrences(
        of: #""market_protection": 0"#,
        with: #""market_protection": 2.00000000000000000001"#,
    )
    let (precisionClient, _) = try orderClient(precisionBody)
    #expect(
        try await precisionClient.orders().first?.marketProtection
            == Decimal(string: "2.00000000000000000001"),
    )
}

@Test(arguments: [
    "quantity", "filled", "instrument_token", "average_price", "exchange_order_id", "trade_id",
    "order_id", "fill_timestamp", "exchange_timestamp",
])
func ordersRejectMalformedTradeFields(field: String) async throws {
    let body = try changingFirstRow(allTradesJSON) { $0[field] = ["invalid": true] }
    let (client, _) = try orderClient(body)
    do {
        _ = try await client.trades()
        Issue.record("Malformed trade field must fail")
    } catch KiteError.decoding {}
}

@Test(arguments: [
    "4294967296", "-1", "1.5", #""4294967296""#, #""-1""#, #""1.5""#, #"" 1""#, #""""#,
])
func ordersRejectOutOfRangeAndMalformedInstrumentTokens(token: String) async throws {
    let body = orderHistoryJSON.replacingOccurrences(
        of: #""instrument_token": 1,"#, with: #""instrument_token": "# + token + ",",
    )
    let (client, _) = try orderClient(body)
    do {
        _ = try await client.orderHistory(orderID: "external-order")
        Issue.record("Invalid uint32 token must fail")
    } catch KiteError.decoding {}
}

@Test func ordersRejectOverflowingCountsAndPreserveFractionalSeconds() async throws {
    let overflow = orderHistoryJSON.replacingOccurrences(
        of: #""quantity": 1,"#,
        with: #""quantity": 9223372036854775808,"#,
    )
    let (client, _) = try orderClient(overflow)
    do {
        _ = try await client.orders()
        Issue.record("Overflowing quantity must fail")
    } catch KiteError.decoding {}
    let fractional = try changingFirstRow(orderBookJSON) {
        $0["order_timestamp"] = "2021-05-31T03:48:57.125Z"
    }
    let (fractionalClient, _) = try orderClient(fractional)
    #expect(
        try await fractionalClient.orders().first?.orderTimestamp.timeIntervalSince1970
            == 1_622_432_937.125,
    )
}
