//
//  GTTResponseTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test(arguments: ["missing", "null"])
func gttExecutionCanLackOrderResult(mode: String) async throws {
    var envelope =
        try JSONSerialization.jsonObject(with: Data(gttDetailJSON().utf8)) as! [String: Any]
    var trigger = envelope["data"] as! [String: Any]
    var orders = trigger["orders"] as! [[String: Any]]
    var result = orders[1]["result"] as! [String: Any]
    if mode == "missing" {
        result.removeValue(forKey: "order_result")
    } else {
        result["order_result"] = NSNull()
    }
    orders[1]["result"] = result
    trigger["orders"] = orders
    envelope["data"] = trigger
    let transport = try ControlledHTTP(
        String(decoding: JSONSerialization.data(withJSONObject: envelope), as: UTF8.self),
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let decoded = try await client.gttTrigger(id: 123)
    #expect(decoded.orders[1].result != nil)
    #expect(decoded.orders[1].result?.orderResult == nil)
}

@Test(arguments: ["create", "modify", "delete"], [0, -1])
func gttUnusableMutationReceiptIsUncertainAndSentOnce(operation: String, identifier: Int)
    async throws
{
    let transport = ControlledHTTP("{\"status\":\"success\",\"data\":{\"trigger_id\":\(identifier)}}")
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    do {
        try await performGTTOperation(operation, client: client)
        Issue.record("Expected uncertain decoding for unusable trigger ID")
    } catch let KiteError.uncertainOutcome(.decoding(status, _)) {
        #expect(status == 200)
    }
    #expect(await transport.requests.count == 1)
}
