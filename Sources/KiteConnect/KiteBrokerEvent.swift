//
//  KiteBrokerEvent.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Non-order text notifications. Server errors are delivered as values: the documented
/// payload is a string. Explicit credential/session failures also stop ticker recovery.
public enum KiteBrokerEvent: Sendable, Equatable {
    /// A broker informational message carried by a text event.
    case message(String)
    /// A broker error string. Recognized authentication errors also block recovery.
    case serverError(String)
    /// An unrecognized text-event type and its preserved JSON data for forward compatibility.
    case unknown(type: String, data: KiteOrderMetadata)
}

enum KiteTextEvent: Decodable {
    case order(KiteOrderUpdateEvent)
    case broker(KiteBrokerEvent)

    enum CodingKeys: String, CodingKey { case type, data }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "order": self = try .order(c.decode(KiteOrderUpdateEvent.self, forKey: .data))
        case "message": self = try .broker(.message(c.decode(String.self, forKey: .data)))
        case "error": self = try .broker(.serverError(c.decode(String.self, forKey: .data)))
        default:
            self = try .broker(
                .unknown(type: type, data: c.decode(KiteOrderMetadata.self, forKey: .data)),
            )
        }
    }
}
