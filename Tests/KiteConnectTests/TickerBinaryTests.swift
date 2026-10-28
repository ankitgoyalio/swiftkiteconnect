import Foundation
import KiteConnect
import Testing

// Literal network-order fixtures transcribed from the stored protocol's byte table.
// No encoder under test produces these bytes. Decimal expectations are worked examples.
private func wire(_ hex: String) -> Data {
  let digits = hex.filter { !$0.isWhitespace }
  return Data(
    stride(from: 0, to: digits.count, by: 2).map {
      let start = digits.index(digits.startIndex, offsetBy: $0)
      return UInt8(digits[start..<digits.index(start, offsetBy: 2)], radix: 16)!
    })
}
private let quoteFrame = wire(
  """
  0001 002c
  00063a01 00003039 00000007 0000300c 0001e240 000003e8 000007d0
  00002ee0 000032c8 00002e7c 00002f44
  """)

@Test func quoteFieldsAndLegacyLTPAreDeliveredIndependently() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let rich = try await ticker.marketTicks()
  let legacy = try await ticker.ticks()
  try await ticker.connect()
  transport.socket.incoming.yield(.binary(quoteFrame))
  var iterator = rich.makeAsyncIterator()
  let tick = try #require(try await iterator.next())
  #expect(tick.instrumentToken == 408065)
  #expect(tick.lastPrice == Decimal(string: "123.45"))
  guard case .quote(let quote) = tick.details else {
    Issue.record("Expected quote")
    return
  }
  #expect(quote.lastTradedQuantity == 7)
  #expect(quote.averageTradedPrice == Decimal(string: "123.00"))
  #expect(quote.volumeTraded == 123456)
  #expect(quote.totalBuyQuantity == 1000)
  #expect(quote.totalSellQuantity == 2000)
  #expect(quote.ohlc.open == 120)
  #expect(quote.ohlc.high == 130)
  #expect(quote.ohlc.low == 119)
  #expect(quote.ohlc.close == 121)
  var ltp = legacy.makeAsyncIterator()
  #expect(try await ltp.next()?.lastPrice == Decimal(string: "123.45"))
  await ticker.disconnect()
  #expect(try await iterator.next() == nil)
}

private let fullFrame = wire(
  """
  0001 00b8
  00063a01 00003039 00000007 0000300c 0001e240 000003e8 000007d0
  00002ee0 000032c8 00002e7c 00002f44
  6553f100 000186a0 0001adb0 00015f90 6553f102
  0000000b 00003038 0001 aabb
  00000016 00003037 0100 ccdd
  00000021 00003036 0201 eeff
  0000002c 00003035 8000 1234
  ffffffff 00003034 ffff 5678
  00000042 0000303a 0006 abcd
  0000004d 0000303b 0007 abcd
  00000058 0000303c 0008 abcd
  00000063 0000303d 0009 abcd
  0000006f 0000303e 000a abcd
  """)

