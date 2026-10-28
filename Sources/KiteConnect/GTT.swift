//
//  GTT.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// The single-leg or two-leg OCO trigger shape, preserving unfamiliar server strings.
public enum KiteGTTType: KiteStringValue {
    /// One trigger value associated with one embedded LIMIT order.
    case single
    /// Two trigger values associated by index with two OCO order legs.
    case twoLeg
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Maps exact server spellings to known cases without rejecting unfamiliar values.
    ///
    /// - Parameter rawValue: Case-sensitive wire text; unknown values remain unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "single": self = .single
        case "two-leg": self = .twoLeg
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .single: "single"
        case .twoLeg: "two-leg"
        case let .unknown(value): value
        }
    }
}

/// The stored trigger lifecycle state, distinct from the execution state of its orders.
public enum KiteGTTStatus: KiteStringValue {
    /// The stored trigger is active and awaiting its condition.
    case active
    /// The condition fired; embedded order submission can still fail.
    case triggered
    /// The server has disabled this trigger or alert definition.
    case disabled
    /// The stored trigger has reached its server-reported expiry.
    case expired
    /// The server reports the stored trigger as cancelled; inspect any earlier order attempts.
    case cancelled
    /// The server reports the stored trigger as rejected; inspect its embedded results.
    case rejected
    /// The server reports this trigger or alert as deleted.
    case deleted
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Maps exact server spellings to known cases without rejecting unfamiliar values.
    ///
    /// - Parameter rawValue: Case-sensitive wire text; unknown values remain unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "active": self = .active
        case "triggered": self = .triggered
        case "disabled": self = .disabled
        case "expired": self = .expired
        case "cancelled": self = .cancelled
        case "rejected": self = .rejected
        case "deleted": self = .deleted
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .active: "active"
        case .triggered: "triggered"
        case .disabled: "disabled"
        case .expired: "expired"
        case .cancelled: "cancelled"
        case .rejected: "rejected"
        case .deleted: "deleted"
        case let .unknown(value): value
        }
    }
}

/// The triggered order submission result, distinct from a confirmed exchange execution.
public enum KiteGTTOrderResultStatus: KiteStringValue {
    /// The triggered order submission succeeded; a fill still requires reconciliation.
    case success
    /// The triggered order submission failed as reported by Kite.
    case failed
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Maps exact server spellings to known cases without rejecting unfamiliar values.
    ///
    /// - Parameter rawValue: Case-sensitive wire text; unknown values remain unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "success": self = .success
        case "failed": self = .failed
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .success: "success"
        case .failed: "failed"
        case let .unknown(value): value
        }
    }
}

/// Trigger condition returned by Kite, including its response-only instrument token.
public struct KiteGTTCondition: Decodable, Sendable, Equatable {
    /// The exchange on which the instrument is identified.
    public let exchange: KiteExchange
    /// The trading symbol within the specified exchange.
    public let tradingSymbol: String
    /// The trigger prices in order-leg index order; single uses one and OCO uses two.
    public let triggerValues: [Decimal]
    /// The last traded price supplied with the trigger condition or basket.
    public let lastPrice: Decimal
    /// The numeric instrument token supplied by Kite; tokens may be reused after expiry.
    public let instrumentToken: UInt32
    enum CodingKeys: String, CodingKey {
        case exchange
        case tradingSymbol = "tradingsymbol"
        case triggerValues = "trigger_values"
        case lastPrice = "last_price"
        case instrumentToken = "instrument_token"
    }
}

/// Embedded order definition and its optional execution result. This is not a standalone order.
public struct KiteGTTOrder: Decodable, Sendable, Equatable {
    /// The exchange on which the instrument is identified.
    public let exchange: KiteExchange
    /// The trading symbol within the specified exchange.
    public let tradingSymbol: String
    /// The buy or sell direction of the embedded or standalone order.
    public let transactionType: KiteTransactionType
    /// The order quantity in instrument units; submitted quantities must be positive.
    public let quantity: Int64
    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public let orderType: KiteOrderType
    /// The broker product used for the order or execution.
    public let product: KiteProduct
    /// The order price as a decimal value, distinct from its execution price.
    public let price: Decimal
    /// The optional trigger-time order attempt details; absence does not establish execution.
    public let result: KiteGTTExecution?
    enum CodingKeys: String, CodingKey {
        case exchange
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case quantity
        case orderType = "order_type"
        case product
        case price
        case result
    }
}

