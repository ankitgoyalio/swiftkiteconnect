//
//  PostbackDocumentationExamplesTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func `documented HTTP postback handler decodes controlled body`() throws {
    let postback = try decodeIncomingHTTPPostback(
        body: offlineHTTPPostbackBody(), backendSecret: "fixture-secret",
    )
    #expect(postback.userID == "AB1234")
    #expect(postback.appID == 1234)
    #expect(postback.order.orderID == "220303000308932")
    #expect(postback.order.status == .complete)
    #expect(postback.order.averagePrice == 470)
    #expect(postback.order.orderTimestampRaw == "2022-03-03 09:24:25")
    #expect(
        postback.order.orderTimestamp == ISO8601DateFormatter().date(from: "2022-03-03T03:54:25Z"),
    )
}

@Test func `documented HTTP postback handler rejects invalid inputs`() {
    #expect(throws: KitePostbackError.invalidSecret) {
        try decodeIncomingHTTPPostback(body: Data(), backendSecret: "")
    }
    #expect(throws: KitePostbackError.invalidChecksum) {
        try decodeIncomingHTTPPostback(body: offlineHTTPPostbackBody(), backendSecret: "wrong-secret")
    }
    #expect(throws: DecodingError.self) {
        try decodeIncomingHTTPPostback(body: Data("{}".utf8), backendSecret: "fixture-secret")
    }
}
