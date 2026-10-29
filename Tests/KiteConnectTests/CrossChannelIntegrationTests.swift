//
//  CrossChannelIntegrationTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

/// The same order can be observed through reconciliation reads and two notification channels.
/// Synthetic compatibility changes to the pinned postback example preserve literal decimals.
@Test(.timeLimit(.minutes(1)), arguments: ["Asia/Kolkata", "UTC"])
func reconciliationChannelsAgreeOnUnknownStateDecimalsAndTimestamp(zone: String) async throws {
    let text =
        orderUpdateFixture
            .replacingOccurrences(of: #""status": "COMPLETE""#, with: #""status": "FUTURE_STATE""#)
            .replacingOccurrences(
                of: #""average_price": 470"#, with: #""average_price": 470.123456789012345678"#,
            )
            .replacingOccurrences(
                of: #""guid": "XXXXXX""#, with: #""guid": "XXXXXX", "modified": false, "future_field": true"#,
            )
            .replacingOccurrences(
                of: "2011845d9348bd6795151bf4258102a03431e3bb12a79c0df73fcb4b7fde4b5d",
                with: "d6b6e7d40302670c95e8b74da93e29b86ca66b85adbe056363af4191178fd21c",
            )
    // Remove the literal WebSocket wrapper without a floating-point JSON round trip.
    let body = String(text.dropFirst(#"{"type":"order","data":"#.count).dropLast())
    let timeZone = try #require(TimeZone(identifier: zone))
    let transport = ControlledHTTP(#"{"status":"success","data":["# + body + "]}")
    let client = try KiteClient(
        apiKey: "key", accessToken: "old",
        configuration: KiteConfiguration(tradingTimeZone: timeZone), transport: transport,
    )
    try await client.replaceAccessToken("fresh")
    let rest = try #require(try await client.orderHistory(orderID: "220303000308932").first)
    let postback = try KitePostbacks.decode(
        Data(body.utf8), apiSecret: "fixture-secret", tradingTimeZone: timeZone,
    )
    let socket = ControlledWebSocket()
    let ticker = try KiteTicker(
        apiKey: "key", accessToken: "fresh", transport: socket, tradingTimeZone: timeZone,
    )
    var updates = try await ticker.orderUpdates().makeAsyncIterator()
    try await ticker.connect()
    socket.socket.incoming.yield(.text(text))
    let event = try #require(try await updates.next())
    #expect(rest.update == postback.order)
    #expect(event.update == postback.order)
    #expect(rest.status == .unknown("FUTURE_STATE"))
    #expect(rest.averagePrice == Decimal(string: "470.123456789012345678"))
    #expect(
        rest.orderTimestamp
            == Date(timeIntervalSince1970: zone == "UTC" ? 1_646_299_465 : 1_646_279_665),
    )
    #expect(await transport.requests.first?.headers["Authorization"] == "token key:fresh")
    await ticker.disconnect()
}