/// Execution attempt details. `meta` is the documented JSON-encoded string, preserved verbatim.
public struct KiteGTTExecution: Decodable, Sendable, Equatable {
    /// The account identifier associated with this order or execution attempt.
    public let accountID: String
    /// The exchange on which the instrument is identified.
    public let exchange: KiteExchange
    /// The trading symbol within the specified exchange.
    public let tradingSymbol: String
    /// The buy or sell direction of the embedded or standalone order.
    public let transactionType: KiteTransactionType
    /// The order quantity in instrument units; submitted quantities must be positive.
    public let quantity: Int64
    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public let orderType: KiteOrderType
    /// The broker product used for the order or execution.
    public let product: KiteProduct
    /// The order price as a decimal value, distinct from its execution price.
    public let price: Decimal
    /// The order lifetime instruction reported or submitted to Kite.
    public let validity: KiteOrderValidity
    /// The optional JSON-encoded metadata string, retained verbatim rather than parsed.
    public let meta: String?
    /// The event instant, using the configured trading timezone for offsetless text.
    public let timestamp: Date
    /// The market price at which the trigger fired, as reported by Kite.
    public let triggeredAt: Decimal
    /// The optional order submission result; success does not establish a fill.
    public let orderResult: KiteGTTOrderResult?
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case exchange
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case quantity
        case orderType = "order_type"
        case product
        case price
        case validity
        case meta
        case timestamp
        case triggeredAt = "triggered_at"
        case orderResult = "order_result"
    }
}

/// Result fields may be missing or null. A failed attempt can have an empty order ID.
public struct KiteGTTOrderResult: Decodable, Sendable, Equatable {
    /// The optional triggered-order submission status; success does not prove a fill.
    public let status: KiteGTTOrderResultStatus?
    /// The optional triggered order identifier; a failed attempt can report an empty string.
    public let orderID: String?
    /// The optional broker explanation for a failed triggered order attempt.
    public let rejectionReason: String?
    enum CodingKeys: String, CodingKey {
        case status
        case orderID = "order_id"
        case rejectionReason = "rejection_reason"
    }
}

/// A stored GTT definition and lifecycle state with indexed embedded order results.
public struct KiteGTTTrigger: Decodable, Sendable, Equatable {
    /// The numeric server identifier for this trigger or basket item.
    public let id: Int64
    /// The user account identifier associated with this server record.
    public let userID: String
    /// The parent trigger identifier, when this trigger has a parent.
    public let parentTrigger: Int64?
    /// The stored single-leg or two-leg OCO trigger shape.
    public let type: KiteGTTType
    /// The creation instant reported by Kite, using the configured timezone when offsetless.
    public let createdAt: Date
    /// The last modification instant reported by Kite.
    public let updatedAt: Date
    /// The expiry instant of the stored GTT trigger definition.
    public let expiresAt: Date
    /// The trigger lifecycle state, separate from embedded order execution.
    public let status: KiteGTTStatus
    /// The comparison or trigger condition associated with this definition.
    public let condition: KiteGTTCondition
    /// The embedded order legs in the same index order as the trigger values.
    public let orders: [KiteGTTOrder]
    /// The server metadata preserved without assuming a fixed JSON schema.
    public let meta: KiteOrderMutationJSONValue?
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case parentTrigger = "parent_trigger"
        case type
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
        case status
        case condition
        case orders
        case meta
    }
}

public extension KiteClient {
    /// Retrieves active GTT triggers and other trigger states retained from the previous seven days.
    ///
    /// - Returns: Stored trigger definitions and their embedded order attempt details.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func gttTriggers() async throws -> [KiteGTTTrigger] {
        try await execute(KiteRequest(path: "/gtt/triggers"), as: [KiteGTTTrigger].self)
    }
}

public extension KiteClient {
    /// Retrieves a stored GTT trigger independently of the list's age and status window.
    ///
    /// - Parameters:
    ///   - id: A positive server trigger identifier.
    /// - Returns: The stored definition and lifecycle state, distinct from order execution.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func gttTrigger(id: Int64) async throws -> KiteGTTTrigger {
        try gttIdentifier(id)
        return try await execute(KiteRequest(path: "/gtt/triggers/\(id)"), as: KiteGTTTrigger.self)
    }
}

func gttIdentifier(_ id: Int64) throws {
    guard id > 0 else {
        throw KiteError.validation(
            field: "trigger_id", message: "Expected a positive trigger identifier",
        )
    }
}
