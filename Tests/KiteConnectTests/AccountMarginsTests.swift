import Foundation
import KiteConnect
import Testing

private let accountMarginsJSON = #"""
  {
      "status": "success",
      "data": {
        "equity": {
          "enabled": true,
          "net": 99725.05000000002,
          "available": {
            "adhoc_margin": 0,
            "cash": 245431.6,
            "opening_balance": 245431.6,
            "live_balance": 99725.05000000002,
            "collateral": 0,
            "intraday_payin": 0
          },
          "utilised": {
            "debits": 145706.55,
            "exposure": 38981.25,
            "m2m_realised": 761.7,
            "m2m_unrealised": 0,
            "option_premium": 0,
            "payout": 0,
            "span": 101989,
            "holding_sales": 0,
            "turnover": 0,
            "liquid_collateral": 0,
            "stock_collateral": 0,
            "delivery": 0
          }
        },
        "commodity": {
          "enabled": true,
          "net": 100661.7,
          "available": {
            "adhoc_margin": 0,
            "cash": 100661.7,
            "opening_balance": 100661.7,
            "live_balance": 100661.7,
            "collateral": 0,
            "intraday_payin": 0
          },
          "utilised": {
            "debits": 0,
            "exposure": 0,
            "m2m_realised": 0,
            "m2m_unrealised": 0,
            "option_premium": 0,
            "payout": 0,
            "span": 0,
            "holding_sales": 0,
            "turnover": 0,
            "liquid_collateral": 0,
            "stock_collateral": 0,
            "delivery": 0
          }
        }
      }
    }

  """#

@Test func accountMarginsReturnsBothCompleteFinancialSegments() async throws {
  let transport = ControlledHTTP(accountMarginsJSON)
  let client = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: transport)
  let margins = try await client.margins()
  #expect(margins.equity.enabled)
  #expect(margins.equity.net == Decimal(string: "99725.05000000002"))
  #expect(margins.equity.available.cash == Decimal(string: "245431.6"))
  #expect(margins.equity.available.openingBalance == Decimal(string: "245431.6"))
  #expect(margins.equity.available.liveBalance == Decimal(string: "99725.05000000002"))
  #expect(margins.equity.available.adhocMargin == 0)
  #expect(margins.equity.available.collateral == 0)
  #expect(margins.equity.available.intradayPayin == 0)
  #expect(margins.equity.utilised.debits == Decimal(string: "145706.55"))
  #expect(margins.equity.utilised.exposure == Decimal(string: "38981.25"))
  #expect(margins.equity.utilised.m2mRealised == Decimal(string: "761.7"))
  #expect(margins.equity.utilised.m2mUnrealised == 0)
  #expect(margins.equity.utilised.optionPremium == 0)
  #expect(margins.equity.utilised.payout == 0)
  #expect(margins.equity.utilised.span == 101989)
  #expect(margins.equity.utilised.holdingSales == 0)
  #expect(margins.equity.utilised.turnover == 0)
  #expect(margins.equity.utilised.liquidCollateral == 0)
  #expect(margins.equity.utilised.stockCollateral == 0)
  #expect(margins.equity.utilised.delivery == 0)
  #expect(margins.commodity.enabled)
  #expect(margins.commodity.net == Decimal(string: "100661.7"))
  #expect(margins.commodity.available.cash == Decimal(string: "100661.7"))
  let requests = await transport.requests
  #expect(requests.count == 1)
  #expect(requests[0].url.absoluteString == "https://sandbox.kite.trade/oms/user/margins")
  #expect(requests[0].method == .get)
  #expect(requests[0].body == nil)
  #expect(requests[0].headers["Authorization"] == "token fixture-key:fixture-token")
  #expect(requests[0].headers["X-Kite-Version"] == "3")
}

private func segmentEnvelope(_ segment: String) -> String {
  switch segment {
  case "equity":
    return #"""
      {"status":"success","data":{
          "enabled": true,
          "net": 99725.05000000002,
          "available": {
            "adhoc_margin": 0,
            "cash": 245431.6,
            "opening_balance": 245431.6,
            "live_balance": 99725.05000000002,
            "collateral": 0,
            "intraday_payin": 0
          },
          "utilised": {
            "debits": 145706.55,
            "exposure": 38981.25,
            "m2m_realised": 761.7,
            "m2m_unrealised": 0,
            "option_premium": 0,
            "payout": 0,
            "span": 101989,
            "holding_sales": 0,
            "turnover": 0,
            "liquid_collateral": 0,
            "stock_collateral": 0,
            "delivery": 0
          }
        }}
      """#
  case "commodity":
    return #"""
      {"status":"success","data":{
          "enabled": true,
          "net": 100661.7,
          "available": {
            "adhoc_margin": 0,
            "cash": 100661.7,
            "opening_balance": 100661.7,
            "live_balance": 100661.7,
            "collateral": 0,
            "intraday_payin": 0
          },
          "utilised": {
            "debits": 0,
            "exposure": 0,
            "m2m_realised": 0,
            "m2m_unrealised": 0,
            "option_premium": 0,
            "payout": 0,
            "span": 0,
            "holding_sales": 0,
            "turnover": 0,
            "liquid_collateral": 0,
            "stock_collateral": 0,
            "delivery": 0
          }
        }}
      """#
  default: preconditionFailure("Unsupported test fixture segment")
  }
}

@Test(arguments: [KiteMarginSegment.equity, .commodity])
func accountMarginsSelectsDocumentedSegment(segment: KiteMarginSegment) async throws {
  let transport = ControlledHTTP(segmentEnvelope(segment.rawValue))
  let client = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: transport)
  let margins = try await client.margins(segment: segment)
  #expect(margins.enabled)
  let expected = segment == .equity ? "99725.05000000002" : "100661.7"
  #expect(margins.net == Decimal(string: expected))
  let requests = await transport.requests
  #expect(requests.count == 1)
  #expect(requests[0].url.path == "/oms/user/margins/\(segment.rawValue)")
  #expect(requests[0].url.query == nil)
  #expect(requests[0].method == .get)
  #expect(requests[0].headers["Authorization"] == "token fixture-key:fixture-token")
  #expect(requests[0].headers["X-Kite-Version"] == "3")
  #expect(KiteMarginSegment(rawValue: "equity/../profile") == nil)
  #expect(KiteMarginSegment(rawValue: "EQUITY") == nil)
  #expect(KiteMarginSegment(rawValue: "") == nil)
}

@Test func accountMarginsToleratesExtraFieldsAndDisabledSegmentsWithoutInventingBalances()
  async throws
{
  let extended =
    accountMarginsJSON
    .replacingOccurrences(
      of: #""enabled": true"#, with: #""enabled": false, "future": {"x": [1,null]}"#
    )
    .replacingOccurrences(of: #""cash": 245431.6"#, with: #""cash": -0.01, "future_balance": 123"#)
    .replacingOccurrences(of: #""delivery": 0"#, with: #""delivery": 0, "future_charge": true"#)
    .replacingOccurrences(of: #""equity": {"#, with: #""future_segment": null, "equity": {"#)
  let client = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: ControlledHTTP(extended))
  let margins = try await client.margins()
  #expect(!margins.equity.enabled)
  #expect(!margins.commodity.enabled)
  #expect(margins.equity.available.cash == Decimal(string: "-0.01"))
  #expect(margins.equity.net == Decimal(string: "99725.05000000002"))
}

private let requiredMarginPaths = [
  "enabled", "net", "available", "utilised",
  "available.cash", "available.opening_balance", "available.live_balance",
  "available.intraday_payin", "available.adhoc_margin", "available.collateral",
  "utilised.m2m_unrealised", "utilised.m2m_realised", "utilised.debits", "utilised.span",
  "utilised.option_premium", "utilised.holding_sales", "utilised.exposure",
  "utilised.liquid_collateral", "utilised.delivery", "utilised.stock_collateral",
  "utilised.turnover", "utilised.payout",
]

@Test(arguments: requiredMarginPaths, ["missing", "null", "wrong-type"])
func accountMarginsRejectsMalformedRequiredData(path: String, corruption: String) async throws {
  var root =
    try JSONSerialization.jsonObject(with: Data(segmentEnvelope("equity").utf8)) as! [String: Any]
  var data = root["data"] as! [String: Any]
  let keys = path.split(separator: ".").map(String.init)
  let replacement: Any? =
    corruption == "missing" ? nil : (corruption == "null" ? NSNull() as Any : ["invalid"] as Any)
  if keys.count == 2 {
    var group = data[keys[0]] as! [String: Any]
    group[keys[1]] = replacement
    data[keys[0]] = group
  } else {
    data[keys[0]] = replacement
  }
  root["data"] = data
  let body = try JSONSerialization.data(withJSONObject: root)
  let transport = ControlledHTTP(String(decoding: body, as: UTF8.self))
  let client = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: transport)
  do {
    _ = try await client.margins(segment: .equity)
    Issue.record("Expected malformed required field to fail: \(path), \(corruption)")
  } catch KiteError.decoding(let status, let message) {
    #expect(status == 200)
    #expect(message.contains(keys.last!))
  }
  #expect(await transport.requests.count == 1)
}

@Test(arguments: ["equity", "commodity"])
func accountMarginsRequiresBothSegments(segment: String) async throws {
  for replacement in ["missing", "null"] {
    var root =
      try JSONSerialization.jsonObject(with: Data(accountMarginsJSON.utf8)) as! [String: Any]
    var data = root["data"] as! [String: Any]
    data[segment] = replacement == "missing" ? nil : NSNull()
    root["data"] = data
    let body = try JSONSerialization.data(withJSONObject: root)
    let client = try KiteClient(
      apiKey: "fixture-key", accessToken: "fixture-token",
      configuration: .sandbox, transport: ControlledHTTP(String(decoding: body, as: UTF8.self)))
    do {
      _ = try await client.margins()
      Issue.record("Expected missing or null segment to fail")
    } catch KiteError.decoding(let status, let message) {
      #expect(status == 200)
      #expect(message.contains(segment))
    }
  }
}

@Test(arguments: [false, true], [401, 429, 503])
func accountMarginsPreservesAPIFailuresWithoutRetry(singleSegment: Bool, status: Int) async throws {
  let transport = ControlledHTTP(
    #"{"status":"error","error_type":"FutureMarginException","message":"Unavailable"}"#,
    status: status)
  let client = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: transport)
  do {
    if singleSegment {
      _ = try await client.margins(segment: .commodity)
    } else {
      _ = try await client.margins()
    }
    Issue.record("Expected API rejection")
  } catch KiteError.api(let error) {
    #expect(error.statusCode == status)
    #expect(error.errorType == "FutureMarginException")
    #expect(error.message == "Unavailable")
  }
  #expect(await transport.requests.count == 1)
}

@Test func accountMarginsRetainsTransportAndCancellationErrors() async throws {
  let transport = FailingHTTP()
  let client = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: transport)
  do {
    _ = try await client.margins()
    Issue.record("Expected transport failure")
  } catch KiteError.transport(let code, _) { #expect(code == URLError.timedOut.rawValue) }
  #expect(await transport.attempts == 1)
  let cancelled = try KiteClient(
    apiKey: "fixture-key", accessToken: "fixture-token",
    configuration: .sandbox, transport: CancelledHTTP())
  await #expect(throws: CancellationError.self) { try await cancelled.margins(segment: .equity) }
}

@Test func accountMarginsUsesCurrentIsolatedSessionAndRequiresAuthentication() async throws {
  let transport = ControlledHTTP(accountMarginsJSON)
  let first = try KiteClient(
    apiKey: "first", accessToken: "old", configuration: .sandbox, transport: transport)
  let second = try KiteClient(
    apiKey: "second", accessToken: "other", configuration: .sandbox, transport: transport)
  async let a = first.margins()
  async let b = second.margins()
  _ = try await (a, b)
  try await first.replaceAccessToken("new")
  _ = try await first.margins()
  let requests = await transport.requests
  #expect(
    Set(requests.prefix(2).compactMap { $0.headers["Authorization"] }) == [
      "token first:old", "token second:other",
    ])
  #expect(requests.last?.headers["Authorization"] == "token first:new")
  try await first.replaceAccessToken(nil)
  do {
    _ = try await first.margins()
    Issue.record("Expected authentication validation")
  } catch KiteError.validation(let field, _) { #expect(field == "accessToken") }
  #expect(await transport.requests.count == 3)
}
