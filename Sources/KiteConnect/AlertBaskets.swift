//
//  AlertBaskets.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// ATO basket. Read responses can omit name, type, tags, and item action fields.
/// Keep these absent values when modifying a fetched basket; do not fabricate server metadata.
public struct KiteAlertBasket: Codable, Sendable, Equatable {
    /// The application-supplied display name for this alert or basket.
    public var name: String?
    /// The optional basket type; new baskets use the alert wire value.
    public var type: String?
    /// The application tags preserved as supplied by the server or basket definition.
    public var tags: [String]?
    /// The basket order entries; a submitted basket requires at least one item.
    public var items: [KiteAlertBasketItem]

    /// Creates an alert basket with the alert type and supplied items and tags. Submission requires at least one item.
    ///
    /// - Parameters:
    ///   - name: The nonempty name of a newly constructed basket.
    ///   - items: The complete basket order items; submission requires at least one.
    ///   - tags: The basket tags, empty by default.
    public init(name: String, items: [KiteAlertBasketItem], tags: [String] = []) {
        self.name = name
        type = "alert"
        self.tags = tags
        self.items = items
    }
}

/// One basket order entry, with optional server metadata preserved when absent in reads.
public struct KiteAlertBasketItem: Codable, Sendable, Equatable {
    /// The optional item action; new basket items use the insert wire value.
    public var type: String?
    /// The numeric server identifier for this trigger or basket item.
    public var id: Int64?
    /// The numeric instrument token supplied by Kite; tokens may be reused after expiry.
    public var instrumentToken: UInt32?
    /// The trading symbol within the specified exchange.
    public var tradingSymbol: String
    /// The exchange on which the instrument is identified.
    public var exchange: KiteExchange
    /// The basket item weight as supplied; the construction default is 10000.
    public var weight: Decimal
    /// The basket-specific order parameters, distinct from standalone order placement.
    public var params: KiteAlertOrderParameters

    /// Creates an insert action with the supplied instrument and basket parameters. The default weight is 10000.
    ///
    /// - Parameters:
    ///   - tradingSymbol: The trading symbol within the supplied exchange.
    ///   - exchange: The exchange identifying the instrument.
    ///   - weight: The finite basket weight, defaulting to 10000.
    ///   - params: The basket-specific order definition.
    public init(
        tradingSymbol: String, exchange: KiteExchange, weight: Decimal = 10000,
        params: KiteAlertOrderParameters,
    ) {
        type = "insert"
        self.tradingSymbol = tradingSymbol
        self.exchange = exchange
        self.weight = weight
        self.params = params
    }

    enum CodingKeys: String, CodingKey {
        case type, id, exchange, weight, params
        case instrumentToken = "instrument_token"
        case tradingSymbol = "tradingsymbol"
    }
}

/// Basket-specific wire parameters, distinct from standalone order placement.
/// Zero TTL/iceberg fields and plural tags are documented here; standalone order rules do not apply.
public struct KiteAlertOrderParameters: Codable, Sendable, Equatable {
    /// The buy or sell direction of the embedded or standalone order.
    public var transactionType: KiteTransactionType
    /// The broker product used for the order or execution.
    public var product: KiteProduct
    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public var orderType: KiteOrderType
    /// The order lifetime instruction reported or submitted to Kite.
    public var validity: KiteOrderValidity
    /// The basket lifetime in minutes; zero is accepted in basket definitions.
    public var validityTTL: Int
    /// The positive number of instrument units for this basket order.
    public var quantity: Int64
    /// The finite nonnegative basket order price; construction defaults to zero.
    public var price: Decimal
    /// The stop-loss trigger price, separate from the order limit price.
    public var triggerPrice: Decimal
    /// The quantity disclosed to the market; supplied values must be nonnegative.
    public var disclosedQuantity: Int64
    /// The last traded price supplied with the trigger condition or basket.
    public var lastPrice: Decimal?
    /// The order routing variety, such as regular, after-market, or cover.
    public var variety: KiteOrderVariety
    /// The application tags preserved as supplied by the server or basket definition.
    public var tags: [String]
    /// The basket square-off value preserved without inferred standalone order rules.
    public var squareoff: Decimal
    /// The basket stop-loss value preserved as supplied.
    public var stoploss: Decimal
    /// The basket trailing stop-loss value preserved as supplied.
    public var trailingStoploss: Decimal
    /// The optional basket iceberg count; zero is accepted without standalone placement rules.
    public var icebergLegs: Int?
    /// The optional basket protection value; -1 is documented and only finiteness is checked.
    public var marketProtection: Decimal?
    /// The optional nested target and stop-loss definition of this basket order.
    public var gtt: KiteAlertBasketGTT?

