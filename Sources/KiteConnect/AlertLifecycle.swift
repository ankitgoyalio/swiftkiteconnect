//
//  AlertLifecycle.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Shared lifecycle response for simple and order-triggering alerts.
public struct KiteAlert: Decodable, Sendable, Equatable {
    /// The simple or order-triggering alert kind reported by Kite.
    public let type: KiteAlertType
    /// The user account identifier associated with this server record.
    public let userID: String
    /// The opaque alert identifier used for lookup, history, modification, and deletion.
    public let uuid: String
    /// The application-supplied display name for this alert or basket.
    public let name: String
    /// The server lifecycle state of this alert definition.
    public let status: KiteAlertStatus
    /// The broker-supplied explanation for disabling the alert.
    public let disabledReason: String
    /// The left-hand instrument attribute compared by the alert.
    public let lhsAttribute: String
    /// The exchange identifying the left-hand instrument.
    public let lhsExchange: KiteExchange
    /// The trading symbol identifying the left-hand instrument within its exchange.
    public let lhsTradingSymbol: String
    /// The comparison operator applied to the left and right operands.
    public let comparison: KiteAlertOperator
    /// Whether the right-hand operand is a constant or an instrument attribute.
    public let rhsType: KiteAlertOperandType
    /// The right-hand instrument attribute returned by Kite.
    public let rhsAttribute: String
    /// The exchange identifying the right-hand instrument operand.
    public let rhsExchange: KiteExchange
    /// The trading symbol identifying the right-hand instrument operand.
    public let rhsTradingSymbol: String
    /// The decimal right-hand constant reported by Kite.
    public let rhsConstant: Decimal
    /// The number of alert occurrences reported by Kite.
    public let alertCount: Int64
    /// The creation instant reported by Kite, using the configured timezone when offsetless.
    public let createdAt: Date
    /// The last modification instant reported by Kite.
    public let updatedAt: Date
    /// Creation receipts may omit the basket, even for ATO alerts.
    public let basket: KiteAlertBasket?
    enum CodingKeys: String, CodingKey {
        case type
        case userID = "user_id"
        case uuid
        case name
        case status
        case disabledReason = "disabled_reason"
        case lhsAttribute = "lhs_attribute"
        case lhsExchange = "lhs_exchange"
        case lhsTradingSymbol = "lhs_tradingsymbol"
        case comparison = "operator"
        case rhsType = "rhs_type"
        case rhsAttribute = "rhs_attribute"
        case rhsExchange = "rhs_exchange"
        case rhsTradingSymbol = "rhs_tradingsymbol"
        case rhsConstant = "rhs_constant"
        case alertCount = "alert_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case basket
    }

    /// Decodes a lifecycle record with a nonempty UUID and optional ATO basket.
    ///
    /// - Parameter decoder: The decoder positioned at the response value, outside any Kite envelope.
    /// - Throws: A decoding error for missing or malformed required values. Optional
    ///   fields allow absence or null, but malformed present values fail.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(KiteAlertType.self, forKey: .type)
        userID = try container.decode(String.self, forKey: .userID)
        uuid = try container.decode(String.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(KiteAlertStatus.self, forKey: .status)
        disabledReason = try container.decode(String.self, forKey: .disabledReason)
        lhsAttribute = try container.decode(String.self, forKey: .lhsAttribute)
        lhsExchange = try container.decode(KiteExchange.self, forKey: .lhsExchange)
        lhsTradingSymbol = try container.decode(String.self, forKey: .lhsTradingSymbol)
        comparison = try container.decode(KiteAlertOperator.self, forKey: .comparison)
        rhsType = try container.decode(KiteAlertOperandType.self, forKey: .rhsType)
        rhsAttribute = try container.decode(String.self, forKey: .rhsAttribute)
        rhsExchange = try container.decode(KiteExchange.self, forKey: .rhsExchange)
        rhsTradingSymbol = try container.decode(String.self, forKey: .rhsTradingSymbol)
        rhsConstant = try container.decode(Decimal.self, forKey: .rhsConstant)
        alertCount = try container.decode(Int64.self, forKey: .alertCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        basket = try container.decodeIfPresent(KiteAlertBasket.self, forKey: .basket)
        guard !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .uuid, in: container, debugDescription: "Empty alert identifier",
            )
        }
    }
}
