//
//  WebSocketAdapterTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func webSocketAdapterRejectsInvalidEndpointsWithoutNetworking() async throws {
    let adapter = NIOKiteWebSocketTransport()
    await #expect(throws: KiteTickerError.self) {
        _ = try await adapter.connect(url: URL(string: "https://127.0.0.1")!)
    }
}
