//
//  KiteOrderUpdateEvent.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// A streamed order update with shared order state and delivery metadata. This decodes
/// the flat postback payload, never a REST order envelope or the stricter KiteOrder.
/// Checksum is preserved only; HTTP postback authentication belongs to the postback helper.
public struct KiteOrderUpdateEvent: Decodable, Sendable, Equatable {
    /// The shared order state. A notification does not by itself establish execution.
    public let update: KiteOrderUpdate
    /// The user identifier carried by the streaming order notification.
    public let userID: String
    /// The application identifier when the notification includes one.
    public let appID: Int64?
    /// The checksum text when present. Decoding preserves it without authentication.
    public let checksum: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case appID = "app_id"
        case checksum
    }

    /// Decodes a flat WebSocket order payload, not a REST order envelope.
    /// - Parameter decoder: Decoder configured for the trading time zone of offsetless timestamps.
    /// - Throws: A decoding error for missing required fields, empty order ID, or zero instrument token.
    public init(from decoder: any Decoder) throws {
        update = try KiteOrderUpdate(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(String.self, forKey: .userID)
        appID = try c.decodeIfPresent(Int64.self, forKey: .appID)
        checksum = try c.decodeIfPresent(String.self, forKey: .checksum)
        guard !update.orderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              update.instrumentToken > 0
        else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath, debugDescription: "Invalid streaming order identifier",
                ),
            )
        }
    }
}
