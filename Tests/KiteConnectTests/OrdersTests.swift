import Foundation
import KiteConnect
import Testing

private func orderClient(_ body: String = orderBookJSON, zone: String = "Asia/Kolkata") throws
  -> (KiteClient, ControlledHTTP)
{
  let transport = ControlledHTTP(body)
  let config = try KiteConfiguration(
    baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 7,
    tradingTimeZone: TimeZone(identifier: zone)!)
  return (
    try KiteClient(
      apiKey: "fixture-key", accessToken: "fixture-token",
      configuration: config, transport: transport), transport
  )
}

@Test func ordersReadDocumentedBookWithoutWriting() async throws {
  let (client, transport) = try orderClient()
  let orders = try await client.orders()
  #expect(orders.count == 10)
  #expect(orders[0].orderID == "100000000000000")
  #expect(orders[0].status == .cancelled)
  #expect(orders[1].averagePrice == Decimal(string: "109.4"))
  #expect(orders[3].exchangeOrderID == nil)
  #expect(orders[3].parentOrderID == nil)
  #expect(orders[3].quantity == 200)
  let requests = await transport.requests
  #expect(requests.count == 1)
  #expect(requests[0].url.absoluteString == "https://sandbox.kite.trade/oms/orders")
  #expect(requests[0].method == .get)
  #expect(requests[0].headers["X-Kite-Version"] == "3")
  #expect(requests[0].headers["Authorization"] == "token fixture-key:fixture-token")
  #expect(requests[0].body == nil)
  #expect(requests[0].timeout == 7)
}

@Test func ordersReadHistoryForCallerSuppliedIDAndPreserveInterimStates() async throws {
  let (client, transport) = try orderClient(orderHistoryJSON)
  let history = try await client.orderHistory(orderID: "171229000724687")
  #expect(history.count == 8)
  #expect(history[0].status == .putOrderRequestReceived)
  #expect(history[1].status == .validationPending)
  #expect(history[4].status == .modifyValidationPending)
  #expect(history[6].status == .modified)
  #expect(history[7].status == .open)
  #expect(history[0].orderTimestamp.timeIntervalSince1970 == 1_514_525_812)
  #expect(history[0].orderTimestampRaw == "2017-12-29 11:06:52")
  #expect(history[0].exchangeTimestamp == nil)
  #expect(history[0].exchangeUpdateTimestamp == nil)
  #expect(history[0].marketProtection == nil)
  #expect(history[0].modified == false)
  #expect(history[7].price == Decimal(string: "300.1"))
  #expect(history[7].triggerPrice == 0)
  #expect(history[7].disclosedQuantity == 0)
  #expect(history[7].pendingQuantity == 1)
  #expect(history[7].filledQuantity == 0)
  #expect(history[7].cancelledQuantity == 0)
  #expect(history[7].exchange == .nse)
  #expect(history[7].tradingSymbol == "SBIN")
  #expect(history[7].instrumentToken == 779521)
  #expect(history[7].transactionType == .buy)
  #expect(history[7].orderType == .limit)
  #expect(history[7].product == .cnc)
  #expect(history[7].validity == .day)
  #expect(history[7].variety == .regular)
  #expect(history[7].placedBy == "DA0017")
  let requests = await transport.requests
  #expect(requests.count == 1)
  #expect(requests[0].url.path == "/oms/orders/171229000724687")
  #expect(requests[0].method == .get)
  #expect(requests[0].headers["X-Kite-Version"] == "3")
  #expect(requests[0].headers["Authorization"] == "token fixture-key:fixture-token")
  #expect(requests[0].body == nil)
}

