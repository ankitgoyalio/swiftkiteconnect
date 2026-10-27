import Foundation
import KiteConnect
import Testing

private let mutationReceipt =
  #"{"status":"success","data":{"order_id":"151220000000000","future":true}}"#

@Test func orderMutationPlacesLimitWithExactDocumentedForm() async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  var request = KiteOrderPlacement(
    tradingSymbol: "A B+C&", exchange: .nse, transactionType: .buy,
    orderType: .limit, quantity: 1, product: .cnc)
  request.price = Decimal(string: "123.4501")!
  request.validity = .day
  let result = try await client.placeOrder(request)
  guard case .order(let receipt) = result else {
    Issue.record("Expected single receipt")
    return
  }
  #expect(receipt.orderID == "151220000000000")
  let sent = try #require(await transport.requests.first)
  #expect(await transport.requests.count == 1)
  #expect(sent.method == .post)
  #expect(sent.url.absoluteString == "https://sandbox.kite.trade/oms/orders/regular")
  #expect(sent.headers["Authorization"] == "token key:token")
  #expect(sent.headers["X-Kite-Version"] == "3")
  #expect(sent.headers["Content-Type"] == "application/x-www-form-urlencoded")
  #expect(
    String(decoding: sent.body!, as: UTF8.self)
      == "tradingsymbol=A%20B%2BC%26&exchange=NSE&transaction_type=BUY&order_type=LIMIT&quantity=1&product=CNC&price=123.4501&validity=DAY"
  )
}

@Test func orderMutationEncodesAllPlacementOptionsAndVarieties() async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  for variety in KiteOrderMutationVariety.allCases {
    var order = KiteOrderPlacement(
      tradingSymbol: "SBIN", exchange: .nse, transactionType: .sell,
      orderType: .stopLoss, quantity: 1000, product: .unknown("MTF"))
    order.variety = variety
    order.price = 463
    order.triggerPrice = Decimal(string: "462.05")!
    order.disclosedQuantity = 0
    order.validity = .ttl
    order.validityTTL = 2
    order.icebergLegs = 5
    order.icebergQuantity = 200
    order.auctionNumber = "22+A"
    order.marketProtection = -1
    order.autoslice = true
    order.tag = "Strategy123"
    _ = try await client.placeOrder(order)
  }
  let sent = await transport.requests
  #expect(
    sent.map(\.url.path) == [
      "/oms/orders/regular", "/oms/orders/amo", "/oms/orders/co", "/oms/orders/iceberg",
      "/oms/orders/auction",
    ])
  #expect(
    sent.allSatisfy {
      String(decoding: $0.body!, as: UTF8.self)
        == "tradingsymbol=SBIN&exchange=NSE&transaction_type=SELL&order_type=SL&quantity=1000&product=MTF&price=463&validity=TTL&trigger_price=462.05&disclosed_quantity=0&validity_ttl=2&iceberg_legs=5&iceberg_quantity=200&auction_number=22%2BA&market_protection=-1&autoslice=true&tag=Strategy123"
    })
}

@Test func orderMutationModifiesAndCancelsChildWithParentIdentifier() async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  var change = KiteOrderModification()
  change.orderType = .stopLossMarket
  change.quantity = 3
  change.price = Decimal(string: "300.05")!
  change.triggerPrice = Decimal(string: "299.95")!
  change.disclosedQuantity = 0
  change.validity = .ttl
  change.validityTTL = 5
  change.marketProtection = Decimal(string: "2.5")!
  let modified = try await client.modifyOrder(
    orderID: "child-1", variety: .co, parentOrderID: "parent+A", changes: change)
  let cancelled = try await client.cancelOrder(
    orderID: "child-1", variety: .co, parentOrderID: "parent+A")
  #expect(modified.orderID == "151220000000000")
  #expect(cancelled.orderID == modified.orderID)
  let sent = await transport.requests
  #expect(sent.count == 2)
  #expect(sent[0].method == .put)
  #expect(sent[0].url.path == "/oms/orders/co/child-1")
  #expect(sent[0].url.query == nil)
  #expect(
    String(decoding: sent[0].body!, as: UTF8.self)
      == "order_type=SL-M&quantity=3&price=300.05&trigger_price=299.95&disclosed_quantity=0&validity=TTL&validity_ttl=5&market_protection=2.5&parent_order_id=parent%2BA"
  )
  #expect(sent[1].method == .delete)
  #expect(
    sent[1].url.absoluteString
      == "https://sandbox.kite.trade/oms/orders/co/child-1?parent_order_id=parent%2BA")
  #expect(sent[1].body == nil)
}

