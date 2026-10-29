//
//  SandboxSafetyTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func `sandbox attempt survives acknowledgement and blocks another placement`() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("attempt")
    let attempt = try SandboxOrderAttempt(url: url, tag: "offline-tag")
    let initial = try Data(contentsOf: url)
    #expect(throws: (any Error).self) { try SandboxOrderAttempt(url: url, tag: "retry") }
    #expect(try Data(contentsOf: url) == initial)
    try attempt.acknowledge(orderID: "offline-order")
    let receipt = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String])
    #expect(receipt == ["tag": "offline-tag", "order_id": "offline-order", "state": "acknowledged"])
    #expect(throws: (any Error).self) { try SandboxOrderAttempt(url: url, tag: "retry") }
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func `sandbox attempt refuses symlinks without modifying their targets`() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let target = directory.appendingPathComponent("target")
    let link = directory.appendingPathComponent("attempt")
    try Data("unchanged".utf8).write(to: target)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    #expect(throws: (any Error).self) { try SandboxOrderAttempt(url: link, tag: "offline") }
    #expect(try Data(contentsOf: target) == Data("unchanged".utf8))
}

@Test func `sandbox reports omit credential bearing error diagnostics`() {
    let secret = "private-access-token"
    let errors: [any Error] = [
        KiteError.transport(code: nil, message: secret),
        KiteError.decoding(statusCode: 200, message: secret),
        KiteError.uncertainOutcome(.transport(code: nil, message: secret)),
        KiteTickerError.malformedText,
    ]
    for error in errors {
        #expect(!SandboxVerificationReport.category(error).contains(secret))
    }
    #expect(SandboxVerificationReport.category(errors[2]).hasPrefix("UNCERTAIN:"))
}

@Test func `sandbox wire summaries omit values and unknown field names`() async {
    let shapes = SandboxWireShapes()
    await shapes.record(#"{"type":"secret-token","data":{"order_id":"private-order","private-account-key":"private-value"}}"#)
    let summary = await shapes.summary().description
    #expect(summary.contains("other: order_id; other fields: 1"))
    for secret in ["secret-token", "private-order", "private-account-key", "private-value"] {
        #expect(!summary.contains(secret))
    }
}
