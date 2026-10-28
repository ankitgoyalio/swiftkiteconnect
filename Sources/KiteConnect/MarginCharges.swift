//
//  MarginCharges.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Compact mode guarantees only the total. Additional documented fields are retained if supplied.
public struct KiteCompactMargin: Decodable, Sendable, Equatable {
    /// Raw margin classification reported by Kite, including empty aggregate values. Nil means the field was absent or null.
    public let type: String?
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue. Nil means the field was absent or null.
    public let tradingSymbol: String?
    /// Exchange reported by Kite, preserving unfamiliar raw values. Nil means the field was absent or null.
    public let exchange: KiteExchange?
    /// SPAN margin component for futures and options reported by Kite. Nil means the field was absent or null.
    public let span: Decimal?
    /// Exposure margin component reported by Kite. Nil means the field was absent or null.
    public let exposure: Decimal?
    /// Option premium component reported by Kite. Nil means the field was absent or null.
    public let optionPremium: Decimal?
    /// Additional margin component reported by Kite. Nil means the field was absent or null.
    public let additional: Decimal?
    /// Bracket-order margin component reported by Kite. Nil means the field was absent or null.
    public let bo: Decimal?
    /// Cash component reported by Kite, without local recomputation. Nil means the field was absent or null.
    public let cash: Decimal?
    /// Value-at-risk margin component reported by Kite. Nil means the field was absent or null.
    public let valueAtRisk: Decimal?
    /// Profit or loss reported by Kite, without local recalculation. Nil means the field was absent or null.
    public let pnl: KiteCalculationPnL?
    /// Leverage factor reported by Kite as a decimal. Nil means the field was absent or null.
    public let leverage: Decimal?
    /// Charge breakdown reported by Kite, retained without recomputation. Nil means the field was absent or null.
    public let charges: KiteCalculationCharges?
    /// Total amount reported by Kite, retained without summing components locally.
    public let total: Decimal
    /// Instrument identity when exchange and trading symbol form a valid pair. Aggregate, malformed, or absent identities return nil.
    public var instrument: KiteInstrumentIdentity? {
        guard let exchange, let tradingSymbol else { return nil }
        return try? KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
    }

    enum CodingKeys: String, CodingKey {
        case type, exchange, span, exposure, additional, bo, cash, pnl, leverage, charges, total
        case tradingSymbol = "tradingsymbol"
        case optionPremium = "option_premium"
        case valueAtRisk = "var"
    }
}

/// Compact basket estimate with required totals and optional per-order and charge detail.
public struct KiteCompactBasketMargins: Decodable, Sendable, Equatable {
    /// Aggregate margin estimate before basket offsets are applied.
    public let initial: KiteCompactMargin
    /// Aggregate margin estimate after basket offsets are applied.
    public let final: KiteCompactMargin
    /// Individual order margin estimates reported for the basket. Nil means the field was absent or null.
    public let orders: [KiteCompactMargin]?
    /// Charge breakdown reported by Kite, retained without recomputation. Nil means the field was absent or null.
    public let charges: KiteCalculationCharges?
}

public extension KiteClient {
    /// Estimates hypothetical orders in compact mode without submitting trades.
    /// - Parameter orders: Nonempty hypothetical orders with positive quantities and nonnegative finite prices.
    /// - Returns: Per-order estimates requiring only total. Other breakdown fields may be absent.
    /// - Throws: `KiteError.validation` for malformed input, or authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func compactOrderMargins(_ orders: [KiteMarginOrder]) async throws -> [KiteCompactMargin] {
        try validateMarginOrders(orders)
        return try await execute(
            KiteRequest(
                method: .post, path: "/margins/orders", query: [.init("mode", "compact")],
                body: .json(JSONEncoder().encode(orders)),
            ), as: [KiteCompactMargin].self,
        )
    }

    /// Estimates a hypothetical basket in compact mode without submitting trades.
    /// - Parameters:
    ///   - orders: Nonempty hypothetical orders with positive quantities and nonnegative finite prices.
    ///   - considerPositions: Whether existing positions enter the estimate. Defaults to true.
    /// - Returns: Initial and final estimates requiring only totals. Orders and charges may be absent.
    /// - Throws: `KiteError.validation` for malformed input, or authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func compactBasketMargins(_ orders: [KiteMarginOrder], considerPositions: Bool = true)
        async throws -> KiteCompactBasketMargins
    {
        try validateMarginOrders(orders)
        return try await execute(
            KiteRequest(
                method: .post, path: "/margins/basket",
                query: [
                    .init("consider_positions", considerPositions ? "true" : "false"),
                    .init("mode", "compact"),
                ],
                body: .json(JSONEncoder().encode(orders)),
            ), as: KiteCompactBasketMargins.self,
        )
    }
}

