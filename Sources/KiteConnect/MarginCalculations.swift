//
//  MarginCalculations.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// A hypothetical order. Calculating margins never submits this order.
///
/// ## See Also
///
/// - <doc:Inspect-account-margins>
public struct KiteMarginOrder: Sendable, Encodable {
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
    /// Nonnegative finite hypothetical price, validated when requesting the estimate.
    public var price: Decimal
    /// Nonnegative finite hypothetical trigger price, validated when requesting the estimate.
    public var triggerPrice: Decimal

    /// Creates a hypothetical margin input. No request or trade is submitted.
    ///
    /// - Parameters:
    ///   - instrument: Exchange and trading symbol of the proposed instrument.
    ///   - transactionType: Proposed buy or sell direction.
    ///   - variety: Proposed variety, regular by default.
    ///   - product: Proposed margin product.
    ///   - orderType: Proposed pricing type.
    ///   - quantity: Positive quantity, checked when requesting an estimate.
    ///   - price: Nonnegative finite price, zero by default.
    ///   - triggerPrice: Nonnegative finite trigger price, zero by default.
    public init(
        instrument: KiteInstrumentIdentity, transactionType: KiteTransactionType,
        variety: KiteOrderVariety = .regular, product: KiteProduct, orderType: KiteOrderType,
        quantity: Int64, price: Decimal = 0, triggerPrice: Decimal = 0,
    ) {
        self.instrument = instrument
        self.transactionType = transactionType
        self.variety = variety
        self.product = product
        self.orderType = orderType
        self.quantity = quantity
        self.price = price
        self.triggerPrice = triggerPrice
    }

    enum CodingKeys: String, CodingKey {
        case exchange, variety, product, quantity, price
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case orderType = "order_type"
        case triggerPrice = "trigger_price"
    }

    /// Encodes the hypothetical order using Kite's request field names.
    /// - Parameter encoder: Encoder that receives the wire representation.
    /// - Throws: An error if the encoder cannot represent a field.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(instrument.exchange, forKey: .exchange)
        try c.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
        try c.encode(transactionType, forKey: .transactionType)
        try c.encode(variety, forKey: .variety)
        try c.encode(product, forKey: .product)
        try c.encode(orderType, forKey: .orderType)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(price, forKey: .price)
        try c.encode(triggerPrice, forKey: .triggerPrice)
    }
}

/// Goods and services tax amounts returned by a charge calculation.
public struct KiteCalculationGST: Decodable, Sendable, Equatable {
    /// Integrated goods and services tax amount reported by Kite.
    public let igst: Decimal
    /// Central goods and services tax amount reported by Kite.
    public let cgst: Decimal
    /// State goods and services tax amount reported by Kite.
    public let sgst: Decimal
    /// Total amount reported by Kite, retained without summing components locally.
    public let total: Decimal
}

/// Raw tax types preserve future server values, including the empty aggregate tax type.
public struct KiteCalculationCharges: Decodable, Sendable, Equatable {
    /// Securities or commodities transaction tax amount reported by Kite.
    public let transactionTax: Decimal
    /// Raw tax classification, including an empty string for an aggregate.
    public let transactionTaxType: String
    /// Exchange turnover charge amount reported by Kite.
    public let exchangeTurnoverCharge: Decimal
    /// SEBI turnover charge amount reported by Kite.
    public let sebiTurnoverCharge: Decimal
    /// Brokerage amount reported by Kite for the calculation.
    public let brokerage: Decimal
    /// Stamp duty amount reported by Kite for the calculation.
    public let stampDuty: Decimal
    /// Goods and services tax breakdown reported by Kite.
    public let gst: KiteCalculationGST
    /// Total amount reported by Kite, retained without summing components locally.
    public let total: Decimal
    enum CodingKeys: String, CodingKey {
        case brokerage, gst, total
        case transactionTax = "transaction_tax"
        case transactionTaxType = "transaction_tax_type"
        case exchangeTurnoverCharge = "exchange_turnover_charge"
        case sebiTurnoverCharge = "sebi_turnover_charge"
        case stampDuty = "stamp_duty"
    }
}

/// Realised and unrealised profit or loss returned with a margin estimate.
public struct KiteCalculationPnL: Decodable, Sendable, Equatable {
    /// Realised profit or loss reported by Kite as a decimal.
    public let realised: Decimal
    /// Unrealised profit or loss reported by Kite as a decimal.
    public let unrealised: Decimal
}

