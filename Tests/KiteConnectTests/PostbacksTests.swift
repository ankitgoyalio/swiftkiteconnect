//
//  PostbacksTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func postbacksDecodeDocumentedRawBody() throws {
    let postback = try KitePostbacks.decode(Data(postbackJSON.utf8), apiSecret: "fixture-secret")
    #expect(postback.userID == "AB1234")
    #expect(postback.appID == 1234)
    #expect(postback.order.orderID == "220303000308932")
    #expect(postback.order.status == .complete)
    #expect(postback.order.unfilledQuantity == 0)
    #expect(postback.order.modified == nil)
    #expect(postback.order.averagePrice == 470)
    #expect(postback.order.orderTimestampRaw == "2022-03-03 09:24:25")
    #expect(
        postback.order.orderTimestamp == ISO8601DateFormatter().date(from: "2022-03-03T03:54:25Z"),
    )
}

@Test func postbacksRejectTamperedChecksumInputsAndWrongSecret() throws {
    for body in [
        postbackJSON.replacingOccurrences(of: "220303000308932", with: "220303000308933"),
        postbackJSON.replacingOccurrences(of: "2022-03-03 09:24:25", with: "2022-03-03 09:24:26"),
        postbackJSON.replacingOccurrences(
            of: "d6b6e7d40302670c95e8b74da93e29b86ca66b85adbe056363af4191178fd21c",
            with: String(repeating: "0", count: 64),
        ),
    ] {
        #expect(throws: KitePostbackError.invalidChecksum) {
            try KitePostbacks.decode(Data(body.utf8), apiSecret: "fixture-secret")
        }
    }
    #expect(throws: KitePostbackError.invalidChecksum) {
        try KitePostbacks.decode(Data(postbackJSON.utf8), apiSecret: "wrong-secret")
    }
}

@Test func postbacksRejectEmptyEnvelopeIdentityAndMissingNotificationQuantity() throws {
    for body in [
        postbackJSON.replacingOccurrences(of: #""user_id": "AB1234""#, with: #""user_id": """#),
        postbackJSON.replacingOccurrences(of: #""app_id": 1234"#, with: #""app_id": -1"#),
        postbackJSON.replacingOccurrences(of: #""unfilled_quantity": 0,"#, with: ""),
    ] {
        #expect(throws: DecodingError.self) {
            try KitePostbacks.decode(Data(body.utf8), apiSecret: "fixture-secret")
        }
    }
}

@Test func postbacksRejectEmptySecretBeforeProcessingUntrustedBody() {
    #expect(throws: KitePostbackError.invalidSecret) {
        try KitePostbacks.decode(Data(), apiSecret: "")
    }
}

@Test func postbacksVerifyUTF8AndExactOriginalTimestampText() throws {
    let body =
        postbackJSON
            .replacingOccurrences(of: "220303000308932", with: "आदेश-订单-🙂")
            .replacingOccurrences(of: "2022-03-03 09:24:25", with: "2022-03-03T09:24:25+05:30")
            .replacingOccurrences(
                of: fixtureChecksum, with: "56fc9cbf10ab025739e2fea10387d34c4ed48344bb4e114174cf7e3b81995658",
            )
    let first = try KitePostbacks.decode(Data(body.utf8), apiSecret: "गुप्त-秘密-🔑")
    #expect(first.order.orderID == "आदेश-订单-🙂")
    #expect(first.order.orderTimestampRaw == "2022-03-03T09:24:25+05:30")
    let equivalent = body.replacingOccurrences(
        of: "2022-03-03T09:24:25+05:30", with: "2022-03-03T03:54:25Z",
    )
    #expect(throws: KitePostbackError.invalidChecksum) {
        try KitePostbacks.decode(Data(equivalent.utf8), apiSecret: "गुप्त-秘密-🔑")
    }
    let resigned = equivalent.replacingOccurrences(
        of: "56fc9cbf10ab025739e2fea10387d34c4ed48344bb4e114174cf7e3b81995658",
        with: "627a501bcb1166d0c96cd590d40a40dc7f42b2c8e697f40aadfe17cd993e1873",
    )
    let second = try KitePostbacks.decode(Data(resigned.utf8), apiSecret: "गुप्त-秘密-🔑")
    #expect(first.order.orderTimestamp == second.order.orderTimestamp)
    #expect(first.order.orderTimestampRaw != second.order.orderTimestampRaw)
}