/// Virtual contract-note input. `orderID` can be any nonempty hypothetical identifier.
public struct KiteChargeOrder: Sendable, Encodable {
    /// Hypothetical identifier for this calculation. No actual order is required.
    public var orderID: String
    /// Exchange and trading symbol for the request. No instrument token is required.
    public var instrument: KiteInstrumentIdentity
    /// Proposed buy or sell direction. Nonblank wire text is checked when requesting the estimate.
    public var transactionType: KiteTransactionType
    /// Proposed order variety, regular by default. Validated when requesting the estimate.
    public var variety: KiteOrderVariety
    /// Proposed margin product. Kite decides current eligibility when it calculates the estimate.
    public var product: KiteProduct
    /// Proposed pricing type. Nonblank wire text is checked when requesting the estimate.
    public var orderType: KiteOrderType
    /// Positive hypothetical order quantity, validated when the calculation is requested.
    public var quantity: Int64
    /// Positive finite hypothetical average price, validated when requesting the calculation.
    public var averagePrice: Decimal

    /// Creates a hypothetical contract-note input without requiring an actual order.
    ///
    /// - Parameters:
    ///   - orderID: Any nonblank hypothetical identifier without control characters.
    ///   - instrument: Exchange and trading symbol of the proposed instrument.
    ///   - transactionType: Proposed buy or sell direction.
    ///   - variety: Proposed variety, regular by default.
    ///   - product: Proposed margin product.
    ///   - orderType: Proposed pricing type.
    ///   - quantity: Positive hypothetical quantity.
    ///   - averagePrice: Positive finite average price for the estimate.
    public init(
        orderID: String, instrument: KiteInstrumentIdentity, transactionType: KiteTransactionType,
        variety: KiteOrderVariety = .regular, product: KiteProduct, orderType: KiteOrderType,
        quantity: Int64, averagePrice: Decimal,
    ) {
        self.orderID = orderID
        self.instrument = instrument
        self.transactionType = transactionType
        self.variety = variety
        self.product = product
        self.orderType = orderType
        self.quantity = quantity
        self.averagePrice = averagePrice
    }

    enum CodingKeys: String, CodingKey {
        case exchange, variety, product, quantity
        case orderID = "order_id"
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case orderType = "order_type"
        case averagePrice = "average_price"
    }

    /// Encodes the hypothetical order using Kite's request field names.
    /// - Parameter encoder: Encoder that receives the wire representation.
    /// - Throws: An error if the encoder cannot represent a field.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(orderID, forKey: .orderID)
        try c.encode(instrument.exchange, forKey: .exchange)
        try c.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
        try c.encode(transactionType, forKey: .transactionType)
        try c.encode(variety, forKey: .variety)
        try c.encode(product, forKey: .product)
        try c.encode(orderType, forKey: .orderType)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(averagePrice, forKey: .averagePrice)
    }
}

/// Virtual contract-note result for a hypothetical order. No trade is submitted.
public struct KiteCalculatedOrderCharges: Decodable, Sendable, Equatable {
    /// Not present in the documented response; retained if returned by the server.
    public let orderID: String?
    /// Exchange reported by Kite, preserving unfamiliar raw values.
    public let exchange: KiteExchange
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Buy or sell direction, preserving unfamiliar response values.
    public let transactionType: KiteTransactionType
    /// Order variety used for the request or reported by Kite.
    public let variety: KiteOrderVariety
    /// Margin product associated with this holding, position, or calculation.
    public let product: KiteProduct
    /// Order pricing type used for the request or reported by Kite.
    public let orderType: KiteOrderType
    /// Quantity reported by Kite, retained without rounding or recomputation.
    public let quantity: Int64
    /// Price reported by Kite in decimal form, without recomputation.
    public let price: Decimal
    /// Charge breakdown reported by Kite, retained without recomputation.
    public let charges: KiteCalculationCharges
    /// Instrument identity when exchange and trading symbol form a valid pair. Aggregate, malformed, or absent identities return nil.
    public var instrument: KiteInstrumentIdentity? {
        try? KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
    }

    enum CodingKeys: String, CodingKey {
        case exchange, variety, product, quantity, price, charges
        case orderID = "order_id"
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case orderType = "order_type"
    }
}

public extension KiteClient {
    /// Calculates a virtual contract note without requiring or placing an actual order.
    /// - Parameter orders: Nonempty hypothetical orders with nonblank identifiers, positive quantities, and positive finite average prices.
    /// - Returns: Per-order charge breakdowns. Response order identifiers may be absent.
    /// - Throws: `KiteError.validation` for malformed input, or authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func orderCharges(_ orders: [KiteChargeOrder]) async throws -> [KiteCalculatedOrderCharges] {
        try validateMarginOrders(
            orders.map {
                KiteMarginOrder(
                    instrument: $0.instrument, transactionType: $0.transactionType,
                    variety: $0.variety, product: $0.product, orderType: $0.orderType, quantity: $0.quantity,
                )
            },
        )
        for order in orders {
            guard !order.orderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !order.orderID.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            else {
                throw KiteError.validation(
                    field: "order_id", message: "Expected a nonempty identifier without controls",
                )
            }
            guard !order.averagePrice.isNaN, order.averagePrice > 0 else {
                throw KiteError.validation(field: "average_price", message: "Must be a positive decimal")
            }
        }
        return try await execute(
            KiteRequest(
                method: .post, path: "/charges/orders", body: .json(JSONEncoder().encode(orders)),
            ),
            as: [KiteCalculatedOrderCharges].self,
        )
    }
}
