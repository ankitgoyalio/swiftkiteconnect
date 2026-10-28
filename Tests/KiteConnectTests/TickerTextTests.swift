import Foundation
import KiteConnect
import Testing

@Test func tickerDeliversDocumentedOrderUpdateWithoutRESTOnlyFields() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let updates = try await ticker.orderUpdates()
  try await ticker.connect()
  transport.socket.incoming.yield(.text(orderUpdateFixture))
  var iterator = updates.makeAsyncIterator()
  let event = try #require(try await iterator.next())
  let order = event.update
  #expect(order.orderID == "220303000308932")
  #expect(order.status == .complete)
  #expect(order.averagePrice == 470)
  #expect(order.instrumentToken == 779521)
  #expect(order.product == .cnc)
  #expect(order.orderType == .market)
  #expect(order.orderTimestamp == Date(timeIntervalSince1970: 1_646_279_665))
  #expect(order.parentOrderID == nil)
  #expect(order.filledQuantity == 1)
  #expect(order.exchangeOrderID == "1000000001482421")
  #expect(order.placedBy == "AB1234")
  #expect(event.userID == "AB1234")
  #expect(event.appID == 1234)
  #expect(order.tradingSymbol == "SBIN")
  #expect(order.exchange == .nse)
  #expect(order.transactionType == .buy)
  #expect(order.validity == .day)
  #expect(order.variety == .regular)
  #expect(order.quantity == 1)
  #expect(order.disclosedQuantity == 0)
  #expect(order.unfilledQuantity == 0)
  #expect(order.pendingQuantity == 0)
  #expect(order.cancelledQuantity == 0)
  #expect(order.price == 0)
  #expect(order.triggerPrice == 0)
  #expect(order.marketProtection == 0)
  #expect(order.exchangeTimestamp == order.orderTimestamp)
  #expect(order.exchangeUpdateTimestamp == order.orderTimestamp)
  #expect(order.statusMessage == nil)
  #expect(order.statusMessageRaw == nil)
  #expect(order.tag == nil)
  #expect(order.meta == .object([:]))
  #expect(order.guid == "XXXXXX")
  #expect(event.checksum == "2011845d9348bd6795151bf4258102a03431e3bb12a79c0df73fcb4b7fde4b5d")
  await ticker.disconnect()
  #expect(try await iterator.next() == nil)
}

@Test func tickerDeliversBrokerMessagesErrorsAndUnknownTypesWithoutClosingQuotes() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let events = try await ticker.brokerEvents(bufferCapacity: 4)
  let quotes = try await ticker.ticks()
  try await ticker.connect()
  var iterator = events.makeAsyncIterator()
  for text in [
    #"{"type":"message","data":"Exchange notice"}"#,
    #"{"type":"error","data":"Invalid subscription"}"#,
    #"{"type":"future","data":{"rate":1.25,"flags":[true,null]}}"#,
  ] {
    transport.socket.incoming.yield(.text(text))
  }
  #expect(try await iterator.next() == .message("Exchange notice"))
  #expect(try await iterator.next() == .serverError("Invalid subscription"))
  #expect(
    try await iterator.next()
      == .unknown(
        type: "future",
        data: .object([
          "rate": .number(Decimal(string: "1.25")!), "flags": .array([.bool(true), .null]),
        ])))
  transport.socket.incoming.yield(.binary(Data([0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 0, 1])))
  var ticks = quotes.makeAsyncIterator()
  #expect(try await ticks.next()?.instrumentToken == 408065)
  await ticker.disconnect()
  #expect(try await iterator.next() == nil)
}

@Test func quoteAndOrderSaturationAndCancellationAreIsolatedPerSubscriber() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let slowQuotes = try await ticker.marketTicks(bufferCapacity: 1)
  let slowOrders = try await ticker.orderUpdates(bufferCapacity: 1)
  let healthyOrders = try await ticker.orderUpdates(bufferCapacity: 1)
  let healthyQuotes = try await ticker.ticks(bufferCapacity: 1)
  let cancelled = try await ticker.orderUpdates(bufferCapacity: 1)
  let waiting = Task {
    var iterator = cancelled.makeAsyncIterator()
    return try await iterator.next()
  }
  waiting.cancel()
  #expect(try await waiting.value == nil)
  try await ticker.connect()
  var orders = healthyOrders.makeAsyncIterator()
  var quotes = healthyQuotes.makeAsyncIterator()
  for price: UInt8 in [1, 2, 3] {
    transport.socket.incoming.yield(.binary(Data([0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 0, price])))
    // The one-slot healthy quote buffer retains its quote despite intervening order traffic.
    transport.socket.incoming.yield(.text(orderUpdateFixture))
    #expect(try await orders.next()?.update.orderID == "220303000308932")
    #expect(try await quotes.next()?.lastPrice == Decimal(price) / 100)
  }
  var laggingQuotes = slowQuotes.makeAsyncIterator()
  #expect(try await laggingQuotes.next()?.lastPrice == Decimal(string: "0.01"))
  await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await laggingQuotes.next() }
  var laggingOrders = slowOrders.makeAsyncIterator()
  #expect(try await laggingOrders.next()?.update.status == .complete)
  await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await laggingOrders.next() }
  await ticker.disconnect()
  #expect(try await orders.next() == nil)
  #expect(try await quotes.next() == nil)
}