@Test func postbacksUseConfiguredTradingZoneWithoutChangingChecksumInput() throws {
    let data = Data(postbackJSON.utf8)
    let utc = try KitePostbacks.decode(
        data, apiSecret: "fixture-secret", tradingTimeZone: TimeZone(secondsFromGMT: 0)!,
    )
    let india = try KitePostbacks.decode(data, apiSecret: "fixture-secret")
    #expect(utc.order.orderTimestamp.timeIntervalSince(india.order.orderTimestamp) == 19800)
    #expect(utc.order.orderTimestampRaw == india.order.orderTimestampRaw)
    #expect(utc.order.exchangeTimestamp?.timeIntervalSince(india.order.exchangeTimestamp!) == 19800)
}

@Test func postbacksPreserveDecimalOptionalUnknownAndExtraData() throws {
    let body =
        postbackJSON
            .replacingOccurrences(
                of: #""average_price": 470"#, with: #""average_price": 470.123456789012345678"#,
            )
            .replacingOccurrences(of: #""price": 0"#, with: #""price": 0.123456789012345678"#)
            .replacingOccurrences(
                of: #""trigger_price": 0"#, with: #""trigger_price": 1.000000000000000001"#,
            )
            .replacingOccurrences(of: #""status": "COMPLETE""#, with: #""status": "FUTURE_STATE""#)
            .replacingOccurrences(
                of: #""exchange_order_id": "1000000001482421""#, with: #""exchange_order_id": null"#,
            )
            .replacingOccurrences(
                of: #""meta": {}"#, with: #""future": true, "meta": {"cost": 0.123456789012345678}"#,
            )
    let postback = try KitePostbacks.decode(Data(body.utf8), apiSecret: "fixture-secret")
    #expect(postback.order.averagePrice == Decimal(string: "470.123456789012345678"))
    #expect(postback.order.price == Decimal(string: "0.123456789012345678"))
    #expect(postback.order.triggerPrice == Decimal(string: "1.000000000000000001"))
    #expect(postback.order.status == .unknown("FUTURE_STATE"))
    #expect(postback.order.exchangeOrderID == nil)
    #expect(postback.order.parentOrderID == nil)
    #expect(postback.order.statusMessage == nil)
    #expect(
        postback.order.meta == .object(["cost": .number(Decimal(string: "0.123456789012345678")!)]),
    )
    for replacement in [#""status": null,"#, ""] {
        let nullable = postbackJSON.replacingOccurrences(
            of: #""status": "COMPLETE","#, with: replacement,
        )
        #expect(
            try KitePostbacks.decode(Data(nullable.utf8), apiSecret: "fixture-secret").order.status == nil,
        )
    }
    let sparse = try changedPostback(removing: [
        "exchange_order_id", "parent_order_id", "status_message", "status_message_raw",
        "exchange_timestamp", "exchange_update_timestamp", "market_protection", "meta", "tag", "guid",
    ])
    let sparseOrder = try KitePostbacks.decode(sparse, apiSecret: "fixture-secret").order
    #expect(sparseOrder.exchangeTimestamp == nil)
    #expect(sparseOrder.exchangeUpdateTimestamp == nil)
    #expect(sparseOrder.meta == nil)
}

@Test func postbacksRejectMalformedChecksumText() {
    for checksum in [
        "", "abc", String(repeating: "g", count: 64), String(repeating: "0", count: 63),
        fixtureChecksum + "\n", fixtureChecksum.uppercased(),
    ] {
        let body = postbackJSON.replacingOccurrences(
            of: fixtureChecksum, with: checksum.replacingOccurrences(of: "\n", with: "\\n"),
        )
        #expect(throws: KitePostbackError.invalidChecksum) {
            try KitePostbacks.decode(Data(body.utf8), apiSecret: "fixture-secret")
        }
    }
}

