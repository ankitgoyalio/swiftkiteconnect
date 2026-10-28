//
//  OrderChanges.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Omitted fields remain unchanged. Existing order state and broker eligibility belong to Kite.
public struct KiteOrderModification: Sendable {
    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public var orderType: KiteOrderType?
    /// The order quantity in instrument units; submitted quantities must be positive.
    public var quantity: Int64?
    /// The order price as a decimal value, distinct from its execution price.
    public var price: Decimal?
    /// The stop-loss trigger price, separate from the order limit price.
    public var triggerPrice: Decimal?
    /// The quantity disclosed to the market; supplied values must be nonnegative.
    public var disclosedQuantity: Int64?
    /// The order lifetime instruction reported or submitted to Kite.
    public var validity: KiteOrderMutationValidity?
    /// The time-to-live in minutes; standalone mutations require a positive supplied value.
    public var validityTTL: Int?
    /// The market-protection value; standalone requests accept -1 or a percentage greater than zero through 100.
    public var marketProtection: Decimal?
    /// Creates an empty change set; set at least one field before submitting a modification.
    public init() {}
}

public extension KiteClient {
    /// Submits only changed fields for an existing order once. Omitted fields remain unchanged.
    ///
    /// - Parameters:
    ///   - orderID: The nonempty safe order identifier to modify.
    ///   - variety: The route matching the original order, defaulting to regular.
    ///   - parentOrderID: The parent identifier for a cover-order child, when required.
    ///   - changes: At least one changed field. Eligibility and current order state remain server-owned.
    /// - Returns: A submission receipt, not confirmation that the exchange applied the change.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func modifyOrder(
        orderID: String, variety: KiteOrderMutationVariety = .regular,
        parentOrderID: String? = nil, changes: KiteOrderModification,
    ) async throws -> KiteOrderMutationReceipt {
        try mutationIdentifier(orderID, field: "order_id")
        if let parentOrderID {
            try mutationIdentifier(parentOrderID, field: "parent_order_id")
        }
        if let type = changes.orderType {
            try mutationText(type.rawValue, field: "order_type")
        }
        try mutationNumbers(
            quantity: changes.quantity, price: changes.price, trigger: changes.triggerPrice,
            disclosed: changes.disclosedQuantity, ttl: changes.validityTTL,
            protection: changes.marketProtection,
        )
        var fields: [KiteParameter] = []
        if let value = changes.orderType {
            fields.append(.init("order_type", value.rawValue))
        }
        if let value = changes.quantity {
            fields.append(.init("quantity", String(value)))
        }
        if let value = changes.price {
            fields.append(.init("price", value.description))
        }
        if let value = changes.triggerPrice {
            fields.append(.init("trigger_price", value.description))
        }
        if let value = changes.disclosedQuantity {
            fields.append(.init("disclosed_quantity", String(value)))
        }
        if let value = changes.validity {
            fields.append(.init("validity", value.rawValue))
        }
        if let value = changes.validityTTL {
            fields.append(.init("validity_ttl", String(value)))
        }
        if let value = changes.marketProtection {
            fields.append(.init("market_protection", value.description))
        }
        guard !fields.isEmpty else {
            throw mutationValidation("changes", "Supply at least one changed field")
        }
        if let parentOrderID {
            fields.append(.init("parent_order_id", parentOrderID))
        }
        return try await execute(
            KiteRequest(
                method: .put, path: "/orders/\(variety.rawValue)/\(orderID)",
                body: .form(fields), isTradingMutation: true,
            ), as: KiteOrderMutationReceipt.self,
        )
    }

    /// Requests cancellation once. For a cover-order second leg, cancellation can exit the position.
    ///
    /// - Parameters:
    ///   - orderID: The nonempty safe order identifier to cancel.
    ///   - variety: The route matching the original order, defaulting to regular.
    ///   - parentOrderID: The cover-order parent identifier, sent in the cancellation query when supplied.
    /// - Returns: A submission receipt. Inspect order state and trades for final cancellation and earlier partial fills.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func cancelOrder(
        orderID: String, variety: KiteOrderMutationVariety = .regular,
        parentOrderID: String? = nil,
    ) async throws -> KiteOrderMutationReceipt {
        try mutationIdentifier(orderID, field: "order_id")
        if let parentOrderID {
            try mutationIdentifier(parentOrderID, field: "parent_order_id")
        }
        return try await execute(
            KiteRequest(
                method: .delete, path: "/orders/\(variety.rawValue)/\(orderID)",
                query: parentOrderID.map { [.init("parent_order_id", $0)] } ?? [],
                isTradingMutation: true,
            ), as: KiteOrderMutationReceipt.self,
        )
    }
}

