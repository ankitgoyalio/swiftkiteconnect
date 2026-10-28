//
//  DocumentationExamplesTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import KiteConnect
import Testing

@Test func `documented client construction uses sandbox without requests`() throws {
    let client = try configuredSandboxClient(accessToken: "fixture-token")
    #expect(client.apiKey == "sandboxdemo")
    #expect(client.configuration.baseURL.absoluteString == "https://sandbox.kite.trade")
    #expect(client.configuration.routePrefix == "oms")
    #expect(throws: KiteError.self) {
        try configuredSandboxClient(accessToken: "invalid token")
    }
}
