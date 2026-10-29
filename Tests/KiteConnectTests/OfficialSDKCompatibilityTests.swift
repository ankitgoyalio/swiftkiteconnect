//
//  OfficialSDKCompatibilityTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

private func officialFixture(_ name: String) throws -> String {
    let url = try #require(Bundle.module.url(
        forResource: name, withExtension: "json", subdirectory: "Fixtures/OfficialPHP",
    ))
    return try String(contentsOf: url, encoding: .utf8)
}

@Test func `official SDK profile retains upstream identity`() async throws {
    let transport = try ControlledHTTP(officialFixture("profile"))
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    let profile = try await client.profile()
    #expect(profile.userID == "AB1234")
    #expect(await transport.requests.first?.url.path == "/user/profile")
}

@Test(arguments: ["margins", "margins_equity", "margin_commodity", "orders", "order_info", "trades", "order_trades", "gtt_get_order", "gtt_get_orders", "holdings", "positions", "auctions_list", "mf_orders", "mf_orders_info", "mf_sips", "mf_holdings", "quote", "ohlc", "ltp", "historical_minute", "historical_oi", "order_margins", "basket_margins", "virtual_contract_note", "alerts_get", "alerts_get_one", "alerts_history"])
func `official SDK responses preserve typed values`(fixture: String) async throws {
    let transport = try ControlledHTTP(officialFixture(fixture))
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    let instrument = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
    let order = KiteMarginOrder(instrument: instrument, transactionType: .buy, product: .cnc, orderType: .market, quantity: 1)
    let from = Date(timeIntervalSince1970: 1_513_308_300)
    let to = Date(timeIntervalSince1970: 1_600_000_000)
    let path: String
    switch fixture {
    case "margins":
        #expect(try await (client.margins()).equity.net == Decimal(string: "99725.05000000002"))
        path = "/user/margins"
    case "margins_equity":
        #expect(try await (client.margins(segment: .equity)).available.cash == Decimal(string: "245431.6"))
        path = "/user/margins/equity"
    case "margin_commodity":
        #expect(try await (client.margins(segment: .commodity)).net == Decimal(string: "96426.33"))
        path = "/user/margins/commodity"
    case "orders":
        #expect(try await (client.orders()).first?.orderID == "100000000000000")
        path = "/orders"
    case "order_info":
        #expect(try await (client.orderHistory(orderID: "example")).first?.orderID == "171229000724687")
        path = "/orders/example"
    case "trades":
        #expect(try await (client.trades()).first?.averagePrice == Decimal(string: "420.65"))
        path = "/trades"
    case "order_trades":
        #expect(try await (client.orderTrades(orderID: "example")).first?.averagePrice == 4852)
        path = "/orders/example/trades"
    case "gtt_get_order":
        #expect(try await (client.gttTrigger(id: 123)).id == 123)
        path = "/gtt/triggers/123"
    case "gtt_get_orders":
        #expect(try await (client.gttTriggers()).first?.id == 112_127)
        path = "/gtt/triggers"
    case "holdings":
        #expect(try await (client.holdings()).first?.tradingSymbol == "AARON")
        path = "/portfolio/holdings"
    case "positions":
        #expect(try await (client.positions()).net.first?.quantity == 1)
        path = "/portfolio/positions"
    case "auctions_list":
        #expect(try await (client.auctionHoldings()).first?.holding.tradingSymbol == "ASHOKLEY")
        path = "/portfolio/holdings/auctions"
    case "mf_orders":
        #expect(try await (client.mutualFundOrders()).first?.orderID == "271989e0-a64e-4cf3-b4e4-afb8f38dd203")
        path = "/mf/orders"
    case "mf_orders_info":
        #expect(try await (client.mutualFundOrder(orderID: "example")).amount == 5000)
        path = "/mf/orders/example"
    case "mf_sips":
        #expect(try await (client.mutualFundSIPs()).first?.instalmentAmount == 500)
        path = "/mf/sips"
    case "mf_holdings":
        #expect(try await (client.mutualFundHoldings()).first?.quantity == Decimal(string: "382.488"))
        path = "/mf/holdings"
    case "quote":
        #expect(try await (client.quotes(instruments: [instrument]))[instrument]?.lastPrice == Decimal(string: "1412.95"))
        path = "/quote"
    case "ohlc":
        #expect(try await (client.ohlc(instruments: [instrument]))[instrument]?.ohlc.open == Decimal(string: "1085.8"))
        path = "/quote/ohlc"
    case "ltp":
        #expect(try await (client.ltp(instruments: [instrument]))[instrument]?.lastPrice == Decimal(string: "1074.35"))
        path = "/quote/ltp"
    case "historical_minute":
        #expect(try await (client.historicalCandles(instrumentToken: 5633, interval: .minute, from: from, to: to)).first?.volume == 2499)
        path = "/instruments/historical/5633/minute"
    case "historical_oi":
        #expect(try await (client.historicalCandles(instrumentToken: 5633, interval: .minute, from: from, to: to, oi: true)).first?.openInterest == 13_667_775)
        path = "/instruments/historical/5633/minute"
    case "order_margins":
        #expect(try await (client.orderMargins([order])).first?.total == 1498)
        path = "/margins/orders"
    case "basket_margins":
        #expect(try await (client.basketMargins([order])).initial.span == Decimal(string: "66832.5"))
        path = "/margins/basket"
    case "virtual_contract_note":
        #expect(try await (client.orderCharges([KiteChargeOrder(orderID: "example", instrument: instrument, transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: 560)])).first?.charges.transactionTax == Decimal(string: "0.56"))
        path = "/charges/orders"
    case "alerts_get":
        #expect(try await (client.alerts()).first?.uuid == "550e8400-e29b-41d4-a716-446655440000")
        path = "/alerts"
    case "alerts_get_one":
        #expect(try await (client.alert(uuid: "example")).uuid == "550e8400-e29b-41d4-a716-446655440000")
        path = "/alerts/example"
    case "alerts_history":
        #expect(try await (client.alertHistory(uuid: "example")).first?.uuid == "550e8400-e29b-41d4-a716-446655440000")
        path = "/alerts/example/history"
    default: Issue.record("Unmapped official fixture"); return
    }
    let requests = await transport.requests
    #expect(requests.count == 1)
    #expect(requests.first?.url.path == path)
    let method: KiteHTTPMethod = ["order_margins", "basket_margins", "virtual_contract_note"].contains(fixture) ? .post : .get
    #expect(requests.first?.method == method)
    #expect(requests.first?.headers["Authorization"] == "token key:token")
}