@Test func fullTickPreservesTimestampsOpenInterestAndEveryDepthLevel() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let stream = try await ticker.marketTicks()
  try await ticker.connect()
  transport.socket.incoming.yield(.binary(fullFrame))
  var iterator = stream.makeAsyncIterator()
  let tick = try #require(try await iterator.next())
  #expect(tick.instrumentToken == 408065)
  #expect(tick.lastPrice == Decimal(string: "123.45"))
  guard case .full(let full) = tick.details else {
    Issue.record("Expected full")
    return
  }
  #expect(full.quote.lastTradedQuantity == 7)
  #expect(full.quote.averageTradedPrice == 123)
  #expect(full.quote.volumeTraded == 123456)
  #expect(full.quote.totalBuyQuantity == 1000)
  #expect(full.quote.totalSellQuantity == 2000)
  #expect(full.quote.ohlc.open == 120)
  #expect(full.quote.ohlc.high == 130)
  #expect(full.quote.ohlc.low == 119)
  #expect(full.quote.ohlc.close == 121)
  #expect(full.lastTradeTime == Date(timeIntervalSince1970: 1_700_000_000))
  #expect(full.exchangeTimestamp == Date(timeIntervalSince1970: 1_700_000_002))
  #expect(full.openInterest == 100000)
  #expect(full.openInterestDayHigh == 110000)
  #expect(full.openInterestDayLow == 90000)
  #expect(full.depth.buy.map(\.quantity) == [11, 22, 33, 44, 4_294_967_295])
  #expect(
    full.depth.buy.map(\.price)
      == ["123.44", "123.43", "123.42", "123.41", "123.40"].map { Decimal(string: $0)! })
  #expect(full.depth.buy.map(\.orders) == [1, 256, 513, 32768, 65535])
  #expect(full.depth.sell.map(\.quantity) == [66, 77, 88, 99, 111])
  #expect(
    full.depth.sell.map(\.price)
      == ["123.46", "123.47", "123.48", "123.49", "123.50"].map { Decimal(string: $0)! })
  #expect(full.depth.sell.map(\.orders) == [6, 7, 8, 9, 10])
  await ticker.disconnect()
}

@Test func indexQuoteAndFullLayoutsRetainEveryFieldInMixedFrame() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let stream = try await ticker.marketTicks()
  try await ticker.connect()
  transport.socket.incoming.yield(
    .binary(
      wire(
        """
        0003
        0008 00000103 075bcd15
        001c 00000109 001e8480 001eab90 001e3660 001e5d70 001e8872 fffffc0e
        0020 00000209 001e8480 001eab90 001e3660 001e5d70 001e8872 fffffc0e 6553f102
        """)))
  var iterator = stream.makeAsyncIterator()
  let ltp = try #require(try await iterator.next())
  #expect(ltp.instrumentToken == 259)
  #expect(ltp.lastPrice == Decimal(string: "12.3456789"))
  #expect(ltp.details == .ltp)
  let quote = try #require(try await iterator.next())
  #expect(quote.instrumentToken == 265)
  #expect(quote.lastPrice == 20000)
  guard case .indexQuote(let fields) = quote.details else {
    Issue.record("Expected index quote")
    return
  }
  #expect(fields.ohlc.open == 19900)
  #expect(fields.ohlc.high == 20100)
  #expect(fields.ohlc.low == 19800)
  #expect(fields.ohlc.close == Decimal(string: "20010.10"))
  #expect(fields.priceChange == Decimal(string: "-10.10"))
  let full = try #require(try await iterator.next())
  #expect(full.instrumentToken == 521)
  #expect(full.lastPrice == 20000)
  guard case .indexFull(let fullFields, let timestamp) = full.details else {
    Issue.record("Expected index full")
    return
  }
  #expect(fullFields == fields)
  #expect(timestamp == Date(timeIntervalSince1970: 1_700_000_002))
  await ticker.disconnect()
}

@Test func explicitModesEncodeDocumentedCommandsAndDefaultRemainsLTP() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  await #expect(throws: KiteTickerError.notConnected) {
    try await ticker.setMode(.full, for: [408065])
  }
  try await ticker.connect()
  try await ticker.subscribe([408065], mode: .quote)
  try await ticker.setMode(.full, for: [408065])
  try await ticker.setMode(.ltp, for: [408065])
  try await ticker.subscribe([884737])
  let writes = try await transport.socket.sent().map {
    try JSONSerialization.jsonObject(with: Data($0.utf8)) as! NSDictionary
  }
  #expect(
    writes
      == [
        ["a": "subscribe", "v": [408065]],
        ["a": "mode", "v": ["quote", [408065]]],
        ["a": "mode", "v": ["full", [408065]]],
        ["a": "mode", "v": ["ltp", [408065]]],
        ["a": "subscribe", "v": [884737]],
        ["a": "mode", "v": ["ltp", [884737]]],
      ].map { $0 as NSDictionary })
  await #expect(throws: KiteTickerError.self) { try await ticker.setMode(.full, for: []) }
  await #expect(throws: KiteTickerError.self) { try await ticker.setMode(.full, for: [0]) }
  await #expect(throws: KiteTickerError.self) { try await ticker.setMode(.full, for: [999]) }
  #expect(await transport.socket.sent().count == 6)
  await ticker.disconnect()
}

