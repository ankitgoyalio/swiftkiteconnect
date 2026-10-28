//
//  PublisherDocumentationTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation
import KiteConnect
import Testing

private actor PublisherReadHTTP: KiteHTTPTransport {
    var requests: [KiteHTTPRequest] = []

    func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        requests.append(request)
        let body: String
        switch request.url.path {
        case "/oms/orders": body = orderBookJSON
        case "/oms/trades": body = allTradesJSON
        default: throw URLError(.unsupportedURL)
        }
        return KiteHTTPResponse(statusCode: 200, body: Data(body.utf8))
    }
}

@Test func `Publisher reconciliation example reads orders and fills without a mutation`() async throws {
    let transport = PublisherReadHTTP()
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token",
        configuration: .sandbox, transport: transport,
    )
    let result = try await inspectPublisherOutcome(client: client)
    #expect(result.orders.count == 10)
    #expect(result.orders.first?.orderID == "100000000000000")
    #expect(result.trades.count == 4)
    #expect(result.trades.first?.tradeID == "10000000")
    let requests = await transport.requests
    #expect(requests.map(\.url.path) == ["/oms/orders", "/oms/trades"])
    #expect(requests.allSatisfy { $0.method == .get && $0.body == nil })
    #expect(requests.allSatisfy { $0.headers["Authorization"] == "token fixture-key:fixture-token" })
}

@Test func `Publisher reconciliation example propagates cancellation`() async throws {
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token",
        configuration: .sandbox, transport: CancelledHTTP(),
    )
    await #expect(throws: CancellationError.self) {
        try await inspectPublisherOutcome(client: client)
    }
}
