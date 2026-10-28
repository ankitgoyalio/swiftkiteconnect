import Foundation
import KiteConnect
import Testing

private let calculationMarginJSON = #"""
  {
    "status": "success",
    "data": [
      {
        "type": "equity",
        "tradingsymbol": "INFY",
        "exchange": "NSE",
        "span": 0,
        "exposure": 0,
        "option_premium": 0,
        "additional": 0,
        "bo": 0,
        "cash": 0,
        "var": 1498,
        "pnl": {
          "realised": 0,
          "unrealised": 0
        },
        "leverage": 1,
        "charges": {
          "transaction_tax": 1.498,
          "transaction_tax_type": "stt",
          "exchange_turnover_charge": 0.051681,
          "sebi_turnover_charge": 0.001498,
          "brokerage": 0.01,
          "stamp_duty": 0.22,
          "gst": {
            "igst": 0.011372219999999999,
            "cgst": 0,
            "sgst": 0,
            "total": 0.011372219999999999
          },
          "total": 1.79255122
        },
        "total": 1498
      }
    ]
  }
  """#

private func calculationOrder() throws -> KiteMarginOrder {
  KiteMarginOrder(
    instrument: try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY"),
    transactionType: .buy, variety: .regular, product: .cnc, orderType: .market, quantity: 1)
}

@Test func calculationOrderMarginsUsesJSONAndReturnsDecimalBreakdown() async throws {
  let transport = ControlledHTTP(calculationMarginJSON)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  let margins = try await client.orderMargins([calculationOrder()])
  let margin = try #require(margins.first)
  #expect(margin.total == 1498)
  #expect(margin.charges.gst.igst == Decimal(string: "0.011372219999999999"))
  #expect(margin.charges.total == Decimal(string: "1.79255122"))
  #expect(margin.leverage == 1)
  #expect(margin.pnl.realised == 0)
  #expect(margin.instrument == (try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")))
  let requests = await transport.requests
  #expect(requests.count == 1)
  let request = try #require(requests.first)
  #expect(request.method == .post)
  #expect(request.url.absoluteString == "https://sandbox.kite.trade/oms/margins/orders")
  #expect(request.headers["Content-Type"] == "application/json")
  #expect(request.headers["X-Kite-Version"] == "3")
  #expect(request.headers["Authorization"] == "token key:token")
  let body = try JSONSerialization.jsonObject(with: #require(request.body)) as! [[String: Any]]
  #expect(body.count == 1)
  #expect(body[0]["tradingsymbol"] as? String == "INFY")
  #expect(body[0]["price"] as? NSNumber == 0)
  #expect(body[0]["trigger_price"] as? NSNumber == 0)
  #expect(body[0]["quantity"] as? NSNumber == 1)
  #expect(body[0]["transaction_type"] as? String == "BUY")
  #expect(body[0]["variety"] as? String == "regular")
  #expect(body[0]["product"] as? String == "CNC")
  #expect(body[0]["order_type"] as? String == "MARKET")
  #expect(body[0]["exchange"] as? String == "NSE")
}

private let calculationBasketJSON = #"""
  {
    "status": "success",
    "data": {
      "initial": {
        "type": "",
        "tradingsymbol": "",
        "exchange": "",
        "span": 66832.5,
        "exposure": 29151.225000000002,
        "option_premium": 521.25,
        "additional": 0,
        "bo": 0,
        "cash": 0,
        "var": 0,
        "pnl": {
          "realised": 0,
          "unrealised": 0
        },
        "leverage": 0,
        "charges": {
          "transaction_tax": 0,
          "transaction_tax_type": "",
          "exchange_turnover_charge": 0,
          "sebi_turnover_charge": 0,
          "brokerage": 0,
          "stamp_duty": 0,
          "gst": {
            "igst": 0,
            "cgst": 0,
            "sgst": 0,
            "total": 0
          },
          "total": 0
        },
        "total": 96504.975
      },
      "final": {
        "type": "",
        "tradingsymbol": "",
        "exchange": "",
        "span": 7788.000000000007,
        "exposure": 29151.225000000002,
        "option_premium": -2152.5,
        "additional": 0,
        "bo": 0,
        "cash": 0,
        "var": 0,
        "pnl": {
          "realised": 0,
          "unrealised": 0
        },
        "leverage": 0,
        "charges": {
          "transaction_tax": 0,
          "transaction_tax_type": "",
          "exchange_turnover_charge": 0,
          "sebi_turnover_charge": 0,
          "brokerage": 0,
          "stamp_duty": 0,
          "gst": {
            "igst": 0,
            "cgst": 0,
            "sgst": 0,
            "total": 0
          },
          "total": 0
        },
        "total": 34786.725000000006
      },
      "orders": [
        {
          "type": "equity",
          "tradingsymbol": "NIFTY23JUL20600CE",
          "exchange": "NFO",
          "span": 66832.5,
          "exposure": 29151.225000000002,
          "option_premium": 0,
          "additional": 0,
          "bo": 0,
          "cash": 0,
          "var": 0,
          "pnl": {
            "realised": 0,
            "unrealised": 0
          },
          "leverage": 1,
          "charges": {
            "transaction_tax": 1.67109375,
            "transaction_tax_type": "stt",
            "exchange_turnover_charge": 1.336875,
            "sebi_turnover_charge": 0.00267375,
            "brokerage": 20,
            "stamp_duty": 0,
            "gst": {
              "igst": 3.8411187749999995,
              "cgst": 0,
              "sgst": 0,
              "total": 3.8411187749999995
            },
            "total": 26.851761274999998
          },
          "total": 95983.725
        },
        {
          "type": "equity",
          "tradingsymbol": "NIFTY23JUL20700CE",
          "exchange": "NFO",
          "span": 0,
          "exposure": 0,
          "option_premium": 521.25,
          "additional": 0,
          "bo": 0,
          "cash": 0,
          "var": 0,
          "pnl": {
            "realised": 0,
            "unrealised": 0
          },
          "leverage": 1,
          "charges": {
            "transaction_tax": 0,
            "transaction_tax_type": "stt",
            "exchange_turnover_charge": 0.260625,
            "sebi_turnover_charge": 0.00052125,
            "brokerage": 20,
            "stamp_duty": 0,
            "gst": {
              "igst": 3.6470063249999995,
              "cgst": 0,
              "sgst": 0,
              "total": 3.6470063249999995
            },
            "total": 23.908152575
          },
          "total": 521.25
        }
      ],
      "charges": {
        "transaction_tax": 0,
        "transaction_tax_type": "",
        "exchange_turnover_charge": 0,
        "sebi_turnover_charge": 0.003195,
        "brokerage": 40,
        "stamp_duty": 0,
        "gst": {
          "igst": 0,
          "cgst": 0,
          "sgst": 0,
          "total": 0
        },
        "total": 0
      }
    }
  }
  """#

@Test(arguments: [false, true])
func calculationBasketReturnsSpreadBenefitAndPerOrderCharges(considerPositions: Bool) async throws {
  let transport = ControlledHTTP(calculationBasketJSON)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  let result = try await client.basketMargins(
    [calculationOrder(), calculationOrder()], considerPositions: considerPositions)
  #expect(result.initial.total == Decimal(string: "96504.975"))
  #expect(result.final.total == Decimal(string: "34786.725000000006"))
  #expect(result.final.optionPremium == Decimal(string: "-2152.5"))
  #expect(result.initial.instrument == nil)
  #expect(result.orders.count == 2)
  #expect(result.orders[0].charges.total == Decimal(string: "26.851761274999998"))
  #expect(result.charges.brokerage == 40)
  let requests = await transport.requests
  #expect(requests.count == 1)
  #expect(requests[0].method == .post)
  #expect(requests[0].url.path == "/oms/margins/basket")
  #expect(requests[0].url.query == "consider_positions=\(considerPositions)")
  let body = try JSONSerialization.jsonObject(with: #require(requests[0].body)) as! [[String: Any]]
  #expect(body.count == 2)
}

@Test func calculationCompactMarginsAllowOnlyTotalsWithoutWeakeningFullResponses() async throws {
  let orderTransport = ControlledHTTP(#"{"status":"success","data":[{"total":1498}]}"#)
  let orderClient = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: orderTransport)
  let orders = try await orderClient.compactOrderMargins([calculationOrder()])
  #expect(orders[0].total == 1498)
  #expect(orders[0].charges == nil)
  #expect(await orderTransport.requests.first?.url.query == "mode=compact")
  let basketTransport = ControlledHTTP(
    #"{"status":"success","data":{"initial":{"total":96504.975},"final":{"total":34786.725000000006}}}"#
  )
  let basketClient = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: basketTransport)
  let basket = try await basketClient.compactBasketMargins(
    [calculationOrder()], considerPositions: false)
  #expect(basket.initial.total == Decimal(string: "96504.975"))
  #expect(basket.final.total == Decimal(string: "34786.725000000006"))
  #expect(basket.orders == nil)
  #expect(basket.charges == nil)
  #expect(
    await basketTransport.requests.first?.url.query == "consider_positions=false&mode=compact")
  let extended = ControlledHTTP(calculationBasketJSON)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: extended)
  let retained = try await client.compactBasketMargins([calculationOrder()])
  #expect(retained.orders?.count == 2)
  #expect(retained.orders?[0].span == Decimal(string: "66832.5"))
  #expect(retained.charges?.brokerage == 40)
  #expect(retained.initial.type == "")
}

private let calculationChargesJSON = #"""
  {
    "status": "success",
    "data": [
      {
        "transaction_type": "BUY",
        "tradingsymbol": "SBIN",
        "exchange": "NSE",
        "variety": "regular",
        "product": "CNC",
        "order_type": "MARKET",
        "quantity": 1,
        "price": 560,
        "charges": {
          "transaction_tax": 0.56,
          "transaction_tax_type": "stt",
          "exchange_turnover_charge": 0.01876,
          "sebi_turnover_charge": 0.00056,
          "brokerage": 0,
          "stamp_duty": 0,
          "gst": {
            "igst": 0.0033767999999999997,
            "cgst": 0,
            "sgst": 0,
            "total": 0.0033767999999999997
          },
          "total": 0.5826968
        }
      },
      {
        "transaction_type": "SELL",
        "tradingsymbol": "GOLDPETAL23JULFUT",
        "exchange": "MCX",
        "variety": "regular",
        "product": "NRML",
        "order_type": "LIMIT",
        "quantity": 1,
        "price": 5862,
        "charges": {
          "transaction_tax": 0.5862,
          "transaction_tax_type": "ctt",
          "exchange_turnover_charge": 0.152412,
          "sebi_turnover_charge": 0.005862,
          "brokerage": 1.7586,
          "stamp_duty": 0,
          "gst": {
            "igst": 0.34503732,
            "cgst": 0,
            "sgst": 0,
            "total": 0.34503732
          },
          "total": 2.84811132
        }
      },
      {
        "transaction_type": "BUY",
        "tradingsymbol": "NIFTY2371317900PE",
        "exchange": "NFO",
        "variety": "regular",
        "product": "NRML",
        "order_type": "LIMIT",
        "quantity": 100,
        "price": 1.5,
        "charges": {
          "transaction_tax": 0,
          "transaction_tax_type": "stt",
          "exchange_turnover_charge": 0.07575,
          "sebi_turnover_charge": 0.00015,
          "brokerage": 20,
          "stamp_duty": 0,
          "gst": {
            "igst": 3.613527,
            "cgst": 0,
            "sgst": 0,
            "total": 3.613527
          },
          "total": 23.689427000000002
        }
      }
    ]
  }
  """#

@Test func calculationChargesAcceptsImaginaryOrdersAndReturnsTaxBreakdown() async throws {
  let transport = ControlledHTTP(calculationChargesJSON)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  let order = KiteChargeOrder(
    orderID: "imaginary-1",
    instrument: try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "SBIN"),
    transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: 560)
  let results = try await client.orderCharges([order])
  #expect(results.count == 3)
  #expect(results[0].price == 560)
  #expect(results[0].orderID == nil)
  #expect(results[0].quantity == 1)
  #expect(results[0].transactionType == .buy)
  #expect(results[0].variety == .regular)
  #expect(results[0].product == .cnc)
  #expect(results[0].orderType == .market)
  #expect(
    results[0].instrument == (try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "SBIN")))
  #expect(results[1].charges.transactionTaxType == "ctt")
  #expect(results[1].charges.brokerage == Decimal(string: "1.7586"))
  #expect(results[2].charges.total == Decimal(string: "23.689427000000002"))
  let requests = await transport.requests
  #expect(requests.count == 1)
  let request = try #require(requests.first)
  #expect(request.url.path == "/oms/charges/orders")
  #expect(request.url.query == nil)
  #expect(request.method == .post)
  #expect(request.headers["Content-Type"] == "application/json")
  let body = try JSONSerialization.jsonObject(with: #require(request.body)) as! [[String: Any]]
  #expect(body[0]["order_id"] as? String == "imaginary-1")
  #expect(body[0]["average_price"] as? NSNumber == 560)
  #expect(body[0]["price"] == nil)
  #expect(body[0]["trigger_price"] == nil)
}

private enum CalculationOperation: CaseIterable, Sendable {
  case orders, basket, compactOrders, compactBasket, charges
  func run(_ client: KiteClient) async throws {
    switch self {
    case .orders: _ = try await client.orderMargins([calculationOrder()])
    case .basket: _ = try await client.basketMargins([calculationOrder()])
    case .compactOrders: _ = try await client.compactOrderMargins([calculationOrder()])
    case .compactBasket: _ = try await client.compactBasketMargins([calculationOrder()])
    case .charges:
      _ = try await client.orderCharges([
        KiteChargeOrder(
          orderID: "hypothetical", instrument: calculationOrder().instrument,
          transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: 560)
      ])
    }
  }
  var response: String {
    switch self {
    case .orders, .compactOrders: calculationMarginJSON
    case .basket, .compactBasket: calculationBasketJSON
    case .charges: calculationChargesJSON
    }
  }
}

@Test(arguments: CalculationOperation.allCases)
private func calculationFailuresAreSingleAttemptAndCancellationRecognizable(
  operation: CalculationOperation
) async throws {
  for status in [401, 429, 503] {
    let transport = ControlledHTTP(
      #"{"status":"error","error_type":"FutureCalculationError","message":"Unavailable"}"#,
      status: status)
    let client = try KiteClient(
      apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
    do {
      try await operation.run(client)
      Issue.record("Expected API rejection")
    } catch KiteError.api(let error) {
      #expect(error.statusCode == status)
      #expect(error.errorType == "FutureCalculationError")
      #expect(error.message == "Unavailable")
    }
    #expect(await transport.requests.count == 1)
  }
  let failure = FailingHTTP()
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: failure)
  do {
    try await operation.run(client)
    Issue.record("Expected transport error, not trading uncertainty")
  } catch KiteError.transport(let code, _) { #expect(code == URLError.timedOut.rawValue) }
  #expect(await failure.attempts == 1)
  let cancelled = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: CancelledHTTP())
  await #expect(throws: CancellationError.self) { try await operation.run(cancelled) }
  let transport = ControlledHTTP(operation.response)
  let preCancelled = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  let task = Task {
    withUnsafeCurrentTask { $0?.cancel() }
    try await operation.run(preCancelled)
  }
  await #expect(throws: CancellationError.self) { try await task.value }
  #expect(await transport.requests.isEmpty)
}

@Test func calculationValidationRejectsInvalidDescriptionsBeforeSending() async throws {
  let transport = ControlledHTTP()
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  for operation in CalculationOperation.allCases {
    do {
      switch operation {
      case .orders: _ = try await client.orderMargins([])
      case .basket: _ = try await client.basketMargins([])
      case .compactOrders: _ = try await client.compactOrderMargins([])
      case .compactBasket: _ = try await client.compactBasketMargins([])
      case .charges: _ = try await client.orderCharges([])
      }
      Issue.record("Expected empty-array validation")
    } catch KiteError.validation(let field, _) { #expect(field == "orders") }
  }
  for field in [
    "quantity", "price", "trigger_price", "transaction_type", "variety", "product", "order_type",
  ] {
    var order = try calculationOrder()
    switch field {
    case "quantity": order.quantity = 0
    case "price": order.price = -1
    case "trigger_price": order.triggerPrice = .nan
    case "transaction_type": order.transactionType = .unknown("")
    case "variety": order.variety = .unknown("\n")
    case "product": order.product = .unknown(" ")
    default: order.orderType = .unknown("LIMIT\u{0}")
    }
    do {
      _ = try await client.orderMargins([order])
      Issue.record("Expected invalid field validation")
    } catch KiteError.validation(let actual, _) { #expect(actual == field) }
  }
  for price in [Decimal.zero, -1, .nan] {
    let order = KiteChargeOrder(
      orderID: "imaginary", instrument: try calculationOrder().instrument,
      transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: price)
    do {
      _ = try await client.orderCharges([order])
      Issue.record("Expected positive average-price validation")
    } catch KiteError.validation(let field, _) { #expect(field == "average_price") }
  }
  for id in ["", " ", "bad\nidentifier"] {
    let order = KiteChargeOrder(
      orderID: id, instrument: try calculationOrder().instrument,
      transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: 1)
    do {
      _ = try await client.orderCharges([order])
      Issue.record("Expected order-ID validation")
    } catch KiteError.validation(let field, _) { #expect(field == "order_id") }
  }
  #expect(await transport.requests.isEmpty)
}

private let requiredCalculationPaths = [
  "type", "exchange", "tradingsymbol", "span", "exposure", "option_premium", "additional",
  "bo", "cash", "var", "pnl", "pnl.realised", "pnl.unrealised", "leverage", "total", "charges",
  "charges.transaction_tax", "charges.transaction_tax_type", "charges.exchange_turnover_charge",
  "charges.sebi_turnover_charge", "charges.brokerage", "charges.stamp_duty", "charges.total",
  "charges.gst", "charges.gst.igst", "charges.gst.cgst", "charges.gst.sgst", "charges.gst.total",
]

private func corruptCalculation(_ object: [String: Any], path: [String], corruption: String)
  -> [String: Any]
{
  var result = object
  let key = path[0]
  if path.count > 1 {
    result[key] = corruptCalculation(
      result[key] as! [String: Any], path: Array(path.dropFirst()), corruption: corruption)
  } else {
    switch corruption {
    case "missing": result.removeValue(forKey: key)
    case "null": result[key] = NSNull()
    default: result[key] = ["invalid"]
    }
  }
  return result
}

@Test(arguments: requiredCalculationPaths, ["missing", "null", "wrong-type"])
func calculationFullMarginsRejectMalformedRequiredBreakdown(path: String, corruption: String)
  async throws
{
  var envelope =
    try JSONSerialization.jsonObject(with: Data(calculationMarginJSON.utf8)) as! [String: Any]
  let rows = envelope["data"] as! [[String: Any]]
  envelope["data"] = [
    corruptCalculation(
      rows[0], path: path.split(separator: ".").map(String.init), corruption: corruption)
  ]
  let data = try JSONSerialization.data(withJSONObject: envelope)
  let transport = ControlledHTTP(String(decoding: data, as: UTF8.self))
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  do {
    _ = try await client.orderMargins([calculationOrder()])
    Issue.record("Expected decoding failure")
  } catch KiteError.decoding(let status, let message) {
    #expect(status == 200)
    #expect(message.contains(path.split(separator: ".").last!))
  }
  #expect(await transport.requests.count == 1)
}

@Test func calculationBasketAndChargeShapesRequireTheirDocumentedData() async throws {
  for corruption in ["missing", "null", "wrong-type"] {
    for path in ["initial", "final", "orders", "charges", "initial.total", "final.total"] {
      var envelope =
        try JSONSerialization.jsonObject(with: Data(calculationBasketJSON.utf8)) as! [String: Any]
      envelope["data"] = corruptCalculation(
        envelope["data"] as! [String: Any], path: path.split(separator: ".").map(String.init),
        corruption: corruption)
      let transport = ControlledHTTP(
        String(decoding: try JSONSerialization.data(withJSONObject: envelope), as: UTF8.self))
      let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
      do {
        _ = try await client.basketMargins([calculationOrder()])
        Issue.record("Expected malformed basket failure: \(path)")
      } catch KiteError.decoding(let status, _) { #expect(status == 200) }
    }
    for path in [
      "exchange", "tradingsymbol", "transaction_type", "variety", "product", "order_type",
      "quantity", "price", "charges",
    ] {
      var envelope =
        try JSONSerialization.jsonObject(with: Data(calculationChargesJSON.utf8)) as! [String: Any]
      let orders = envelope["data"] as! [[String: Any]]
      envelope["data"] = [corruptCalculation(orders[0], path: [path], corruption: corruption)]
      let transport = ControlledHTTP(
        String(decoding: try JSONSerialization.data(withJSONObject: envelope), as: UTF8.self))
      let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
      do {
        try await CalculationOperation.charges.run(client)
        Issue.record("Expected malformed charges failure: \(path)")
      } catch KiteError.decoding(let status, _) { #expect(status == 200) }
    }
  }
  for (operation, body) in [
    (CalculationOperation.orders, #"{"status":"success","data":[{"total":1}]}"#),
    (.compactOrders, #"{"status":"success","data":[{"total":null}]}"#),
    (.compactBasket, #"{"status":"success","data":{"initial":{"total":1},"final":{}}}"#),
    (.compactOrders, #"{"status":"success","data":[{"total":1,"span":"invalid"}]}"#),
  ] {
    let client = try KiteClient(
      apiKey: "key", accessToken: "token", configuration: .sandbox, transport: ControlledHTTP(body))
    do {
      try await operation.run(client)
      Issue.record("Expected malformed shape failure")
    } catch KiteError.decoding(let status, _) { #expect(status == 200) }
  }
}

@Test func calculationPreservesUnknownValuesOptionalIDsAndDecimalInputs() async throws {
  let body =
    calculationChargesJSON
    .replacingOccurrences(
      of: #""transaction_type": "BUY""#,
      with:
        #""order_id":"imaginary-response", "future": {"new":true}, "transaction_type": "FUTURE_SIDE""#
    )
    .replacingOccurrences(of: #""exchange": "NSE""#, with: #""exchange": "NEW_EXCHANGE""#)
    .replacingOccurrences(of: #""variety": "regular""#, with: #""variety": "future_variety""#)
    .replacingOccurrences(of: #""product": "CNC""#, with: #""product": "FUTURE_PRODUCT""#)
    .replacingOccurrences(of: #""order_type": "MARKET""#, with: #""order_type": "FUTURE_TYPE""#)
    .replacingOccurrences(
      of: #""transaction_tax_type": "stt""#, with: #""transaction_tax_type": "future_tax""#)
  let transport = ControlledHTTP(body)
  let client = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport)
  let order = KiteChargeOrder(
    orderID: "imaginary", instrument: try calculationOrder().instrument,
    transactionType: .sell, variety: .afterMarket, product: .mis, orderType: .limit,
    quantity: Int64.max, averagePrice: Decimal(string: "560.123456789012345678")!)
  let result = try await client.orderCharges([order])
  #expect(result[0].orderID == "imaginary-response")
  #expect(result[0].exchange == .unknown("NEW_EXCHANGE"))
  #expect(result[0].transactionType == .unknown("FUTURE_SIDE"))
  #expect(result[0].variety == .unknown("future_variety"))
  #expect(result[0].product == .unknown("FUTURE_PRODUCT"))
  #expect(result[0].orderType == .unknown("FUTURE_TYPE"))
  #expect(result[0].charges.transactionTaxType == "future_tax")
  let wire = try #require(await transport.requests.first?.body)
  let string = String(decoding: wire, as: UTF8.self)
  #expect(string.contains("560.123456789012345678"))
  #expect(string.contains("9223372036854775807"))
  let dictionary = try JSONSerialization.jsonObject(with: wire) as! [[String: Any]]
  #expect(dictionary[0]["transaction_type"] as? String == "SELL")
  #expect(dictionary[0]["variety"] as? String == "amo")
  #expect(dictionary[0]["product"] as? String == "MIS")
  #expect(dictionary[0]["order_type"] as? String == "LIMIT")

  let marginTransport = ControlledHTTP(
    calculationMarginJSON.replacingOccurrences(
      of: #""type": "equity""#, with: #""future":null, "type":"future_segment""#))
  let marginsClient = try KiteClient(
    apiKey: "key", accessToken: "token", configuration: .sandbox, transport: marginTransport)
  var description = try calculationOrder()
  description.orderType = .stopLoss
  description.price = Decimal(string: "1498.123456789012345678")!
  description.triggerPrice = Decimal(string: "1498.123456789012345679")!
  let margins = try await marginsClient.orderMargins([description])
  #expect(margins[0].type == "future_segment")
  let marginWire = String(
    decoding: try #require(await marginTransport.requests.first?.body), as: UTF8.self)
  #expect(marginWire.contains("1498.123456789012345678"))
  #expect(marginWire.contains("1498.123456789012345679"))
}

@Test(arguments: CalculationOperation.allCases)
private func calculationSessionsRemainIsolatedAndRequireCurrentAuthentication(
  operation: CalculationOperation
) async throws {
  let transport = ControlledHTTP(operation.response)
  let configuration = try KiteConfiguration(
    baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 9)
  let first = try KiteClient(
    apiKey: "one", accessToken: "old", configuration: configuration, transport: transport)
  let second = try KiteClient(
    apiKey: "two", accessToken: "other", configuration: configuration, transport: transport)
  async let a: Void = operation.run(first)
  async let b: Void = operation.run(second)
  _ = try await (a, b)
  try await first.replaceAccessToken("new")
  try await operation.run(first)
  let requests = await transport.requests
  #expect(
    Set(requests.prefix(2).compactMap { $0.headers["Authorization"] }) == [
      "token one:old", "token two:other",
    ])
  #expect(requests.last?.headers["Authorization"] == "token one:new")
  #expect(
    requests.allSatisfy {
      $0.timeout == 9 && $0.headers["X-Kite-Version"] == "3"
        && $0.headers["Content-Type"] == "application/json"
    })
  try await first.replaceAccessToken(nil)
  do {
    try await operation.run(first)
    Issue.record("Expected missing-session validation")
  } catch KiteError.validation(let field, _) { #expect(field == "accessToken") }
  #expect(await transport.requests.count == 3)
}