@Test(arguments: [
  (UInt8(3), "0.0012345", "0.0012300", "0.0012000", "0.0012344"),
  (UInt8(6), "1.2345", "1.2300", "1.2000", "1.2344"),
  (UInt8(12), "1.2345", "1.2300", "1.2000", "1.2344"),
  (UInt8(250), "123.45", "123.00", "120.00", "123.44"),
]) func fullPricesUseSegmentScaleIncludingUnknownSegment(
  segment: UInt8, last: String, average: String, open: String, bid: String
) async throws {
  var frame = fullFrame
  frame[7] = segment  // Only the token's exchange byte differs; every field remains the known fixture.
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let stream = try await ticker.marketTicks()
  try await ticker.connect()
  transport.socket.incoming.yield(.binary(frame))
  var iterator = stream.makeAsyncIterator()
  let tick = try #require(try await iterator.next())
  #expect(tick.lastPrice == Decimal(string: last))
  guard case .full(let full) = tick.details else {
    Issue.record("Expected full")
    return
  }
  #expect(full.quote.averageTradedPrice == Decimal(string: average))
  #expect(full.quote.ohlc.open == Decimal(string: open))
  #expect(full.depth.buy.first?.price == Decimal(string: bid))
  #expect(full.lastTradeTime == Date(timeIntervalSince1970: 1_700_000_000))
  await ticker.disconnect()
}

// Exact length validation at every possible truncation, plus trailing bytes and unknown layouts.
private let malformedRichFrames: [Data] = {
  let index = wire(
    "0001 0020 00000109 001e8480 001eab90 001e3660 001e5d70 001e8872 fffffc0e 6553f102")
  let frames = [quoteFrame, fullFrame, index]
  var bad = frames.flatMap { frame in
    (2..<frame.count).map { Data(frame.prefix($0)) }
  }
  bad += [fullFrame + Data([0]), wire("0001 0009 00000101 00003039 00")]
  // A valid quote followed by malformed full must emit neither packet.
  var mixed = quoteFrame
  mixed[1] = 2
  mixed.append(contentsOf: wire("00b8 00063a01"))
  bad.append(mixed)
  return bad
}()

@Test(arguments: malformedRichFrames)
func malformedRichMessageFailsBothPublicStreamsAtomically(frame: Data) async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let rich = try await ticker.marketTicks()
  let legacy = try await ticker.ticks()
  try await ticker.connect()
  transport.socket.incoming.yield(.binary(frame))
  var r = rich.makeAsyncIterator()
  var l = legacy.makeAsyncIterator()
  await #expect(throws: KiteTickerError.self) { _ = try await r.next() }
  await #expect(throws: KiteTickerError.self) { _ = try await l.next() }
  await ticker.disconnect()
}

@Test func richSubscriberOverflowAndCancellationDoNotAffectOtherConsumers() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  await #expect(throws: KiteTickerError.self) {
    _ = try await ticker.marketTicks(bufferCapacity: 0)
  }
  let slow = try await ticker.marketTicks(bufferCapacity: 1)
  let healthy = try await ticker.marketTicks(bufferCapacity: 8)
  let cancelled = try await ticker.marketTicks(bufferCapacity: 1)
  let waiting = Task {
    var iterator = cancelled.makeAsyncIterator()
    return try await iterator.next()
  }
  waiting.cancel()
  #expect(try await waiting.value == nil)
  try await ticker.connect()
  var consumer = healthy.makeAsyncIterator()
  transport.socket.incoming.yield(.binary(quoteFrame))
  let first = try await consumer.next()
  transport.socket.incoming.yield(.binary(fullFrame))
  let second = try #require(try await consumer.next())
  guard case .full = second.details else {
    Issue.record("Expected full")
    return
  }
  var lagging = slow.makeAsyncIterator()
  #expect(try await lagging.next() == first)
  await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await lagging.next() }
  transport.socket.incoming.yield(.binary(quoteFrame))
  #expect(try await consumer.next() == first)
  await ticker.disconnect()
  #expect(try await consumer.next() == nil)
}

