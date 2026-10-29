//
//  OrderMutationOptionsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func orderMutationModificationValidatesOnlySuppliedStructure() async throws {
    let transport = ControlledHTTP(mutationReceipt)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
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
        } catch let KiteError.validation(actual, _) { #expect(actual == field) }
    }
    do {
        _ = try await client.cancelOrder(orderID: "1", variety: .co, parentOrderID: "")
        Issue.record("Expected parent validation")
    } catch let KiteError.validation(field, _) { #expect(field == "parent_order_id") }
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
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
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
        """#,
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var order = limitPlacement()
    order.validity = .ioc
    order.autoslice = true
    let result = try await client.placeOrder(order)
    guard case let .order(receipt) = result else {
        Issue.record("Expected parent receipt")
        return
    }
    let children = try #require(receipt.children)
    #expect(children.count == 4)
    guard case let .rejected(error) = children[2] else {
        Issue.record("Expected slice rejection")
        return
    }
    #expect(error.data == .null)
    #expect(error.errorType == "MarginException")
    #expect(error.code == 400)
}

@Test(arguments: KiteOrderMutationVariety.allCases)
func orderMutationRoutesModificationAndCancellationForEveryVariety(
    variety: KiteOrderMutationVariety,
) async throws {
    let transport = ControlledHTTP(mutationReceipt)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    var change = KiteOrderModification()
    change.quantity = 1
    _ = try await client.modifyOrder(orderID: "151220000000000", variety: variety, changes: change)
    _ = try await client.cancelOrder(orderID: "151220000000000", variety: variety)
    let requests = await transport.requests
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.url.path == "/oms/orders/\(variety.rawValue)/151220000000000" })
    #expect(requests.map(\.method) == [.put, .delete])
}
