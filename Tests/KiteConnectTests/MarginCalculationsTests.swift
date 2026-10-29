//
//  MarginCalculationsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func calculationOrderMarginsUsesJSONAndReturnsDecimalBreakdown() async throws {
    let transport = ControlledHTTP(calculationMarginJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let margins = try await client.orderMargins([calculationOrder()])
    let margin = try #require(margins.first)
    #expect(margin.total == 1498)
    #expect(margin.charges.gst.igst == Decimal(string: "0.011372219999999999"))
    #expect(margin.charges.total == Decimal(string: "1.79255122"))
    #expect(margin.leverage == 1)
    #expect(margin.pnl.realised == 0)
    #expect(try margin.instrument == KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY"))
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

@Test(arguments: [false, true])
func calculationBasketReturnsSpreadBenefitAndPerOrderCharges(considerPositions: Bool) async throws {
    let transport = ControlledHTTP(calculationBasketJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let result = try await client.basketMargins(
        [calculationOrder(), calculationOrder()], considerPositions: considerPositions,
    )
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
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: orderTransport,
    )
    let orders = try await orderClient.compactOrderMargins([calculationOrder()])
    #expect(orders[0].total == 1498)
    #expect(orders[0].charges == nil)
    #expect(await orderTransport.requests.first?.url.query == "mode=compact")
    let basketTransport = ControlledHTTP(
        #"{"status":"success","data":{"initial":{"total":96504.975},"final":{"total":34786.725000000006}}}"#,
    )
    let basketClient = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: basketTransport,
    )
    let basket = try await basketClient.compactBasketMargins(
        [calculationOrder()], considerPositions: false,
    )
    #expect(basket.initial.total == Decimal(string: "96504.975"))
    #expect(basket.final.total == Decimal(string: "34786.725000000006"))
    #expect(basket.orders == nil)
    #expect(basket.charges == nil)
    #expect(
        await basketTransport.requests.first?.url.query == "consider_positions=false&mode=compact",
    )
    let extended = ControlledHTTP(calculationBasketJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: extended,
    )
    let retained = try await client.compactBasketMargins([calculationOrder()])
    #expect(retained.orders?.count == 2)
    #expect(retained.orders?[0].span == Decimal(string: "66832.5"))
    #expect(retained.charges?.brokerage == 40)
    #expect(retained.initial.type == "")
}

@Test func calculationChargesAcceptsImaginaryOrdersAndReturnsTaxBreakdown() async throws {
    let transport = ControlledHTTP(calculationChargesJSON)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let order = try KiteChargeOrder(
        orderID: "imaginary-1",
        instrument: KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "SBIN"),
        transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: 560,
    )
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
        try results[0].instrument == KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "SBIN"),
    )
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