@Test func mixedFrameDeliversAllFiveLayoutsInOrderToEveryStream() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let a = try await ticker.marketTicks()
  let b = try await ticker.marketTicks()
  let legacy = try await ticker.ticks()
  try await ticker.connect()
  var frame = wire("0005 0008 00000101 00003039")
  frame.append(quoteFrame.dropFirst(2))
  frame.append(fullFrame.dropFirst(2))
  frame.append(wire("001c 00000109 001e8480 001eab90 001e3660 001e5d70 001e8872 fffffc0e"))
  frame.append(wire("0020 00000109 001e8480 001eab90 001e3660 001e5d70 001e8872 fffffc0e 00000000"))
  transport.socket.incoming.yield(.binary(Data([0])))
  transport.socket.incoming.yield(.binary(wire("0000")))  // empty packet list
  transport.socket.incoming.yield(.binary(frame))
  var ai = a.makeAsyncIterator()
  var bi = b.makeAsyncIterator()
  var li = legacy.makeAsyncIterator()
  for expectedPrice in ["123.45", "123.45", "123.45", "20000", "20000"] {
    let tick = try #require(try await ai.next())
    #expect(tick.lastPrice == Decimal(string: expectedPrice))
    #expect(try await bi.next() == tick)
    #expect(try await li.next()?.lastPrice == Decimal(string: expectedPrice))
  }
  await ticker.disconnect()
}

@Test func existingSubscribeFunctionReferenceRemainsSourceCompatible() async throws {
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let subscribe: @Sendable ([UInt32]) async throws -> Void = ticker.subscribe
  try await ticker.connect()
  try await subscribe([408065])
  #expect(await transport.socket.sent().count == 2)
  await ticker.disconnect()
}

@Test func modeChangeCannotOverlapAnUnfinishedSubscription() async throws {
  let transport = PausedWriteTransport()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  try await ticker.connect()
  let pending = Task { try await ticker.subscribe([408065], mode: .full) }
  var started = transport.socket.started.makeAsyncIterator()
  _ = await started.next()
  await #expect(throws: KiteTickerError.operationInProgress) {
    try await ticker.setMode(.quote, for: [408065])
  }
  transport.socket.resume.finish()
  try await pending.value
  try await ticker.setMode(.quote, for: [408065])
  await ticker.disconnect()
}

@Test func zeroAndUnsignedTimestampExtremesRemainUnixInstants() async throws {
  var frame = fullFrame
  frame.replaceSubrange(48..<52, with: [0, 0, 0, 0])
  frame.replaceSubrange(64..<68, with: [255, 255, 255, 255])
  let transport = ControlledWebSocket()
  let ticker = try KiteTicker(apiKey: "fixture", accessToken: "fixture", transport: transport)
  let stream = try await ticker.marketTicks()
  try await ticker.connect()
  transport.socket.incoming.yield(.binary(frame))
  var iterator = stream.makeAsyncIterator()
  let tick = try #require(try await iterator.next())
  guard case .full(let full) = tick.details else {
    Issue.record("Expected full")
    return
  }
  #expect(full.lastTradeTime == Date(timeIntervalSince1970: 0))
  #expect(full.exchangeTimestamp == Date(timeIntervalSince1970: 4_294_967_295))
  await ticker.disconnect()
}
