//
//  Postbacks.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// An HTTP order notification decoded and checksum-checked by ``KitePostbacks``.
///
/// The checksum binds only the order ID and original timestamp to the API secret.
/// Other fields are structurally decoded but are not covered by the checksum.
/// Applications own routing, deduplication, and reconciliation.
/// See <doc:Postbacks-and-order-updates> for delivery and verification limits.
public struct KitePostback: Sendable, Equatable {
    /// The nonempty `user_id` supplied in the notification, not covered by the checksum.
    /// The application must check that this user belongs to the expected route.
    public let userID: String
    /// The nonnegative `app_id` supplied in the notification, not covered by the checksum.
    /// This value does not replace the application's trusted configuration for secret selection.
    public let appID: Int64
    /// The decoded order state, including the original timestamp text used for the checksum.
    /// Status can be absent or null, and checksum success does not establish a fill.
    public let order: KiteOrderUpdate
}

/// Local secret and checksum failures from ``KitePostbacks/decode(_:apiSecret:tradingTimeZone:)``.
///
/// Invalid JSON, missing required fields, malformed values, and invalid dates
/// throw `DecodingError` instead. No HTTP request or retry occurs.
public enum KitePostbackError: Error, Sendable, Equatable {
    /// The supplied API secret is empty. This check runs before the payload is decoded.
    case invalidSecret
    /// The received checksum differs from the expected lowercase SHA-256 digest.
    /// Malformed digest text, uppercase hex, and a wrong secret also produce this error.
    case invalidChecksum
}

/// Backend helpers that validate incoming raw JSON HTTP postbacks without network access.
///
/// The application owns the HTTP server, HTTPS ingress, and secret storage.
/// See <doc:Receive-HTTP-postbacks> for integration with an application-owned handler.
public enum KitePostbacks {
    /// Decodes an HTTP postback body and verifies its documented SHA-256 checksum.
    ///
    /// The digest covers the UTF-8 text `order_id + order_timestamp + api_secret`
    /// without separators. The original timestamp text is retained for verification.
    /// Explicit timestamp offsets determine the instant. Offsetless timestamps use
    /// `tradingTimeZone`, never the device timezone.
    ///
    /// The envelope requires a nonempty user ID, a nonnegative integer app ID,
    /// and a nonnegative integer unfilled quantity, plus the required ``KiteOrderUpdate``
    /// fields. Unknown JSON fields are ignored and unfamiliar server strings are preserved.
    /// Status and modified state can be absent. Required fields cannot be null.
    ///
    /// Checksum success does not authenticate the remaining fields or establish
    /// freshness or execution. The application owns app and user routing, replay
    /// handling, and reconciliation. Keep the API secret on the backend.
    ///
    /// - Parameters:
    ///   - payload: The raw JSON HTTP request body, without a REST or WebSocket wrapper.
    ///   - apiSecret: The nonempty API secret from the backend's trusted configuration.
    ///   - tradingTimeZone: The zone for offsetless timestamps. Defaults to `Asia/Kolkata`.
    /// - Returns: The decoded user ID, app ID, and order state after checksum verification.
    /// - Throws: ``KitePostbackError/invalidSecret`` before decoding if the secret is empty.
    ///   Throws `DecodingError` for malformed JSON or invalid required structure and values.
    ///   Throws ``KitePostbackError/invalidChecksum`` if the checksum does not match exactly.
    public static func decode(
        _ payload: Data, apiSecret: String,
        tradingTimeZone: TimeZone = TimeZone(identifier: "Asia/Kolkata")!,
    ) throws -> KitePostback {
        guard !apiSecret.isEmpty else { throw KitePostbackError.invalidSecret }
        let envelope = try KiteTimestamp.decoder(timeZone: tradingTimeZone)
            .decode(PostbackEnvelope.self, from: payload)
        let expected = KiteChecksum.sha256(
            envelope.order.orderID + envelope.order.orderTimestampRaw + apiSecret,
        )
        // Compare every byte for equal-length digests rather than exiting at the first mismatch.
        let receivedBytes = Array(envelope.checksum.utf8)
        let expectedBytes = Array(expected.utf8)
        guard receivedBytes.count == expectedBytes.count else {
            throw KitePostbackError.invalidChecksum
        }
        var difference: UInt8 = 0
        for (received, expected) in zip(receivedBytes, expectedBytes) {
            difference |= received ^ expected
        }
        guard difference == 0 else { throw KitePostbackError.invalidChecksum }
        return KitePostback(userID: envelope.userID, appID: envelope.appID, order: envelope.order)
    }
}

private struct PostbackEnvelope: Decodable {
    let userID: String
    let appID: Int64
    let order: KiteOrderUpdate
    let checksum: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case appID = "app_id"
        case unfilledQuantity = "unfilled_quantity"
        case checksum
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        appID = try container.decode(Int64.self, forKey: .appID)
        checksum = try container.decode(String.self, forKey: .checksum)
        let unfilledQuantity = try container.decode(Int64.self, forKey: .unfilledQuantity)
        guard !userID.isEmpty, appID >= 0, unfilledQuantity >= 0 else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a nonempty user ID and nonnegative app ID and quantity",
                ),
            )
        }
        order = try KiteOrderUpdate(from: decoder)
    }
}