/// A per-slice rejection is confirmed, while other slices may already have been placed.
public enum KiteOrderSliceResult: Decodable, Sendable, Equatable {
    /// A slice submission receipt, which does not establish exchange execution.
    case placed(KiteOrderMutationReceipt)
    /// A confirmed rejection of this slice; other slices may already have been submitted.
    case rejected(KiteOrderSliceRejection)
    enum CodingKeys: String, CodingKey {
        case error
        case orderID = "order_id"
    }

    /// Decodes KiteOrderSliceResult from the supplied decoder, throwing when required fields are missing or malformed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.error) {
            guard !container.contains(.orderID) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .error, in: container, debugDescription: "Ambiguous slice outcome",
                )
            }
            self = try .rejected(container.decode(KiteOrderSliceRejection.self, forKey: .error))
        } else {
            self = try .placed(KiteOrderMutationReceipt(from: decoder))
        }
    }
}

/// A confirmed rejection of one slice, retaining the server category and JSON details.
public struct KiteOrderSliceRejection: Decodable, Sendable, Equatable {
    /// The numeric rejection code supplied for this individual order slice.
    public let code: Int
    /// The raw server error category for this rejected slice.
    public let errorType: String
    /// The server explanation of why this individual slice was rejected.
    public let message: String
    /// The rejection details with JSON structure and decimal numbers preserved.
    public let data: KiteOrderMutationJSONValue
    enum CodingKeys: String, CodingKey {
        case code
        case errorType = "error_type"
        case message, data
    }
}

/// Lossless JSON structure for broker-provided slice rejection details. Numbers use Decimal.
public indirect enum KiteOrderMutationJSONValue: Decodable, Sendable, Equatable {
    /// An explicit JSON null value, distinct from missing object keys.
    case null
    /// A JSON Boolean preserved as its original true or false value.
    case bool(Bool)
    /// A JSON number decoded as Decimal without conversion through Double.
    case number(Decimal)
    /// A JSON string preserved without interpreting its contents.
    case string(String)
    /// A JSON array retaining the server order of its child values.
    case array([KiteOrderMutationJSONValue])
    /// A JSON object retaining each named child value without a fixed schema.
    case object([String: KiteOrderMutationJSONValue])
    /// Decodes KiteOrderMutationJSONValue from the supplied decoder, throwing when required fields are missing or malformed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([KiteOrderMutationJSONValue].self) {
            self = .array(value)
        } else {
            self = try .object(container.decode([String: KiteOrderMutationJSONValue].self))
        }
    }
}

func mutationValidation(_ field: String, _ message: String) -> KiteError {
    .validation(field: field, message: message)
}

func mutationText(_ value: String, field: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else {
        throw mutationValidation(field, "Expected nonempty text without control characters")
    }
}

func mutationIdentifier(_ value: String, field: String) throws {
    try mutationText(value, field: field)
    guard !value.contains(".."), !value.contains(where: { $0.isWhitespace || "/\\?#%".contains($0) })
    else {
        throw mutationValidation(field, "Expected a single order identifier")
    }
}

func mutationNumbers(
    quantity: Int64?, price: Decimal?, trigger: Decimal?,
    disclosed: Int64?, ttl: Int?, protection: Decimal?,
) throws {
    if let quantity, quantity <= 0 {
        throw mutationValidation("quantity", "Must be positive")
    }
    for (field, value) in [("price", price), ("trigger_price", trigger)] {
        if let value, value.isNaN || value < 0 {
            throw mutationValidation(field, "Must be finite and nonnegative")
        }
    }
    if let disclosed, disclosed < 0 {
        throw mutationValidation("disclosed_quantity", "Must be nonnegative")
    }
    if let ttl, ttl <= 0 {
        throw mutationValidation("validity_ttl", "Must be positive minutes")
    }
    if let protection,
       protection.isNaN || !(protection == -1 || (protection > 0 && protection <= 100))
    {
        throw mutationValidation(
            "market_protection", "Expected -1 or a percentage greater than 0 and at most 100",
        )
    }
}
