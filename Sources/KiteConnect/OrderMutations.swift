//
//  OrderMutations.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Request varieties in the release's orders documentation snapshot.
public enum KiteOrderMutationVariety: String, Sendable, CaseIterable {
    /// The regular standalone order route used for ordinary orders.
    case regular
    /// The after-market order route encoded as amo on the wire.
    case amo
    /// The cover order route with a linked protective order leg.
    case co
    /// The iceberg variety divides the order into configured legs.
    case iceberg
    /// The auction variety requires a supplied auction session number.
    case auction
}

/// The buy or sell direction accepted by standalone order mutations.
public enum KiteOrderMutationSide: String, Sendable {
    /// A purchase direction encoded as the BUY wire value.
    case buy = "BUY"
    /// A sale direction encoded as the SELL wire value.
    case sell = "SELL"
}

/// The DAY, IOC, and TTL lifetime instructions accepted by standalone mutations.
public enum KiteOrderMutationValidity: String, Sendable {
    /// The DAY instruction keeps the order valid for the trading day.
    case day = "DAY"
    /// The IOC instruction executes available quantity and cancels the remainder.
    case ioc = "IOC"
    /// The TTL instruction uses a supplied lifetime in minutes.
    case ttl = "TTL"
}

/// A standalone placement definition validated before one submission attempt. See <doc:Manage-orders>.
public struct KiteOrderPlacement: Sendable {
    /// The order routing variety, such as regular, after-market, or cover.
    public var variety: KiteOrderMutationVariety = .regular
    /// The trading symbol within the specified exchange.
    public var tradingSymbol: String
    /// The exchange on which the instrument is identified.
    public var exchange: KiteExchange
    /// The buy or sell direction of the embedded or standalone order.
    public var transactionType: KiteOrderMutationSide
    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public var orderType: KiteOrderType
    /// The order quantity in instrument units; submitted quantities must be positive.
    public var quantity: Int64
    /// The broker product used for the order or execution.
    public var product: KiteProduct
    /// The order price as a decimal value, distinct from its execution price.
    public var price: Decimal?
    /// The order lifetime instruction reported or submitted to Kite.
    public var validity: KiteOrderMutationValidity?
    /// The stop-loss trigger price, separate from the order limit price.
    public var triggerPrice: Decimal?
    /// The quantity disclosed to the market; supplied values must be nonnegative.
    public var disclosedQuantity: Int64?
    /// The time-to-live in minutes; standalone mutations require a positive supplied value.
    public var validityTTL: Int?
    /// The number of iceberg legs; standalone iceberg placement requires 2 through 50.
    public var icebergLegs: Int?
    /// The positive quantity per iceberg leg, required for iceberg placement.
    public var icebergQuantity: Int64?
    /// The auction session identifier; auction placement requires a nonempty value.
    public var auctionNumber: String?
    /// -1 requests automatic protection; otherwise a percentage greater than 0 and at most 100.
    public var marketProtection: Decimal?
    /// Whether Kite should split the order into slices; every returned slice needs inspection.
    public var autoslice: Bool?
    /// An application tag of 1 through 20 ASCII alphanumeric characters; it is not an idempotency key.
    public var tag: String?

    /// Creates a placement with regular variety and omitted optional fields. Configure required price and trigger fields before submission.
    ///
    /// - Parameters:
    ///   - tradingSymbol: The trading symbol within the supplied exchange.
    ///   - exchange: The exchange identifying the instrument.
    ///   - transactionType: The BUY or SELL direction.
    ///   - orderType: The pricing instruction. LIMIT and SL require a price before submission.
    ///   - quantity: The positive number of instrument units.
    ///   - product: The broker product for the order.
    public init(
        tradingSymbol: String, exchange: KiteExchange,
        transactionType: KiteOrderMutationSide, orderType: KiteOrderType,
        quantity: Int64, product: KiteProduct,
    ) {
        self.tradingSymbol = tradingSymbol
        self.exchange = exchange
        self.transactionType = transactionType
        self.orderType = orderType
        self.quantity = quantity
        self.product = product
    }
}

/// Receipt of submission, never proof of exchange acceptance or execution.
public struct KiteOrderMutationReceipt: Decodable, Sendable, Equatable {
    /// The opaque Kite order identifier used for history, trades, and reconciliation.
    public let orderID: String
    /// The optional per-slice outcomes returned within an object acknowledgement.
    public let children: [KiteOrderSliceResult]?
    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case children
    }

    /// Decodes KiteOrderMutationReceipt from the supplied decoder, throwing when required fields are missing or malformed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderID = try container.decode(String.self, forKey: .orderID)
        guard !orderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .orderID, in: container, debugDescription: "Empty order ID",
            )
        }
        children =
            container.contains(.children)
                ? try container.decode([KiteOrderSliceResult].self, forKey: .children) : nil
    }
}