private let mixedSlices =
  #"[{"order_id":"1914227164534824960"},{"error":{"code":400,"error_type":"FutureMarginException","message":"Insufficient funds","data":{"required":228365.92,"retry":false,"details":[null,"margin"]}}}]"#
@Test(arguments: [false, true])
func orderMutationPreservesMixedAutosliceResults(arrayShape: Bool) async throws {
  let data =
    arrayShape ? mixedSlices : #"{"order_id":"1914227164488687616","children":\#(mixedSlices)}"#
  let transport = ControlledHTTP(#"{"status":"success","data":\#(data)}"#)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  var order = KiteOrderPlacement(
    tradingSymbol: "NIFTY", exchange: .nfo, transactionType: .buy, orderType: .market,
    quantity: 10000, product: .nrml)
  order.autoslice = true
  order.marketProtection = -1
  let result = try await client.placeOrder(order)
  let slices: [KiteOrderSliceResult]
  switch result {
  case .order(let receipt):
    #expect(!arrayShape)
    #expect(receipt.orderID == "1914227164488687616")
    slices = try #require(receipt.children)
  case .slices(let values):
    #expect(arrayShape)
    slices = values
  }
  #expect(slices.count == 2)
  guard case .placed(let accepted) = slices[0], case .rejected(let error) = slices[1] else {
    Issue.record("Expected accepted slice and rejected slice")
    return
  }
  #expect(accepted.orderID == "1914227164534824960")
  #expect(error.code == 400)
  #expect(error.errorType == "FutureMarginException")
  #expect(error.message == "Insufficient funds")
  #expect(
    error.data
      == .object([
        "required": .number(Decimal(string: "228365.92")!), "retry": .bool(false),
        "details": .array([.null, .string("margin")]),
      ]))
  #expect(await transport.requests.count == 1)
}

private func limitPlacement() -> KiteOrderPlacement {
  var order = KiteOrderPlacement(
    tradingSymbol: "INFY", exchange: .nse, transactionType: .buy,
    orderType: .limit, quantity: 1, product: .cnc)
  order.price = 123
  return order
}