    /// Creates basket parameters with DAY validity, regular variety, zero prices, and automatic market protection of -1.
    ///
    /// - Parameters:
    ///   - transactionType: The order direction encoded in basket parameters.
    ///   - product: The broker product encoded in basket parameters.
    ///   - orderType: The pricing instruction encoded in basket parameters.
    ///   - quantity: The positive number of instrument units.
    public init(
        transactionType: KiteTransactionType, product: KiteProduct, orderType: KiteOrderType,
        quantity: Int64,
    ) {
        self.transactionType = transactionType
        self.product = product
        self.orderType = orderType
        self.quantity = quantity
        validity = .day
        validityTTL = 1
        price = 0
        triggerPrice = 0
        disclosedQuantity = 0
        lastPrice = 0
        variety = .regular
        tags = []
        squareoff = 0
        stoploss = 0
        trailingStoploss = 0
        icebergLegs = 0
        marketProtection = -1
    }

    enum CodingKeys: String, CodingKey {
        case product, validity, quantity, price, variety, tags, squareoff, stoploss, gtt
        case transactionType = "transaction_type"
        case orderType = "order_type"
        case validityTTL = "validity_ttl"
        case triggerPrice = "trigger_price"
        case disclosedQuantity = "disclosed_quantity"
        case lastPrice = "last_price"
        case trailingStoploss = "trailing_stoploss"
        case icebergLegs = "iceberg_legs"
        case marketProtection = "market_protection"
    }
}

/// Nested target/stoploss values shown in the documented retrieved ATO basket.
public struct KiteAlertBasketGTT: Codable, Sendable, Equatable {
    /// The nested basket GTT target value, distinct from a standalone GTT request.
    public var target: Decimal
    /// The basket stop-loss value preserved as supplied.
    public var stoploss: Decimal
    /// Creates nested basket target and stop-loss values. Submitted values must be finite and nonnegative.
    ///
    /// - Parameters:
    ///   - target: The finite nonnegative target value.
    ///   - stoploss: The finite nonnegative stop-loss value.
    public init(target: Decimal, stoploss: Decimal) {
        self.target = target
        self.stoploss = stoploss
    }
}

extension KiteAlertBasket {
    func validate() throws {
        if let name {
            try alertText(name, field: "basket.name")
        }
        if let type {
            try alertText(type, field: "basket.type")
        }
        for tag in tags ?? [] {
            try alertText(tag, field: "basket.tags")
        }
        guard !items.isEmpty else {
            throw KiteError.validation(field: "basket.items", message: "Expected at least one order")
        }
        for item in items {
            if let type = item.type {
                try alertText(type, field: "basket.items.type")
            }
            try alertText(item.tradingSymbol, field: "basket.items.tradingsymbol")
            try alertText(item.exchange.rawValue, field: "basket.items.exchange")
            try basketDecimal(item.weight, field: "weight", nonnegative: false)
            let params = item.params
            for (field, value) in [
                ("transaction_type", params.transactionType.rawValue), ("product", params.product.rawValue),
                ("order_type", params.orderType.rawValue), ("validity", params.validity.rawValue),
                ("variety", params.variety.rawValue),
            ] {
                try alertText(value, field: "basket.items.params.\(field)")
            }
            guard params.quantity > 0 else {
                throw KiteError.validation(
                    field: "basket.items.params.quantity", message: "Must be positive",
                )
            }
            for (field, value) in [
                ("validity_ttl", params.validityTTL),
                ("iceberg_legs", params.icebergLegs ?? 0),
            ] where value < 0 {
                throw KiteError.validation(
                    field: "basket.items.params.\(field)", message: "Must be nonnegative",
                )
            }
            guard params.disclosedQuantity >= 0 else {
                throw KiteError.validation(
                    field: "basket.items.params.disclosed_quantity", message: "Must be nonnegative",
                )
            }
            for (field, value) in [
                ("price", params.price), ("trigger_price", params.triggerPrice),
                ("last_price", params.lastPrice), ("squareoff", params.squareoff),
                ("stoploss", params.stoploss), ("trailing_stoploss", params.trailingStoploss),
                ("gtt.target", params.gtt?.target), ("gtt.stoploss", params.gtt?.stoploss),
            ] {
                if let value {
                    try basketDecimal(value, field: field)
                }
            }
            if let protection = params.marketProtection {
                // The ATO docs show -1 but do not publish a range; do not import standalone order rules.
                try basketDecimal(protection, field: "market_protection", nonnegative: false)
            }
            for tag in params.tags {
                try alertText(tag, field: "basket.items.params.tags")
            }
        }
    }
}

private func basketDecimal(_ value: Decimal, field: String, nonnegative: Bool = true) throws {
    guard !value.isNaN, !nonnegative || value >= 0 else {
        throw KiteError.validation(
            field: "basket.items.params.\(field)",
            message: nonnegative ? "Must be finite and nonnegative" : "Must be finite",
        )
    }
}