/// The object or auto-slice array acknowledgement returned by placement; neither shape proves execution.
public enum KiteOrderPlacementResult: Decodable, Sendable, Equatable {
    /// An object acknowledgement with an order ID and optional child slice outcomes.
    case order(KiteOrderMutationReceipt)
    /// An auto-slice acknowledgement array; inspect every placed and rejected result.
    case slices([KiteOrderSliceResult])
    /// Decodes KiteOrderPlacementResult from the supplied decoder, throwing when required fields are missing or malformed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let slices = try? container.decode([KiteOrderSliceResult].self) {
            self = .slices(slices)
        } else {
            self = try .order(container.decode(KiteOrderMutationReceipt.self))
        }
    }
}

public extension KiteClient {
    /// Submits a standalone order once, without automatic retries. See <doc:Manage-orders>.
    ///
    /// - Parameters:
    ///   - order: The placement definition, including price for LIMIT or SL and triggerPrice for stop-loss orders.
    /// - Returns: An order receipt or per-slice results. Inspect every slice; submission is not exchange acceptance or execution.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func placeOrder(_ order: KiteOrderPlacement) async throws -> KiteOrderPlacementResult {
        try mutationText(order.tradingSymbol, field: "tradingsymbol")
        try mutationText(order.exchange.rawValue, field: "exchange")
        try mutationText(order.product.rawValue, field: "product")
        try mutationText(order.orderType.rawValue, field: "order_type")
        try mutationNumbers(
            quantity: order.quantity, price: order.price, trigger: order.triggerPrice,
            disclosed: order.disclosedQuantity, ttl: order.validityTTL, protection: order.marketProtection,
        )
        if [.limit, .stopLoss].contains(order.orderType), order.price == nil {
            throw mutationValidation("price", "Required for LIMIT and SL placement")
        }
        if [.stopLoss, .stopLossMarket].contains(order.orderType), order.triggerPrice == nil {
            throw mutationValidation("trigger_price", "Required for stop-loss placement")
        }
        if order.validity == .ttl, order.validityTTL == nil {
            throw mutationValidation("validity_ttl", "Required for TTL placement")
        }
        if order.variety == .iceberg, order.icebergLegs == nil {
            throw mutationValidation("iceberg_legs", "Required for iceberg placement")
        }
        if let legs = order.icebergLegs, !(2 ... 50).contains(legs) {
            throw mutationValidation("iceberg_legs", "Expected 2 through 50 legs")
        }
        if order.variety == .iceberg, order.icebergQuantity == nil {
            throw mutationValidation("iceberg_quantity", "Required for iceberg placement")
        }
        if let quantity = order.icebergQuantity, quantity <= 0 {
            throw mutationValidation("iceberg_quantity", "Must be positive")
        }
        if order.variety == .auction, order.auctionNumber == nil {
            throw mutationValidation("auction_number", "Required for auction placement")
        }
        if let auction = order.auctionNumber {
            try mutationText(auction, field: "auction_number")
        }
        if let tag = order.tag {
            let allowed = CharacterSet(
                charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
            )
            guard !tag.isEmpty, tag.utf8.count <= 20,
                  tag.unicodeScalars.allSatisfy({ allowed.contains($0) })
            else {
                throw mutationValidation("tag", "Expected 1 through 20 alphanumeric ASCII characters")
            }
        }
        var fields: [KiteParameter] = [
            .init("tradingsymbol", order.tradingSymbol), .init("exchange", order.exchange.rawValue),
            .init("transaction_type", order.transactionType.rawValue),
            .init("order_type", order.orderType.rawValue), .init("quantity", String(order.quantity)),
            .init("product", order.product.rawValue),
        ]
        if let price = order.price {
            fields.append(.init("price", price.description))
        }
        if let validity = order.validity {
            fields.append(.init("validity", validity.rawValue))
        }
        if let value = order.triggerPrice {
            fields.append(.init("trigger_price", value.description))
        }
        if let value = order.disclosedQuantity {
            fields.append(.init("disclosed_quantity", String(value)))
        }
        if let value = order.validityTTL {
            fields.append(.init("validity_ttl", String(value)))
        }
        if let value = order.icebergLegs {
            fields.append(.init("iceberg_legs", String(value)))
        }
        if let value = order.icebergQuantity {
            fields.append(.init("iceberg_quantity", String(value)))
        }
        if let value = order.auctionNumber {
            fields.append(.init("auction_number", value))
        }
        if let value = order.marketProtection {
            fields.append(.init("market_protection", value.description))
        }
        if let value = order.autoslice {
            fields.append(.init("autoslice", value ? "true" : "false"))
        }
        if let value = order.tag {
            fields.append(.init("tag", value))
        }
        return try await execute(
            KiteRequest(
                method: .post, path: "/orders/\(order.variety.rawValue)",
                body: .form(fields), isTradingMutation: true,
            ), as: KiteOrderPlacementResult.self,
        )
    }
}
