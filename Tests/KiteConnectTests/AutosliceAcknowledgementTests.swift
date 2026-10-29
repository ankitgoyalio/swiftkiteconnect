//
//  AutosliceAcknowledgementTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test(arguments: [200, 202])
func `empty autoslice acknowledgement requires reconciliation`(status: Int) async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":[]}"#, status: status)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var order = KiteOrderPlacement(
        tradingSymbol: "NIFTY", exchange: .nfo, transactionType: .buy,
        orderType: .market, quantity: 10000, product: .nrml,
    )
    order.autoslice = true
    do {
        _ = try await client.placeOrder(order)
        Issue.record("Expected uncertain decoding failure for an acknowledgement without slice outcomes")
    } catch let KiteError.uncertainOutcome(.decoding(receivedStatus, _)) {
        #expect(receivedStatus == status)
    }
    #expect(await transport.requests.count == 1)
}

@Test func `parent acknowledgement allows empty children`() async throws {
    let transport = ControlledHTTP(
        #"{"status":"success","data":{"order_id":"parent-1","children":[]}}"#,
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var order = KiteOrderPlacement(
        tradingSymbol: "NIFTY", exchange: .nfo, transactionType: .buy,
        orderType: .market, quantity: 10000, product: .nrml,
    )
    order.autoslice = true
    guard case let .order(receipt) = try await client.placeOrder(order) else {
        Issue.record("Expected parent receipt")
        return
    }
    #expect(receipt.orderID == "parent-1")
    #expect(receipt.children == [])
    #expect(await transport.requests.count == 1)
}

@Test(arguments: [false, true])
func `autoslice acknowledgement preserves uniform outcomes`(rejected: Bool) async throws {
    let data = rejected
        ? #"[{"error":{"code":400,"error_type":"MarginException","message":"Insufficient funds","data":null}}]"#
        : #"[{"order_id":"slice-1"},{"order_id":"slice-2"}]"#
    let transport = ControlledHTTP(#"{"status":"success","data":\#(data)}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var order = KiteOrderPlacement(
        tradingSymbol: "NIFTY", exchange: .nfo, transactionType: .buy,
        orderType: .market, quantity: 10000, product: .nrml,
    )
    order.autoslice = true
    guard case let .slices(slices) = try await client.placeOrder(order) else {
        Issue.record("Expected slice outcomes")
        return
    }
    if rejected {
        #expect(slices.count == 1)
        guard case let .rejected(error) = slices.first else {
            Issue.record("Expected slice rejection")
            return
        }
        #expect(error.code == 400)
        #expect(error.errorType == "MarginException")
        #expect(error.message == "Insufficient funds")
        #expect(error.data == .null)
    } else {
        #expect(slices.count == 2)
        let orderIDs = slices.compactMap { slice -> String? in
            guard case let .placed(receipt) = slice else { return nil }
            return receipt.orderID
        }
        #expect(orderIDs == ["slice-1", "slice-2"])
    }
    #expect(await transport.requests.count == 1)
}