@Test func postbacksRejectMissingNullAndMalformedRequiredFields() throws {
    let required = [
        "user_id", "app_id", "checksum", "unfilled_quantity", "placed_by", "order_id",
        "order_timestamp", "exchange", "tradingsymbol", "instrument_token", "variety",
        "transaction_type", "order_type", "product", "validity", "quantity", "disclosed_quantity",
        "filled_quantity", "pending_quantity", "cancelled_quantity", "price", "trigger_price",
        "average_price",
    ]
    for key in required {
        for data in try [
            changedPostback(removing: [key]), changedPostback(setting: [key: NSNull()]),
            changedPostback(setting: [key: ["invalid"]]),
        ] {
            #expect(throws: DecodingError.self) {
                try KitePostbacks.decode(data, apiSecret: "fixture-secret")
            }
        }
    }
    for (key, value) in [
        ("quantity", -1 as Any), ("unfilled_quantity", -1), ("app_id", 1.5), ("quantity", 1.5),
        ("instrument_token", 4_294_967_296), ("status", 123), ("market_protection", "invalid"),
        ("exchange_timestamp", "2022-02-30 09:24:25"), ("order_id", ""),
    ] {
        #expect(throws: DecodingError.self) {
            try KitePostbacks.decode(
                changedPostback(setting: [key: value]), apiSecret: "fixture-secret",
            )
        }
    }
    // Correctly signed, but not a valid calendar date.
    let invalidDate = postbackJSON.replacingOccurrences(
        of: "2022-03-03 09:24:25", with: "2022-02-30 09:24:25",
    )
    .replacingOccurrences(
        of: fixtureChecksum, with: "671bd6d20abb35f0c8dd22966fb9b4f9629a95ccb38de990d707ea2ce8f328fb",
    )
    #expect(throws: DecodingError.self) {
        try KitePostbacks.decode(Data(invalidDate.utf8), apiSecret: "fixture-secret")
    }
}

@Test func postbacksRejectInvalidRawBodies() {
    for data in [
        Data(), Data([0xFF, 0xFE]), Data("null".utf8), Data("[]".utf8), Data("{}".utf8),
        Data("{broken".utf8), Data((postbackJSON + " trailing").utf8),
    ] {
        #expect(throws: DecodingError.self) {
            try KitePostbacks.decode(data, apiSecret: "fixture-secret")
        }
    }
}

/// JSONSerialization is used only for structural variants; precision tests edit raw JSON above.
private func changedPostback(removing keys: [String] = [], setting values: [String: Any] = [:])
    throws -> Data
{
    var object = try #require(
        JSONSerialization.jsonObject(with: Data(postbackJSON.utf8)) as? [String: Any],
    )
    for key in keys {
        object.removeValue(forKey: key)
    }
    for (key, value) in values {
        object[key] = value
    }
    return try JSONSerialization.data(withJSONObject: object)
}

private let fixtureChecksum = "d6b6e7d40302670c95e8b74da93e29b86ca66b85adbe056363af4191178fd21c"

/// Official release snapshot payload; checksum replaced for the synthetic fixture-secret.
/// Known checksum literals independently computed with Python hashlib.sha256, UTF-8 input.
private let postbackJSON = #"""
{
    "user_id": "AB1234",
    "unfilled_quantity": 0,
    "app_id": 1234,
    "checksum": "d6b6e7d40302670c95e8b74da93e29b86ca66b85adbe056363af4191178fd21c",
    "placed_by": "AB1234",
    "order_id": "220303000308932",
    "exchange_order_id": "1000000001482421",
    "parent_order_id": null,
    "status": "COMPLETE",
    "status_message": null,
    "status_message_raw": null,
    "order_timestamp": "2022-03-03 09:24:25",
    "exchange_update_timestamp": "2022-03-03 09:24:25",
    "exchange_timestamp": "2022-03-03 09:24:25",
    "variety": "regular",
    "exchange": "NSE",
    "tradingsymbol": "SBIN",
    "instrument_token": 779521,
    "order_type": "MARKET",
    "transaction_type": "BUY",
    "validity": "DAY",
    "product": "CNC",
    "quantity": 1,
    "disclosed_quantity": 0,
    "price": 0,
    "trigger_price": 0,
    "average_price": 470,
    "filled_quantity": 1,
    "pending_quantity": 0,
    "cancelled_quantity": 0,
    "market_protection": 0,
    "meta": {},
    "tag": null,
    "guid": "XXXXXX"
}
"""#