/// Full margin breakdown, also used for basket initial/final aggregate margins.
/// Aggregate exchange and trading symbol can be empty; no instrument identity is invented.
///
/// ## See Also
///
/// - <doc:Financial-values-and-portfolio-views>
public struct KiteCalculatedMargin: Decodable, Sendable, Equatable {
    /// Raw margin classification reported by Kite, including empty aggregate values.
    public let type: String
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Exchange reported by Kite, preserving unfamiliar raw values.
    public let exchange: KiteExchange
    /// SPAN margin component for futures and options reported by Kite.
    public let span: Decimal
    /// Exposure margin component reported by Kite.
    public let exposure: Decimal
    /// Option premium component reported by Kite.
    public let optionPremium: Decimal
    /// Additional margin component reported by Kite.
    public let additional: Decimal
    /// Bracket-order margin component reported by Kite.
    public let bo: Decimal
    /// Cash component reported by Kite, without local recomputation.
    public let cash: Decimal
    /// Value-at-risk margin component reported by Kite.
    public let valueAtRisk: Decimal
    /// Profit or loss reported by Kite, without local recalculation.
    public let pnl: KiteCalculationPnL
    /// Leverage factor reported by Kite as a decimal.
    public let leverage: Decimal
    /// Charge breakdown reported by Kite, retained without recomputation.
    public let charges: KiteCalculationCharges
    /// Total amount reported by Kite, retained without summing components locally.
    public let total: Decimal
    /// Instrument identity when exchange and trading symbol form a valid pair. Aggregate, malformed, or absent identities return nil.
    public var instrument: KiteInstrumentIdentity? {
        try? KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
    }

    enum CodingKeys: String, CodingKey {
        case type, exchange, span, exposure, additional, bo, cash, pnl, leverage, charges, total
        case tradingSymbol = "tradingsymbol"
        case optionPremium = "option_premium"
        case valueAtRisk = "var"
    }
}

public extension KiteClient {
    /// Estimates each hypothetical order against existing positions and open orders without submitting a trade.
    /// - Parameter orders: Nonempty hypothetical orders with positive quantities and nonnegative finite prices.
    /// - Returns: Full per-order margin breakdowns reported by Kite.
    /// - Throws: `KiteError.validation` for malformed input, or authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func orderMargins(_ orders: [KiteMarginOrder]) async throws -> [KiteCalculatedMargin] {
        try validateMarginOrders(orders)
        return try await execute(
            KiteRequest(
                method: .post, path: "/margins/orders", body: .json(JSONEncoder().encode(orders)),
            ),
            as: [KiteCalculatedMargin].self,
        )
    }
}

func validateMarginOrders(_ orders: [KiteMarginOrder]) throws {
    guard !orders.isEmpty else {
        throw KiteError.validation(field: "orders", message: "Supply at least one order")
    }
    for order in orders {
        for (field, value) in [
            ("transaction_type", order.transactionType.rawValue), ("variety", order.variety.rawValue),
            ("product", order.product.rawValue), ("order_type", order.orderType.rawValue),
        ] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            else {
                throw KiteError.validation(
                    field: field, message: "Expected a nonempty value without controls",
                )
            }
        }
        guard order.quantity > 0 else {
            throw KiteError.validation(field: "quantity", message: "Must be positive")
        }
        for (field, value) in [("price", order.price), ("trigger_price", order.triggerPrice)] {
            guard !value.isNaN, value >= 0 else {
                throw KiteError.validation(field: field, message: "Must be a nonnegative decimal")
            }
        }
    }
}

/// Full basket estimate with required initial, final, per-order, and charge breakdowns.
public struct KiteCalculatedBasketMargins: Decodable, Sendable, Equatable {
    /// Aggregate margin estimate before basket offsets are applied.
    public let initial: KiteCalculatedMargin
    /// Aggregate margin estimate after basket offsets are applied.
    public let final: KiteCalculatedMargin
    /// Individual order margin estimates reported for the basket.
    public let orders: [KiteCalculatedMargin]
    /// May omit transaction taxes for mixed tax types. Prefer individual order charges.
    public let charges: KiteCalculationCharges
}

public extension KiteClient {
    /// Estimates a hypothetical basket with full initial, final, and per-order margin breakdowns.
    /// - Parameters:
    ///   - orders: Nonempty hypothetical orders with positive quantities and nonnegative finite prices.
    ///   - considerPositions: Whether existing positions enter the estimate. Defaults to true.
    /// - Returns: Full basket margins. Mixed transaction-tax aggregates may omit tax amounts. Prefer individual order charges.
    /// - Throws: `KiteError.validation` for malformed input, or authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func basketMargins(_ orders: [KiteMarginOrder], considerPositions: Bool = true)
        async throws -> KiteCalculatedBasketMargins
    {
        try validateMarginOrders(orders)
        return try await execute(
            KiteRequest(
                method: .post, path: "/margins/basket",
                query: [.init("consider_positions", considerPositions ? "true" : "false")],
                body: .json(JSONEncoder().encode(orders)),
            ), as: KiteCalculatedBasketMargins.self,
        )
    }
}