@Test func `official SDK auto slice retains accepted and rejected outcomes`() async throws {
    let transport = try ControlledHTTP(officialFixture("autoslice_response"))
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    var order = KiteOrderPlacement(tradingSymbol: "INFY", exchange: .nse, transactionType: .buy, orderType: .market, quantity: 10000, product: .cnc)
    order.autoslice = true
    guard case let .slices(slices) = try await client.placeOrder(order) else {
        Issue.record("Expected official slice array"); return
    }
    #expect(slices.count == 5)
    guard case let .placed(receipt) = slices[0], case let .rejected(rejection) = slices[3] else {
        Issue.record("Expected accepted and rejected slices"); return
    }
    #expect(receipt.orderID == "1914227164488687616")
    #expect(rejection.code == 400)
    #expect(rejection.errorType == "MarginException")
    #expect(rejection.data == .null)
    #expect(await transport.requests.count == 1)
}

/// Adaptations of the pinned response exercise supported envelopes. The upstream
/// resource remains byte-for-byte intact; these are not separate upstream fixtures.
@Test(arguments: ["parent", "empty-children", "rejections", "ordinary"])
func `official SDK slice values survive supported envelopes`(shape: String) async throws {
    let bytes = try Data(officialFixture("autoslice_response").utf8)
    var envelope = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let slices = try #require(envelope["data"] as? [[String: Any]])
    switch shape {
    case "parent": envelope["data"] = ["order_id": "parent", "children": slices]
    case "empty-children": envelope["data"] = ["order_id": "parent", "children": []]
    case "ordinary": envelope["data"] = slices[0]
    default: envelope["data"] = [slices[3]]
    }
    let body = try JSONSerialization.data(withJSONObject: envelope)
    let transport = ControlledHTTP(String(decoding: body, as: UTF8.self))
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    let order = KiteOrderPlacement(tradingSymbol: "INFY", exchange: .nse,
                                   transactionType: .buy, orderType: .market, quantity: 1, product: .cnc)
    let result = try await client.placeOrder(order)
    switch (shape, result) {
    case let ("parent", .order(receipt)):
        #expect(receipt.orderID == "parent")
        #expect(receipt.children?.count == 5)
    case let ("empty-children", .order(receipt)):
        #expect(receipt.orderID == "parent")
        #expect(receipt.children == [])
    case let ("ordinary", .order(receipt)):
        #expect(receipt.orderID == "1914227164488687616")
        #expect(receipt.children == nil)
    case let ("rejections", .slices(results)):
        #expect(results.count == 1)
        guard case let .rejected(rejection) = results[0] else {
            Issue.record("Expected rejection-only result"); return
        }
        #expect(rejection.errorType == "MarginException")
    default: Issue.record("Supported acknowledgement shape changed")
    }
    #expect(await transport.requests.count == 1)
}