@Test func ordersReadAllTradesAndOrderTradesAsSeparateFills() async throws {
  let (client, allTransport) = try orderClient(allTradesJSON)
  let trades = try await client.trades()
  #expect(trades.count == 4)
  #expect(trades[0].tradeID == "10000000")
  #expect(trades[0].orderID == "200000000000000")
  #expect(trades[0].exchangeOrderID == "300000000000000")
  #expect(trades[0].averagePrice == Decimal(string: "420.65"))
  #expect(trades[0].quantity == 1)
  #expect(trades[0].orderTimestamp == .timeOfDay(hour: 9, minute: 16, second: 39))
  #expect(trades[0].orderTimestampRaw == "09:16:39")
  #expect(trades[0].fillTimestamp.timeIntervalSince1970 == 1_622_432_799)
  #expect(trades[0].exchangeTimestamp == trades[0].fillTimestamp)
  #expect(trades[0].exchange == .nse)
  #expect(trades[0].tradingSymbol == "SBIN")
  #expect(trades[0].instrumentToken == 779521)
  #expect(trades[0].transactionType == .buy)
  #expect(trades[0].product == .cnc)
  #expect(trades[1].averagePrice == Decimal(string: "72.755"))
  let (orderClient, orderTransport) = try orderClient(orderTradesJSON)
  let fills = try await orderClient.orderTrades(orderID: "200000000000000")
  #expect(fills.count == 1)
  #expect(fills[0].averagePrice == 4852)
  #expect(fills[0].orderTimestamp == .timeOfDay(hour: 16, minute: 0, second: 36))
  let requests = await allTransport.requests + orderTransport.requests
  #expect(requests.map(\.url.path) == ["/oms/trades", "/oms/orders/200000000000000/trades"])
  #expect(requests.allSatisfy { $0.method == .get && $0.body == nil })
  #expect(requests.allSatisfy { $0.headers["X-Kite-Version"] == "3" })
  #expect(requests.allSatisfy { $0.headers["Authorization"] == "token fixture-key:fixture-token" })
}