@Test func brokerOverflowLeavesOrdersAndHealthyBrokerSubscriberRunning() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let slow = try await ticker.brokerEvents(bufferCapacity: 1)
  let healthy = try await ticker.brokerEvents(bufferCapacity: 1)
  let orders = try await ticker.orderUpdates(bufferCapacity: 1)
  try await ticker.connect()
  var iterator = healthy.makeAsyncIterator()
  for _ in 0..<3 {
    transport.socket.incoming.yield(.text(#"{"type":"message","data":"notice"}"#))
    #expect(try await iterator.next() == .message("notice"))
  }
  transport.socket.incoming.yield(.text(orderUpdateFixture))
  var orderIterator = orders.makeAsyncIterator()
  #expect(try await orderIterator.next()?.update.status == .complete)
  var lagging = slow.makeAsyncIterator()
  #expect(try await lagging.next() == .message("notice"))
  await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await lagging.next() }
  await ticker.disconnect()
}

@Test(arguments: [
  "not json", "[]", "null", "{}", #"{"data":"notice"}"#,
  #"{"type":2,"data":"notice"}"#, #"{"type":"message"}"#,
  #"{"type":"message","data":null}"#, #"{"type":"error","data":{}}"#,
  #"{"type":"order","data":{}}"#, #"{"type":"future"}"#,
  orderUpdateFixture.replacingOccurrences(of: "\"quantity\": 1", with: "\"quantity\": \"bad\""),
  orderUpdateFixture.replacingOccurrences(of: "2022-03-03 09:24:25", with: "2022-02-30 09:24:25"),
]) func malformedTextFailsEveryStreamExplicitlyWithoutEmittingPartialEvents(text: String)
  async throws
{
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let orders = try await ticker.orderUpdates()
  let broker = try await ticker.brokerEvents()
  let rich = try await ticker.marketTicks()
  let ltp = try await ticker.ticks()
  try await ticker.connect()
  transport.socket.incoming.yield(.text(text))
  var o = orders.makeAsyncIterator()
  var b = broker.makeAsyncIterator()
  var r = rich.makeAsyncIterator()
  var l = ltp.makeAsyncIterator()
  await #expect(throws: KiteTickerError.malformedText) { _ = try await o.next() }
  await #expect(throws: KiteTickerError.malformedText) { _ = try await b.next() }
  await #expect(throws: KiteTickerError.malformedText) { _ = try await r.next() }
  await #expect(throws: KiteTickerError.malformedText) { _ = try await l.next() }
  await #expect(throws: KiteTickerError.notConnected) { try await ticker.subscribe([408065]) }
  await ticker.disconnect()
}

@Test func orderUpdatesPreserveUnknownValuesNullableFieldsAndConfiguredTimestampZone() async throws
{
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(
    apiKey: "key", accessToken: "token", transport: transport,
    tradingTimeZone: TimeZone(secondsFromGMT: 0)!)
  let updates = try await ticker.orderUpdates()
  try await ticker.connect()
  let text =
    orderUpdateFixture
    .replacingOccurrences(of: "COMPLETE", with: "FUTURE STATUS")
    .replacingOccurrences(of: "\"CNC\"", with: "\"FUTURE PRODUCT\"")
    .replacingOccurrences(of: "\"MARKET\"", with: "\"FUTURE TYPE\"")
    .replacingOccurrences(of: "\"NSE\"", with: "\"FUTURE EXCHANGE\"")
    .replacingOccurrences(of: "\"average_price\": 470", with: "\"average_price\": 470.123456789")
    .replacingOccurrences(
      of: "\"exchange_timestamp\": \"2022-03-03 09:24:25\"",
      with: "\"exchange_timestamp\": \"2022-03-03T09:24:25+05:30\"")
  transport.socket.incoming.yield(.text(text))
  var iterator = updates.makeAsyncIterator()
  let update = try #require(try await iterator.next()).update
  #expect(update.status == .unknown("FUTURE STATUS"))
  #expect(update.product == .unknown("FUTURE PRODUCT"))
  #expect(update.orderType == .unknown("FUTURE TYPE"))
  #expect(update.exchange == .unknown("FUTURE EXCHANGE"))
  #expect(update.averagePrice == Decimal(string: "470.123456789"))
  #expect(update.orderTimestamp == Date(timeIntervalSince1970: 1_646_299_465))
  #expect(update.exchangeTimestamp == Date(timeIntervalSince1970: 1_646_279_665))
  transport.socket.incoming.yield(
    .text(
      orderUpdateFixture.replacingOccurrences(
        of: "\"status\": \"COMPLETE\"", with: "\"status\": null")))
  #expect(try await iterator.next()?.update.status == nil)
  await ticker.disconnect()
}