@Test(arguments: CalculationOperation.allCases)
private func calculationFailuresAreSingleAttemptAndCancellationRecognizable(
    operation: CalculationOperation,
) async throws {
    for status in [401, 429, 503] {
        let transport = ControlledHTTP(
            #"{"status":"error","error_type":"FutureCalculationError","message":"Unavailable"}"#,
            status: status,
        )
        let client = try KiteClient(
            apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
        )
        do {
            try await operation.run(client)
            Issue.record("Expected API rejection")
        } catch let KiteError.api(error) {
            #expect(error.statusCode == status)
            #expect(error.errorType == "FutureCalculationError")
            #expect(error.message == "Unavailable")
        }
        #expect(await transport.requests.count == 1)
    }
    let failure = FailingHTTP()
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: failure,
    )
    do {
        try await operation.run(client)
        Issue.record("Expected transport error, not trading uncertainty")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    #expect(await failure.attempts == 1)
    let cancelled = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: CancelledHTTP(),
    )
    await #expect(throws: CancellationError.self) { try await operation.run(cancelled) }
    let transport = ControlledHTTP(operation.response)
    let preCancelled = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
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
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
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
        } catch let KiteError.validation(field, _) { #expect(field == "orders") }
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
        } catch let KiteError.validation(actual, _) { #expect(actual == field) }
    }
    for price in [Decimal.zero, -1, .nan] {
        let order = try KiteChargeOrder(
            orderID: "imaginary", instrument: calculationOrder().instrument,
            transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: price,
        )
        do {
            _ = try await client.orderCharges([order])
            Issue.record("Expected positive average-price validation")
        } catch let KiteError.validation(field, _) { #expect(field == "average_price") }
    }
    for id in ["", " ", "bad\nidentifier"] {
        let order = try KiteChargeOrder(
            orderID: id, instrument: calculationOrder().instrument,
            transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: 1,
        )
        do {
            _ = try await client.orderCharges([order])
            Issue.record("Expected order-ID validation")
        } catch let KiteError.validation(field, _) { #expect(field == "order_id") }
    }
    #expect(await transport.requests.isEmpty)
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
            rows[0], path: path.split(separator: ".").map(String.init), corruption: corruption,
        ),
    ]
    let data = try JSONSerialization.data(withJSONObject: envelope)
    let transport = ControlledHTTP(String(decoding: data, as: UTF8.self))
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        _ = try await client.orderMargins([calculationOrder()])
        Issue.record("Expected decoding failure")
    } catch let KiteError.decoding(status, message) {
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
                corruption: corruption,
            )
            let transport = try ControlledHTTP(
                String(decoding: JSONSerialization.data(withJSONObject: envelope), as: UTF8.self),
            )
            let client = try KiteClient(
                apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
            )
            do {
                _ = try await client.basketMargins([calculationOrder()])
                Issue.record("Expected malformed basket failure: \(path)")
            } catch let KiteError.decoding(status, _) { #expect(status == 200) }
        }
        for path in [
            "exchange", "tradingsymbol", "transaction_type", "variety", "product", "order_type",
            "quantity", "price", "charges",
        ] {
            var envelope =
                try JSONSerialization.jsonObject(with: Data(calculationChargesJSON.utf8)) as! [String: Any]
            let orders = envelope["data"] as! [[String: Any]]
            envelope["data"] = [corruptCalculation(orders[0], path: [path], corruption: corruption)]
            let transport = try ControlledHTTP(
                String(decoding: JSONSerialization.data(withJSONObject: envelope), as: UTF8.self),
            )
            let client = try KiteClient(
                apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
            )
            do {
                try await CalculationOperation.charges.run(client)
                Issue.record("Expected malformed charges failure: \(path)")
            } catch let KiteError.decoding(status, _) { #expect(status == 200) }
        }
    }
    for (operation, body) in [
        (CalculationOperation.orders, #"{"status":"success","data":[{"total":1}]}"#),
        (.compactOrders, #"{"status":"success","data":[{"total":null}]}"#),
        (.compactBasket, #"{"status":"success","data":{"initial":{"total":1},"final":{}}}"#),
        (.compactOrders, #"{"status":"success","data":[{"total":1,"span":"invalid"}]}"#),
    ] {
        let client = try KiteClient(
            apiKey: "key", accessToken: "token", configuration: .sandbox, transport: ControlledHTTP(body),
        )
        do {
            try await operation.run(client)
            Issue.record("Expected malformed shape failure")
        } catch let KiteError.decoding(status, _) { #expect(status == 200) }
    }
}

@Test func calculationPreservesUnknownValuesOptionalIDsAndDecimalInputs() async throws {
    let body =
        calculationChargesJSON
            .replacingOccurrences(
                of: #""transaction_type": "BUY""#,
                with:
                #""order_id":"imaginary-response", "future": {"new":true}, "transaction_type": "FUTURE_SIDE""#,
            )
            .replacingOccurrences(of: #""exchange": "NSE""#, with: #""exchange": "NEW_EXCHANGE""#)
            .replacingOccurrences(of: #""variety": "regular""#, with: #""variety": "future_variety""#)
            .replacingOccurrences(of: #""product": "CNC""#, with: #""product": "FUTURE_PRODUCT""#)
            .replacingOccurrences(of: #""order_type": "MARKET""#, with: #""order_type": "FUTURE_TYPE""#)
            .replacingOccurrences(
                of: #""transaction_tax_type": "stt""#, with: #""transaction_tax_type": "future_tax""#,
            )
    let transport = ControlledHTTP(body)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let order = try KiteChargeOrder(
        orderID: "imaginary", instrument: calculationOrder().instrument,
        transactionType: .sell, variety: .afterMarket, product: .mis, orderType: .limit,
        quantity: Int64.max, averagePrice: Decimal(string: "560.123456789012345678")!,
    )
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
            of: #""type": "equity""#, with: #""future":null, "type":"future_segment""#,
        ),
    )
    let marginsClient = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: marginTransport,
    )
    var description = try calculationOrder()
    description.orderType = .stopLoss
    description.price = Decimal(string: "1498.123456789012345678")!
    description.triggerPrice = Decimal(string: "1498.123456789012345679")!
    let margins = try await marginsClient.orderMargins([description])
    #expect(margins[0].type == "future_segment")
    let marginWire = try String(
        decoding: #require(await marginTransport.requests.first?.body), as: UTF8.self,
    )
    #expect(marginWire.contains("1498.123456789012345678"))
    #expect(marginWire.contains("1498.123456789012345679"))
}