@Test func orderMutationRejectsMalformedStructureBeforeTransport() async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  var bad: [(String, KiteOrderPlacement)] = []
  var order = limitPlacement()
  order.tradingSymbol = " "
  bad.append(("tradingsymbol", order))
  order = limitPlacement()
  order.quantity = 0
  bad.append(("quantity", order))
  order = limitPlacement()
  order.price = nil
  bad.append(("price", order))
  order = limitPlacement()
  order.price = .nan
  bad.append(("price", order))
  order = limitPlacement()
  order.triggerPrice = -1
  bad.append(("trigger_price", order))
  order = limitPlacement()
  order.orderType = .stopLossMarket
  bad.append(("trigger_price", order))
  order = limitPlacement()
  order.disclosedQuantity = -1
  bad.append(("disclosed_quantity", order))
  order = limitPlacement()
  order.validity = .ttl
  bad.append(("validity_ttl", order))
  order = limitPlacement()
  order.validityTTL = 0
  bad.append(("validity_ttl", order))
  order = limitPlacement()
  order.variety = .iceberg
  bad.append(("iceberg_legs", order))
  order = limitPlacement()
  order.icebergLegs = 51
  bad.append(("iceberg_legs", order))
  order = limitPlacement()
  order.variety = .iceberg
  order.icebergLegs = 2
  bad.append(("iceberg_quantity", order))
  order = limitPlacement()
  order.variety = .auction
  bad.append(("auction_number", order))
  for value: Decimal in [0, -2, 101, .nan] {
    order = limitPlacement()
    order.marketProtection = value
    bad.append(("market_protection", order))
  }
  for tag in ["has space", "a&b", String(repeating: "x", count: 21), "é"] {
    order = limitPlacement()
    order.tag = tag
    bad.append(("tag", order))
  }
  for (field, request) in bad {
    do {
      _ = try await client.placeOrder(request)
      Issue.record("Expected validation for \(field)")
    } catch KiteError.validation(let actual, _) { #expect(actual == field) }
  }
  for id in ["", "../orders", "a/b", "a?x", "a#x", "a%2Fb", "a\nb"] {
    do {
      _ = try await client.cancelOrder(orderID: id)
      Issue.record("Expected identifier validation")
    } catch KiteError.validation(let field, _) { #expect(field == "order_id") }
  }
  do {
    _ = try await client.modifyOrder(orderID: "1", changes: .init())
    Issue.record("Expected empty change validation")
  } catch KiteError.validation(let field, _) { #expect(field == "changes") }
  #expect(await transport.requests.isEmpty)
}

@Test(arguments: [
  #"{}"#, #"{"order_id":null}"#, #"{"order_id":17}"#, #"{"order_id":""}"#,
  #"{"order_id":"1","children":null}"#,
  #"[{"order_id":"1","error":{"code":400,"error_type":"InputException","message":"bad","data":null}}]"#,
  #"[{"error":{"code":400,"message":"bad","data":null}}]"#,
  #"{"order_id":"1","children":[{}]}"#,
])
func orderMutationMalformedReceiptIsUncertain(data: String) async throws {
  let transport = ControlledHTTP(#"{"status":"success","data":\#(data)}"#, status: 202)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  do {
    _ = try await client.placeOrder(limitPlacement())
    Issue.record("Expected uncertain malformed receipt")
  } catch KiteError.uncertainOutcome(.decoding(let status, _)) { #expect(status == 202) }
  #expect(await transport.requests.count == 1)
}

private func performMutation(_ operation: String, client: KiteClient) async throws {
  switch operation {
  case "place": _ = try await client.placeOrder(limitPlacement())
  case "modify":
    var change = KiteOrderModification()
    change.quantity = 2
    _ = try await client.modifyOrder(orderID: "1", changes: change)
  default: _ = try await client.cancelOrder(orderID: "1")
  }
}

@Test(arguments: ["place", "modify", "cancel"], [200, 400, 401, 429, 503])
func orderMutationConfirmedRejectionNeverRetries(operation: String, status: Int) async throws {
  let transport = ControlledHTTP(
    #"{"status":"error","error_type":"FutureOrderException","message":"Rejected"}"#, status: status)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  do {
    try await performMutation(operation, client: client)
    Issue.record("Expected API rejection")
  } catch KiteError.api(let error) {
    #expect(error.statusCode == status)
    #expect(error.errorType == "FutureOrderException")
    #expect(error.message == "Rejected")
  }
  #expect(await transport.requests.count == 1)
}

@Test(arguments: ["place", "modify", "cancel"])
func orderMutationLostResponsesRemainUncertainAndCancellationRecognizable(operation: String)
  async throws
{
  let failed = FailingHTTP()
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: failed)
  do {
    try await performMutation(operation, client: client)
    Issue.record("Expected uncertainty")
  } catch KiteError.uncertainOutcome(.transport(let code, _)) {
    #expect(code == URLError.timedOut.rawValue)
  }
  #expect(await failed.attempts == 1)
  for (status, body) in [
    (502, "Bad gateway"), (200, "not json"), (200, #"{"status":"success","data":{}}"#),
  ] {
    let transport = ControlledHTTP(body, status: status)
    let client = try KiteClient(
      apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
    do {
      try await performMutation(operation, client: client)
      Issue.record("Expected uncertainty")
    } catch KiteError.uncertainOutcome(let underlying) {
      switch underlying {
      case .api(let error):
        #expect(status == 502)
        #expect(error.statusCode == 502)
      case .decoding(let actual, _):
        #expect(status == 200)
        #expect(actual == 200)
      default: Issue.record("Unexpected underlying error")
      }
    }
    #expect(await transport.requests.count == 1)
  }
  let cancelled = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: CancelledHTTP())
  await #expect(throws: CancellationError.self) {
    try await performMutation(operation, client: cancelled)
  }
  let suspended = SuspendedHTTP()
  let cancellable = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: suspended)
  let task = Task { try await performMutation(operation, client: cancellable) }
  for await _ in suspended.started { break }
  task.cancel()
  await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func orderMutationSessionsTimeoutAndOmissionArePreserved() async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let config = try KiteConfiguration(
    baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 17)
  let first = try KiteClient(
    apiKey: "one", accessToken: "old", configuration: config, transport: transport)
  let second = try KiteClient(
    apiKey: "two", accessToken: "other", configuration: .sandbox, transport: transport)
  _ = try await first.placeOrder(limitPlacement())
  try await first.replaceAccessToken("new")
  var change = KiteOrderModification()
  change.price = Decimal(string: "234.56789")!
  _ = try await first.modifyOrder(orderID: "1", variety: .amo, changes: change)
  _ = try await second.cancelOrder(orderID: "2", variety: .auction)
  try await first.replaceAccessToken(nil)
  do {
    _ = try await first.placeOrder(limitPlacement())
    Issue.record("Expected missing credentials")
  } catch KiteError.validation(let field, _) { #expect(field == "accessToken") }
  let sent = await transport.requests
  #expect(sent.count == 3)
  #expect(
    sent.map { $0.headers["Authorization"] } == [
      "token one:old", "token one:new", "token two:other",
    ])
  #expect(sent[0].timeout == 17)
  #expect(sent[1].url.path == "/oms/orders/amo/1")
  #expect(sent[1].body == Data("price=234.56789".utf8))
  #expect(sent[2].url.query == nil)
}

@Test func orderMutationModificationValidatesOnlySuppliedStructure() async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  var invalid: [(String, KiteOrderModification)] = []
  var change = KiteOrderModification()
  change.quantity = -1
  invalid.append(("quantity", change))
  change = .init()
  change.price = .nan
  invalid.append(("price", change))
  change = .init()
  change.triggerPrice = -1
  invalid.append(("trigger_price", change))
  change = .init()
  change.disclosedQuantity = -1
  invalid.append(("disclosed_quantity", change))
  change = .init()
  change.validityTTL = 0
  invalid.append(("validity_ttl", change))
  change = .init()
  change.marketProtection = 101
  invalid.append(("market_protection", change))
  for (field, changes) in invalid {
    do {
      _ = try await client.modifyOrder(orderID: "1", changes: changes)
      Issue.record("Expected validation")
    } catch KiteError.validation(let actual, _) { #expect(actual == field) }
  }
  do {
    _ = try await client.cancelOrder(orderID: "1", variety: .co, parentOrderID: "")
    Issue.record("Expected parent validation")
  } catch KiteError.validation(let field, _) { #expect(field == "parent_order_id") }
  #expect(await transport.requests.isEmpty)
  // Existing TTL/type/trigger state is unavailable locally. A partial change must remain possible.
  change = .init()
  change.validityTTL = 3
  _ = try await client.modifyOrder(orderID: "1", changes: change)
  #expect(await transport.requests.count == 1)
}

@Test func orderMutationAllowsBrokerOwnedValuesAndDocumentedBoundaries() async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  for protection: Decimal in [-1, Decimal(string: "0.01")!, 100] {
    var order = limitPlacement()
    order.marketProtection = protection
    order.autoslice = false
    order.tag = "12345678901234567890"
    order.exchange = .unknown("FUTURE")
    order.product = .unknown("MTF")
    _ = try await client.placeOrder(order)
  }
  for legs in [2, 50] {
    var order = limitPlacement()
    order.variety = .iceberg
    order.icebergLegs = legs
    order.icebergQuantity = 1
    _ = try await client.placeOrder(order)
  }
  #expect(await transport.requests.count == 5)
  #expect(await transport.requests.first?.body?.contains(Data("autoslice=false".utf8)) == true)
}

@Test func orderMutationAcceptsSnapshotAutosliceExampleWithNullErrorData() async throws {
  let transport = ControlledHTTP(
    #"""
    {"status":"success","data":{"order_id":"1914227164488687616","children":[
      {"order_id":"1914227164534824960"},
      {"order_id":"1914227164580962304"},
      {"error":{"code":400,"error_type":"MarginException","message":"Insufficient funds. Required margin is 228365.92 but available margin is 228358.50.","data":null}},
      {"order_id":"1914227164681625600"}
    ]}}
    """#)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  var order = limitPlacement()
  order.validity = .ioc
  order.autoslice = true
  let result = try await client.placeOrder(order)
  guard case .order(let receipt) = result else {
    Issue.record("Expected parent receipt")
    return
  }
  let children = try #require(receipt.children)
  #expect(children.count == 4)
  guard case .rejected(let error) = children[2] else {
    Issue.record("Expected slice rejection")
    return
  }
  #expect(error.data == .null)
  #expect(error.errorType == "MarginException")
  #expect(error.code == 400)
}

@Test(arguments: KiteOrderMutationVariety.allCases)
func orderMutationRoutesModificationAndCancellationForEveryVariety(
  variety: KiteOrderMutationVariety
) async throws {
  let transport = ControlledHTTP(mutationReceipt)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  var change = KiteOrderModification()
  change.quantity = 1
  _ = try await client.modifyOrder(orderID: "151220000000000", variety: variety, changes: change)
  _ = try await client.cancelOrder(orderID: "151220000000000", variety: variety)
  let requests = await transport.requests
  #expect(requests.count == 2)
  #expect(requests.allSatisfy { $0.url.path == "/oms/orders/\(variety.rawValue)/151220000000000" })
  #expect(requests.map(\.method) == [.put, .delete])
}
