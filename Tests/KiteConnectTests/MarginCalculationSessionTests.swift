//
//  MarginCalculationSessionTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test(arguments: CalculationOperation.allCases)
private func calculationSessionsRemainIsolatedAndRequireCurrentAuthentication(
    operation: CalculationOperation,
) async throws {
    let transport = ControlledHTTP(operation.response)
    let configuration = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 9,
    )
    let first = try KiteClient(
        apiKey: "one", accessToken: "old", configuration: configuration, transport: transport,
    )
    let second = try KiteClient(
        apiKey: "two", accessToken: "other", configuration: configuration, transport: transport,
    )
    async let a: Void = operation.run(first)
    async let b: Void = operation.run(second)
    _ = try await (a, b)
    try await first.replaceAccessToken("new")
    try await operation.run(first)
    let requests = await transport.requests
    #expect(
        Set(requests.prefix(2).compactMap { $0.headers["Authorization"] }) == [
            "token one:old", "token two:other",
        ],
    )
    #expect(requests.last?.headers["Authorization"] == "token one:new")
    #expect(
        requests.allSatisfy {
            $0.timeout == 9 && $0.headers["X-Kite-Version"] == "3"
                && $0.headers["Content-Type"] == "application/json"
        },
    )
    try await first.replaceAccessToken(nil)
    do {
        try await operation.run(first)
        Issue.record("Expected missing-session validation")
    } catch let KiteError.validation(field, _) { #expect(field == "accessToken") }
    #expect(await transport.requests.count == 3)
}