@Test func textStreamsRejectNonPositiveBufferCapacities() async throws {
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: ControlledWebSocket())
  for capacity in [0, -1] {
    await #expect(throws: KiteTickerError.self) {
      _ = try await ticker.orderUpdates(bufferCapacity: capacity)
    }
    await #expect(throws: KiteTickerError.self) {
      _ = try await ticker.brokerEvents(bufferCapacity: capacity)
    }
  }
}

@Test(arguments: [
  orderUpdateFixture.replacingOccurrences(of: "220303000308932", with: ""),
  orderUpdateFixture.replacingOccurrences(of: "779521", with: "0"),
]) func structurallyInvalidOrderUpdateFailsTextStream(text: String) async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let orders = try await ticker.orderUpdates()
  try await ticker.connect()
  transport.socket.incoming.yield(.text(text))
  var iterator = orders.makeAsyncIterator()
  await #expect(throws: KiteTickerError.malformedText) { _ = try await iterator.next() }
  await ticker.disconnect()
}

@Test func socketUpdatesAllowAbsentPostbackMetadataAndUnknownAdditionalFields() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let updates = try await ticker.orderUpdates()
  try await ticker.connect()
  var envelope = try #require(
    try JSONSerialization.jsonObject(with: Data(orderUpdateFixture.utf8)) as? [String: Any])
  var payload = try #require(envelope["data"] as? [String: Any])
  for key in ["checksum", "app_id", "unfilled_quantity", "guid", "market_protection"] {
    payload.removeValue(forKey: key)
  }
  payload["future_field"] = ["nested": 42]
  payload["meta"] = "arbitrary broker metadata"
  payload["exchange_timestamp"] = NSNull()
  envelope["data"] = payload
  let text = String(decoding: try JSONSerialization.data(withJSONObject: envelope), as: UTF8.self)
  transport.socket.incoming.yield(.text(text))
  var iterator = updates.makeAsyncIterator()
  let event = try #require(try await iterator.next())
  let order = event.update
  #expect(order.orderID == "220303000308932")
  #expect(event.checksum == nil)
  #expect(event.appID == nil)
  #expect(order.unfilledQuantity == nil)
  #expect(order.exchangeTimestamp == nil)
  #expect(order.meta == .string("arbitrary broker metadata"))
  await ticker.disconnect()
}

@Test(arguments: [
  ("COMPLETE", KiteOrderStatus.complete), ("REJECTED", .rejected),
  ("CANCELLED", .cancelled), ("UPDATE", .update),
])
func documentedPostbackStatusesAreTyped(raw: String, expected: KiteOrderStatus) async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let updates = try await ticker.orderUpdates()
  try await ticker.connect()
  transport.socket.incoming.yield(
    .text(orderUpdateFixture.replacingOccurrences(of: "COMPLETE", with: raw)))
  var iterator = updates.makeAsyncIterator()
  #expect(try await iterator.next()?.update.status == expected)
  await ticker.disconnect()
}

@Test func binaryFailureAlsoTerminatesOrderAndBrokerStreams() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "key", accessToken: "token", transport: transport)
  let orders = try await ticker.orderUpdates()
  let broker = try await ticker.brokerEvents()
  try await ticker.connect()
  transport.socket.incoming.yield(.binary(Data()))
  var o = orders.makeAsyncIterator()
  var b = broker.makeAsyncIterator()
  await #expect(throws: KiteTickerError.malformedPacket) { _ = try await o.next() }
  await #expect(throws: KiteTickerError.malformedPacket) { _ = try await b.next() }
  await ticker.disconnect()
}
