//
//  GTTRequests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Request condition: no response-only instrument token is sent to Kite.
public struct KiteGTTConditionRequest: Encodable, Sendable, Equatable {
    /// The exchange and trading symbol identifying the instrument without a catalogue lookup.
    public var instrument: KiteInstrumentIdentity
    /// The trigger prices in order-leg index order; single uses one and OCO uses two.
    public var triggerValues: [Decimal]
    /// The last traded price supplied with the trigger condition or basket.
    public var lastPrice: Decimal
    /// Creates a condition with indexed trigger prices and the supplied last traded price. Leg counts are checked on submission.
    ///
    /// - Parameters:
    ///   - instrument: The exchange and trading symbol for the trigger.
    ///   - triggerValues: One or two finite trigger prices in order-leg index order.
    ///   - lastPrice: The finite last traded price supplied with the definition.
    public init(instrument: KiteInstrumentIdentity, triggerValues: [Decimal], lastPrice: Decimal) {
        self.instrument = instrument
        self.triggerValues = triggerValues
        self.lastPrice = lastPrice
    }

    enum CodingKeys: String, CodingKey {
        case exchange
        case tradingSymbol = "tradingsymbol"
        case triggerValues = "trigger_values"
        case lastPrice = "last_price"
    }

    /// Encodes the instrument as exchange and tradingsymbol fields with the GTT definition.
    ///
    /// - Parameter encoder: The destination encoder for the embedded definition.
    /// - Throws: Any error raised while encoding the fields. Structural validation
    ///   belongs to submission, so encoding alone does not prove a valid GTT request.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instrument.exchange, forKey: .exchange)
        try container.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
        try container.encode(triggerValues, forKey: .triggerValues)
        try container.encode(lastPrice, forKey: .lastPrice)
    }
}

/// Embedded GTT order, distinct from standalone order placement. GTT supports LIMIT orders.
public struct KiteGTTOrderRequest: Encodable, Sendable, Equatable {
    /// The exchange and trading symbol identifying the instrument without a catalogue lookup.
    public var instrument: KiteInstrumentIdentity
    /// The buy or sell direction of the embedded or standalone order.
    public var transactionType: KiteTransactionType
    /// The order quantity in instrument units; submitted quantities must be positive.
    public var quantity: Int64
    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public var orderType: KiteOrderType
    /// The broker product used for the order or execution.
    public var product: KiteProduct
    /// The order price as a decimal value, distinct from its execution price.
    public var price: Decimal
    /// Creates an embedded order definition. Submission requires LIMIT, BUY or SELL, and a positive quantity.
    ///
    /// - Parameters:
    ///   - instrument: The exchange and trading symbol for this order leg.
    ///   - transactionType: BUY or SELL; unfamiliar values fail submission validation.
    ///   - quantity: The positive number of instrument units.
    ///   - orderType: The embedded pricing instruction; submission requires LIMIT.
    ///   - product: The nonempty broker product for this order.
    ///   - price: The finite LIMIT order price.
    public init(
        instrument: KiteInstrumentIdentity, transactionType: KiteTransactionType,
        quantity: Int64, orderType: KiteOrderType = .limit, product: KiteProduct, price: Decimal,
    ) {
        self.instrument = instrument
        self.transactionType = transactionType
        self.quantity = quantity
        self.orderType = orderType
        self.product = product
        self.price = price
    }

    enum CodingKeys: String, CodingKey {
        case exchange
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case quantity
        case orderType = "order_type"
        case product, price
    }

    /// Encodes the instrument as exchange and tradingsymbol fields with the GTT definition.
    ///
    /// - Parameter encoder: The destination encoder for the embedded definition.
    /// - Throws: Any error raised while encoding the fields. Structural validation
    ///   belongs to submission, so encoding alone does not prove a valid GTT request.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instrument.exchange, forKey: .exchange)
        try container.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
        try container.encode(transactionType, forKey: .transactionType)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(orderType, forKey: .orderType)
        try container.encode(product, forKey: .product)
        try container.encode(price, forKey: .price)
    }
}

/// Complete definition used for both creation and replacement-style modification.
/// Trigger values and orders correspond by array index; their order is preserved.
public struct KiteGTTRequest: Sendable, Equatable {
    /// The trigger shape determining whether one or two indexed order legs are required.
    public var type: KiteGTTType
    /// The comparison or trigger condition associated with this definition.
    public var condition: KiteGTTConditionRequest
    /// The embedded order legs in the same index order as the trigger values.
    public var orders: [KiteGTTOrderRequest]
    /// Creates a complete trigger definition. Single requires one value and order; two-leg requires two of each.
    ///
    /// - Parameters:
    ///   - type: Single for one leg or twoLeg for two indexed OCO legs.
    ///   - condition: The trigger instrument, indexed prices, and last traded price.
    ///   - orders: The complete order legs in trigger-value index order.
    public init(type: KiteGTTType, condition: KiteGTTConditionRequest, orders: [KiteGTTOrderRequest]) {
        self.type = type
        self.condition = condition
        self.orders = orders
    }