@Test func ordersPreserveOptionalMetadataAndOpenValues() async throws {
  let (client, _) = try orderClient()
  let book = try await client.orders()
  #expect(book[3].validityTTL == 2)
  #expect(book[3].tag == "icebergord")
  #expect(book[3].tags == ["icebergord"])
  #expect(
    book[3].meta
      == .object([
        "iceberg": .object([
          "leg": .number(1), "legs": .number(5), "leg_quantity": .number(200),
          "total_quantity": .number(1000), "remaining_quantity": .number(800),
        ])
      ]))
  #expect(book[6].auctionNumber == "22")
  #expect(book[6].guid == nil)
  #expect(book[7].accountID == "XXXXXX")
  #expect(book[9].terminalID == "111111111111100")
  #expect(book[8].tags == ["mktp", "mktp:2.00"])
  let unknown =
    orderHistoryJSON
    .replacingOccurrences(of: "PUT ORDER REQ RECEIVED", with: "FUTURE STATE")
    .replacingOccurrences(of: #""BUY""#, with: #""FUTURE SIDE""#)
    .replacingOccurrences(of: #""regular""#, with: #""future-variety""#)
    .replacingOccurrences(of: #""DAY""#, with: #""FUTURE VALIDITY""#)
  let (futureClient, _) = try orderClient(unknown)
  let order = try #require(try await futureClient.orders().first)
  #expect(order.status == .unknown("FUTURE STATE"))
  #expect(order.transactionType == .unknown("FUTURE SIDE"))
  #expect(order.variety == .unknown("future-variety"))
  #expect(order.validity == .unknown("FUTURE VALIDITY"))
}

@Test(arguments: [
  "", " ", "123/456", "../orders", "12..34", "123?x=1", "123#x", "123\n", "123\\456",
])
func ordersRejectInvalidIDBeforeTransport(id: String) async throws {
  let (client, transport) = try orderClient(#"{"status":"success","data":[]}"#)
  for history in [true, false] {
    do {
      if history {
        _ = try await client.orderHistory(orderID: id)
      } else {
        _ = try await client.orderTrades(orderID: id)
      }
      Issue.record("Invalid ID must fail before HTTP")
    } catch KiteError.validation(let field, _) { #expect(field == "orderID") }
  }
  #expect(await transport.requests.isEmpty)
}

private func changingFirstRow(_ body: String, _ change: (inout [String: Any]) -> Void) throws
  -> String
{
  let object = try #require(
    try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
  var row = try #require((object["data"] as? [[String: Any]])?.first)
  change(&row)
  return String(
    decoding: try JSONSerialization.data(withJSONObject: [
      "status": "success", "data": [row], "future": true,
    ]), as: UTF8.self)
}

@Test func ordersSupportDocumentedStringTokensAndTradeFilledSpelling() async throws {
  let body = try changingFirstRow(allTradesJSON) {
    $0["instrument_token"] = "779521"
    $0.removeValue(forKey: "quantity")
    $0["filled"] = 3
    $0["exchange_order_id"] = NSNull()
  }
  let (client, _) = try orderClient(body)
  let trade = try #require(try await client.trades().first)
  #expect(trade.instrumentToken == 779521)
  #expect(trade.quantity == 3)
  #expect(trade.filled == 3)
  #expect(trade.exchangeOrderID == nil)
  let orderBody = try changingFirstRow(orderBookJSON) { $0["instrument_token"] = "412675" }
  let (ordersClient, _) = try orderClient(orderBody)
  #expect(try await ordersClient.orders().first?.instrumentToken == 412675)
}

@Test(arguments: [
  "quantity", "disclosed_quantity", "filled_quantity", "pending_quantity", "cancelled_quantity",
  "validity_ttl",
])
func ordersRejectNegativeQuantities(field: String) async throws {
  let body = try changingFirstRow(orderBookJSON) { $0[field] = -1 }
  let (client, _) = try orderClient(body)
  do {
    _ = try await client.orders()
    Issue.record("Negative order quantity must fail")
  } catch KiteError.decoding(let status, _) { #expect(status == 200) }
}

@Test(arguments: ["quantity", "filled"])
func ordersRejectNegativeTradeQuantities(field: String) async throws {
  let body = try changingFirstRow(allTradesJSON) { $0[field] = -1 }
  let (client, _) = try orderClient(body)
  do {
    _ = try await client.trades()
    Issue.record("Negative trade quantity must fail")
  } catch KiteError.decoding {}
}

@Test func ordersPreserveFinancialPrecisionAndZeroWithoutBusinessRules() async throws {
  let body =
    orderHistoryJSON
    .replacingOccurrences(of: #""price": 300,"#, with: #""price": 123.45000000000000000001,"#)
    .replacingOccurrences(
      of: #""average_price": 0,"#, with: #""average_price": 0.10000000000000000001,"#
    )
    .replacingOccurrences(
      of: #""trigger_price": 0,"#, with: #""trigger_price": -0.00000000000000000001,"#)
  let (client, _) = try orderClient(body)
  let order = try #require(try await client.orders().first)
  #expect(order.price == Decimal(string: "123.45000000000000000001"))
  #expect(order.averagePrice == Decimal(string: "0.10000000000000000001"))
  #expect(order.triggerPrice == Decimal(string: "-0.00000000000000000001"))
  let tradeBody = allTradesJSON.replacingOccurrences(of: "420.65", with: "420.65000000000000000001")
  let (tradeClient, _) = try orderClient(tradeBody)
  #expect(
    try await tradeClient.trades().first?.averagePrice
      == Decimal(string: "420.65000000000000000001"))
}

@Test(arguments: [
  "order_id", "status", "modified", "placed_by", "exchange", "tradingsymbol", "instrument_token",
  "variety", "transaction_type", "order_type", "product", "validity", "quantity",
  "disclosed_quantity", "filled_quantity", "pending_quantity", "cancelled_quantity", "price",
  "trigger_price", "average_price", "order_timestamp",
])
func ordersRejectMissingAndNullRequiredFields(field: String) async throws {
  for null in [false, true] {
    let body = try changingFirstRow(orderBookJSON) {
      if null { $0[field] = NSNull() } else { $0.removeValue(forKey: field) }
    }
    let (client, _) = try orderClient(body)
    do {
      _ = try await client.orders()
      Issue.record("Missing/null required order field must fail: \(field)")
    } catch KiteError.decoding(let status, let message) {
      #expect(status == 200)
      #expect(message.contains(field))
    }
  }
}

@Test(arguments: [
  "trade_id", "order_id", "exchange", "tradingsymbol", "instrument_token", "transaction_type",
  "product", "average_price", "quantity", "fill_timestamp", "order_timestamp", "exchange_timestamp",
])
func ordersRejectMissingAndNullRequiredTradeFields(field: String) async throws {
  for null in [false, true] {
    let body = try changingFirstRow(allTradesJSON) {
      if null { $0[field] = NSNull() } else { $0.removeValue(forKey: field) }
    }
    let (client, _) = try orderClient(body)
    do {
      _ = try await client.trades()
      Issue.record("Missing/null required trade field must fail: \(field)")
    } catch KiteError.decoding(let status, _) { #expect(status == 200) }
  }
}

@Test(arguments: [
  "price", "average_price", "trigger_price", "quantity", "filled_quantity", "pending_quantity",
  "cancelled_quantity", "disclosed_quantity", "instrument_token", "exchange_order_id",
  "parent_order_id", "order_id", "modified", "exchange_timestamp", "exchange_update_timestamp",
  "market_protection", "validity_ttl", "tags", "guid", "auction_number",
])
func ordersRejectMalformedPresentFields(field: String) async throws {
  let body = try changingFirstRow(orderBookJSON) { $0[field] = ["invalid": true] }
  let (client, _) = try orderClient(body)
  do {
    _ = try await client.orders()
    Issue.record("Malformed present field must fail: \(field)")
  } catch KiteError.decoding {}
}

@Test(arguments: [
  "quantity", "filled_quantity", "pending_quantity", "cancelled_quantity", "disclosed_quantity",
  "instrument_token",
])
func ordersRejectFractionalCounts(field: String) async throws {
  let body = try changingFirstRow(orderBookJSON) { $0[field] = 1.5 }
  let (client, _) = try orderClient(body)
  do {
    _ = try await client.orders()
    Issue.record("Fractional count must fail")
  } catch KiteError.decoding {}
}

@Test func ordersAcceptAbsentOrNullOptionalFieldsAndAdditionalFields() async throws {
  for null in [false, true] {
    let body = try changingFirstRow(orderBookJSON) {
      for key in [
        "exchange_order_id", "parent_order_id", "status_message", "status_message_raw",
        "exchange_timestamp", "exchange_update_timestamp", "market_protection", "validity_ttl",
        "auction_number", "tag", "tags", "guid", "meta", "account_id", "terminal_id",
      ] {
        if null { $0[key] = NSNull() } else { $0.removeValue(forKey: key) }
      }
      $0["future"] = ["any": [1, 2, 3]]
    }
    let (client, _) = try orderClient(body)
    let order = try #require(try await client.orders().first)
    #expect(order.exchangeOrderID == nil && order.parentOrderID == nil)
    #expect(order.exchangeTimestamp == nil && order.exchangeUpdateTimestamp == nil)
    #expect(order.marketProtection == nil && order.validityTTL == nil)
    #expect(order.meta == nil && order.guid == nil && order.tags == nil)
  }
}

@Test(arguments: ["UTC", "Asia/Kolkata"])
func ordersUseConfiguredTimestampZoneAndHonorExplicitOffsets(zone: String) async throws {
  let (client, _) = try orderClient(zone: zone)
  let order = try #require(try await client.orders().first)
  #expect(
    order.orderTimestamp.timeIntervalSince1970 == (zone == "UTC" ? 1_622_452_737 : 1_622_432_937))
  for stamp in [
    "2021-05-31T09:18:57+0530", "2021-05-31 09:18:57+05:30", "2021-05-31T03:48:57Z",
    "2021-05-30T23:48:57-04:00",
  ] {
    let body = try changingFirstRow(orderBookJSON) {
      $0["order_timestamp"] = stamp
      $0["exchange_timestamp"] = stamp
      $0["exchange_update_timestamp"] = stamp
    }
    let (offsetClient, _) = try orderClient(body, zone: zone)
    let result = try #require(try await offsetClient.orders().first)
    #expect(result.orderTimestamp.timeIntervalSince1970 == 1_622_432_937)
    #expect(result.exchangeTimestamp == result.orderTimestamp)
    #expect(result.exchangeUpdateTimestamp == result.orderTimestamp)
  }
}

@Test(arguments: [
  "2021-02-29 09:18:57", "2021-05-31 24:00:00", "2021-05-31 09:60:00", "2021-05-31 09:18:60",
  "2021-05-31 09:18:57+2560", "2021-05-31 09:18:57\n", "2021-05-31", "bad", "2026-03-08 02:30:00",
])
func ordersRejectMalformedTimestamps(timestamp: String) async throws {
  let body = try changingFirstRow(orderBookJSON) { $0["order_timestamp"] = timestamp }
  let (client, _) = try orderClient(body, zone: "America/New_York")
  do {
    _ = try await client.orders()
    Issue.record("Malformed timestamp must fail")
  } catch KiteError.decoding {}
}

@Test func ordersTradeFullTimestampsHonorOffsetsAndConfiguredZone() async throws {
  let body = try changingFirstRow(allTradesJSON) {
    $0["order_timestamp"] = "2021-05-31T03:46:39Z"
    $0["fill_timestamp"] = "2021-05-31 09:16:39"
    $0["exchange_timestamp"] = "2021-05-31T09:16:39+0530"
  }
  let (client, _) = try orderClient(body)
  let trade = try #require(try await client.trades().first)
  #expect(trade.orderTimestamp == .instant(Date(timeIntervalSince1970: 1_622_432_799)))
  #expect(trade.fillTimestamp.timeIntervalSince1970 == 1_622_432_799)
  #expect(trade.exchangeTimestamp == trade.fillTimestamp)
}

@Test(arguments: ["24:00:00", "12:60:00", "12:00:60", "9:16:39", "09:16:39Z", "09:16:39\n"])
func ordersRejectMalformedTradeClock(timestamp: String) async throws {
  let body = try changingFirstRow(allTradesJSON) { $0["order_timestamp"] = timestamp }
  let (client, _) = try orderClient(body)
  do {
    _ = try await client.trades()
    Issue.record("Malformed time of day must fail")
  } catch KiteError.decoding {}
}

@Test func ordersExposeReusableUpdateQuantitiesAndFinancialMetadata() async throws {
  let body = try changingFirstRow(orderBookJSON) {
    $0["unfilled_quantity"] = 1
    $0["market_protection"] = -1
    $0["meta"] = "broker annotation"
  }
  let (client, _) = try orderClient(body)
  let order = try #require(try await client.orders().first)
  #expect(order.update.unfilledQuantity == 1)
  #expect(order.update.marketProtection == -1)
  #expect(order.update.meta == .string("broker annotation"))
  #expect(order.update.status == order.status)
  #expect(order.update.orderTimestampRaw == "2021-05-31 09:18:57")
}

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
      request.url.absoluteString == "https://sandbox.kite.trade/oms/orders/external_A-7%252F/trades"
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
  ])
private func ordersRejectMalformedEnvelopes(operation: OrderRead, body: String) async throws {
  let (client, transport) = try orderClient(body)
  do {
    try await operation.perform(client)
    Issue.record("Malformed collection/envelope must fail")
  } catch KiteError.decoding(let status, _) { #expect(status == 200) }
  #expect(await transport.requests.count == 1)
}

@Test(arguments: OrderRead.allCases, [401, 429, 503])
private func ordersPreserveAPIErrorsWithoutRetry(operation: OrderRead, status: Int) async throws {
  let transport = ControlledHTTP(
    #"{"status":"error","error_type":"FutureOrderException","message":"Unavailable"}"#,
    status: status)
  let client = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: transport)
  do {
    try await operation.perform(client)
    Issue.record("Expected API error")
  } catch KiteError.api(let error) {
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
    configuration: .sandbox, transport: transport)
  do {
    try await operation.perform(client)
    Issue.record("Expected transport error")
  } catch KiteError.transport(let code, _) { #expect(code == URLError.timedOut.rawValue) }
  #expect(await transport.attempts == 1)
  let cancelled = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: CancelledHTTP())
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
    configuration: .sandbox, transport: transport)
  let task = Task { try await operation.perform(client) }
  for await _ in transport.started { break }
  task.cancel()
  await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func ordersIsolateSessionsAndApplyReplacementCredentials() async throws {
  let transport = ControlledHTTP(#"{"status":"success","data":[]}"#)
  let first = try KiteClient(
    apiKey: "first", accessToken: "old", configuration: .sandbox, transport: transport)
  let second = try KiteClient(
    apiKey: "second", accessToken: "other", configuration: .sandbox, transport: transport)
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
    ])
  #expect(requests[2].headers["Authorization"] == "token first:new")
  #expect(requests[3].headers["Authorization"] == "token second:other")
  try await first.replaceAccessToken(nil)
  for operation in OrderRead.allCases {
    do {
      try await operation.perform(first)
      Issue.record("Missing credentials must fail")
    } catch KiteError.validation(let field, _) { #expect(field == "accessToken") }
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
    with: #""market_protection": 2.00000000000000000001"#)
  let (precisionClient, _) = try orderClient(precisionBody)
  #expect(
    try await precisionClient.orders().first?.marketProtection
      == Decimal(string: "2.00000000000000000001"))
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
    of: #""instrument_token": 1,"#, with: #""instrument_token": "# + token + ",")
  let (client, _) = try orderClient(body)
  do {
    _ = try await client.orderHistory(orderID: "external-order")
    Issue.record("Invalid uint32 token must fail")
  } catch KiteError.decoding {}
}

@Test func ordersRejectOverflowingCountsAndPreserveFractionalSeconds() async throws {
  let overflow = orderHistoryJSON.replacingOccurrences(
    of: #""quantity": 1,"#,
    with: #""quantity": 9223372036854775808,"#)
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
      == 1622432937.125)
}
