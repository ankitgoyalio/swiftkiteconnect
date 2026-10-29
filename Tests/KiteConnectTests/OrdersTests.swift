//
//  OrdersTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

func orderClient(_ body: String = orderBookJSON, zone: String = "Asia/Kolkata") throws
    -> (KiteClient, ControlledHTTP)
{
    let transport = ControlledHTTP(body)
    let config = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 7,
        tradingTimeZone: TimeZone(identifier: zone)!,
    )
    return try (
        KiteClient(
            apiKey: "fixture-key", accessToken: "fixture-token",
            configuration: config, transport: transport,
        ), transport,
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
    #expect(history[7].instrumentToken == 779_521)
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
    #expect(trades[0].instrumentToken == 779_521)
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
                ]),
            ]),
    )
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
        } catch let KiteError.validation(field, _) { #expect(field == "orderID") }
    }
    #expect(await transport.requests.isEmpty)
}

func changingFirstRow(_ body: String, _ change: (inout [String: Any]) -> Void) throws
    -> String
{
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
    )
    var row = try #require((object["data"] as? [[String: Any]])?.first)
    change(&row)
    return try String(
        decoding: JSONSerialization.data(withJSONObject: [
            "status": "success", "data": [row], "future": true,
        ]), as: UTF8.self,
    )
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
    #expect(trade.instrumentToken == 779_521)
    #expect(trade.quantity == 3)
    #expect(trade.filled == 3)
    #expect(trade.exchangeOrderID == nil)
    let orderBody = try changingFirstRow(orderBookJSON) { $0["instrument_token"] = "412675" }
    let (ordersClient, _) = try orderClient(orderBody)
    #expect(try await ordersClient.orders().first?.instrumentToken == 412_675)
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
    } catch let KiteError.decoding(status, _) { #expect(status == 200) }
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
                of: #""average_price": 0,"#, with: #""average_price": 0.10000000000000000001,"#,
            )
            .replacingOccurrences(
                of: #""trigger_price": 0,"#, with: #""trigger_price": -0.00000000000000000001,"#,
            )
    let (client, _) = try orderClient(body)
    let order = try #require(try await client.orders().first)
    #expect(order.price == Decimal(string: "123.45000000000000000001"))
    #expect(order.averagePrice == Decimal(string: "0.10000000000000000001"))
    #expect(order.triggerPrice == Decimal(string: "-0.00000000000000000001"))
    let tradeBody = allTradesJSON.replacingOccurrences(of: "420.65", with: "420.65000000000000000001")
    let (tradeClient, _) = try orderClient(tradeBody)
    #expect(
        try await tradeClient.trades().first?.averagePrice
            == Decimal(string: "420.65000000000000000001"),
    )
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
            if null {
                $0[field] = NSNull()
            } else {
                $0.removeValue(forKey: field)
            }
        }
        let (client, _) = try orderClient(body)
        do {
            _ = try await client.orders()
            Issue.record("Missing/null required order field must fail: \(field)")
        } catch let KiteError.decoding(status, message) {
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
            if null {
                $0[field] = NSNull()
            } else {
                $0.removeValue(forKey: field)
            }
        }
        let (client, _) = try orderClient(body)
        do {
            _ = try await client.trades()
            Issue.record("Missing/null required trade field must fail: \(field)")
        } catch let KiteError.decoding(status, _) { #expect(status == 200) }
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
                if null {
                    $0[key] = NSNull()
                } else {
                    $0.removeValue(forKey: key)
                }
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
        order.orderTimestamp.timeIntervalSince1970 == (zone == "UTC" ? 1_622_452_737 : 1_622_432_937),
    )
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