    func parameters() throws -> [KiteParameter] {
        let count: Int
        switch type {
        case .single: count = 1
        case .twoLeg: count = 2
        case .unknown:
            throw KiteError.validation(field: "type", message: "Expected single or two-leg")
        }
        guard condition.triggerValues.count == count, orders.count == count else {
            throw KiteError.validation(
                field: "orders",
                message: "Trigger values and orders must match the trigger type's leg count",
            )
        }
        for value in condition.triggerValues + [condition.lastPrice] + orders.map(\.price) {
            guard !value.isNaN else {
                throw KiteError.validation(field: "price", message: "Expected finite decimal values")
            }
        }
        for order in orders {
            guard order.orderType == .limit else {
                throw KiteError.validation(field: "order_type", message: "GTT orders require LIMIT")
            }
            guard order.transactionType == .buy || order.transactionType == .sell else {
                throw KiteError.validation(field: "transaction_type", message: "Expected BUY or SELL")
            }
            guard order.quantity > 0 else {
                throw KiteError.validation(field: "quantity", message: "Expected a positive quantity")
            }
            guard !order.product.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !order.product.rawValue.unicodeScalars.contains(where: {
                      CharacterSet.controlCharacters.contains($0)
                  })
            else {
                throw KiteError.validation(
                    field: "product", message: "Expected a nonempty product without controls",
                )
            }
        }
        let encoder = JSONEncoder()
        return try [
            .init("type", type.rawValue),
            .init("condition", String(decoding: encoder.encode(condition), as: UTF8.self)),
            .init("orders", String(decoding: encoder.encode(orders), as: UTF8.self)),
        ]
    }
}

/// Acknowledges a trigger mutation; does not establish that an embedded order executed.
public struct KiteGTTReceipt: Decodable, Sendable, Equatable {
    /// The positive identifier acknowledged by Kite; it does not establish order execution.
    public let triggerID: Int64
    enum CodingKeys: String, CodingKey { case triggerID = "trigger_id" }

    /// Decodes a positive trigger ID; zero and negative acknowledgement IDs fail.
    ///
    /// - Parameter decoder: The decoder positioned at the response value, outside any Kite envelope.
    /// - Throws: A decoding error for missing or malformed required values. Optional
    ///   fields allow absence or null, but malformed present values fail.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        triggerID = try values.decode(Int64.self, forKey: .triggerID)
        guard triggerID > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .triggerID, in: values, debugDescription: "Expected a positive trigger identifier",
            )
        }
    }
}

public extension KiteClient {
    /// Creates a GTT definition once. See <doc:Manage-GTT-triggers>.
    ///
    /// - Parameters:
    ///   - trigger: A complete single or two-leg definition with matching indexed LIMIT order legs.
    /// - Returns: A positive trigger identifier acknowledging the mutation, not an order fill.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func createGTT(_ trigger: KiteGTTRequest) async throws -> KiteGTTReceipt {
        try await execute(
            KiteRequest(
                method: .post, path: "/gtt/triggers",
                body: .form(trigger.parameters()), isTradingMutation: true,
            ), as: KiteGTTReceipt.self,
        )
    }
}

public extension KiteClient {
    /// Replaces a GTT definition once. Fetch current state before constructing the complete desired definition.
    ///
    /// - Parameters:
    ///   - id: A positive server trigger identifier.
    ///   - trigger: The complete replacement definition; omitted existing state is not merged locally.
    /// - Returns: A trigger acknowledgement, not proof of embedded order execution.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func modifyGTT(id: Int64, trigger: KiteGTTRequest) async throws -> KiteGTTReceipt {
        try gttIdentifier(id)
        return try await execute(
            KiteRequest(
                method: .put, path: "/gtt/triggers/\(id)",
                body: .form(trigger.parameters()), isTradingMutation: true,
            ), as: KiteGTTReceipt.self,
        )
    }

    /// Deletes a stored GTT trigger once, without automatic resubmission.
    ///
    /// - Parameters:
    ///   - id: A positive server trigger identifier.
    /// - Returns: A trigger acknowledgement. Read current state to reconcile an uncertain response.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func deleteGTT(id: Int64) async throws -> KiteGTTReceipt {
        try gttIdentifier(id)
        return try await execute(
            KiteRequest(
                method: .delete, path: "/gtt/triggers/\(id)",
                isTradingMutation: true,
            ), as: KiteGTTReceipt.self,
        )
    }
}
