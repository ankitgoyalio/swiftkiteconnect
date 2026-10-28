//
//  MutualFunds.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// Mutual-fund order record with fractional units and decimal financial values. This model does not place orders.
///
/// ## See Also
///
/// - <doc:Read-mutual-fund-information>
public struct KiteMutualFundOrder: Decodable, Sendable, Equatable {
    /// Order identifier reported by Kite for subsequent order lookup.
    public let orderID: String
    /// Exchange order identifier when supplied by Kite. Nil means the field was absent or null.
    public let exchangeOrderID: String?
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Order status when supplied by Kite, preserving unfamiliar values. Nil means the field was absent or null.
    public let status: KiteOrderStatus?
    /// Server explanation of the order status when supplied. Nil means the field was absent or null.
    public let statusMessage: String?
    /// Folio number when supplied by Kite. An absent value remains nil.
    public let folio: String?
    /// Display name of the mutual-fund scheme reported by Kite.
    public let fund: String
    /// Order timestamp decoded as an instant using the configured trading timezone when offsetless.
    public let orderTimestamp: Date
    /// Exchange-reported calendar date, retained without a device-timezone conversion. Nil means the field was absent or null.
    public let exchangeTimestamp: KiteDateOnly?
    /// Settlement identifier when supplied by Kite. Nil means the field was absent or null.
    public let settlementID: String?
    /// Buy or sell direction, preserving unfamiliar response values.
    public let transactionType: KiteTransactionType
    /// Monetary amount of the mutual-fund order, retained as a decimal.
    public let amount: Decimal
    /// Order variety used for the request or reported by Kite.
    public let variety: KiteMutualFundVariety
    /// Fresh or additional purchase classification when supplied by Kite. Nil means the field was absent or null.
    public let purchaseType: KiteMutualFundPurchaseType?
    /// Quantity reported by Kite, retained without rounding or recomputation.
    public let quantity: Decimal
    /// Price reported by Kite in decimal form, without recomputation. Nil means the field was absent or null.
    public let price: Decimal?
    /// Latest price or net asset value reported by Kite, not a live-price subscription.
    public let lastPrice: Decimal
    /// Average acquisition or execution price reported by Kite as a decimal.
    public let averagePrice: Decimal
    /// Identifier of the user who placed the order, as reported by Kite.
    public let placedBy: String
    /// Calendar date of the reported price or net asset value.
    public let lastPriceDate: KiteDateOnly
    /// Application tag returned by Kite when present. Nil means the field was absent or null.
    public let tag: String?
    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case exchangeOrderID = "exchange_order_id"
        case tradingSymbol = "tradingsymbol"
        case status
        case statusMessage = "status_message"
        case folio
        case fund
        case orderTimestamp = "order_timestamp"
        case exchangeTimestamp = "exchange_timestamp"
        case settlementID = "settlement_id"
        case transactionType = "transaction_type"
        case amount
        case variety
        case purchaseType = "purchase_type"
        case quantity
        case price
        case lastPrice = "last_price"
        case averagePrice = "average_price"
        case placedBy = "placed_by"
        case lastPriceDate = "last_price_date"
        case tag
    }

    /// Decodes the required fields and retains optional metadata when present.
    /// - Parameter decoder: Decoder configured with the SDK timestamp strategy for instant fields.
    /// - Throws: A decoding or validation error if a required value is missing or malformed.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orderID = try c.decode(String.self, forKey: .orderID)
        exchangeOrderID = try c.decodeIfPresent(String.self, forKey: .exchangeOrderID)
        tradingSymbol = try c.decode(String.self, forKey: .tradingSymbol)
        status = try c.decodeIfPresent(KiteOrderStatus.self, forKey: .status)
        statusMessage = try c.decodeIfPresent(String.self, forKey: .statusMessage)
        folio = try c.decodeIfPresent(String.self, forKey: .folio)
        fund = try c.decode(String.self, forKey: .fund)
        orderTimestamp = try c.decode(Date.self, forKey: .orderTimestamp)
        exchangeTimestamp = try c.decodeIfPresent(String.self, forKey: .exchangeTimestamp).map {
            try KiteDateOnly($0)
        }
        settlementID = try c.decodeIfPresent(String.self, forKey: .settlementID)
        transactionType = try c.decode(KiteTransactionType.self, forKey: .transactionType)
        amount = try c.decode(Decimal.self, forKey: .amount)
        variety = try c.decode(KiteMutualFundVariety.self, forKey: .variety)
        purchaseType = try c.decodeIfPresent(KiteMutualFundPurchaseType.self, forKey: .purchaseType)
        quantity = try c.decode(Decimal.self, forKey: .quantity)
        price = try c.decodeIfPresent(Decimal.self, forKey: .price)
        lastPrice = try c.decode(Decimal.self, forKey: .lastPrice)
        averagePrice = try c.decode(Decimal.self, forKey: .averagePrice)
        placedBy = try c.decode(String.self, forKey: .placedBy)
        lastPriceDate = try KiteDateOnly(c.decode(String.self, forKey: .lastPriceDate))
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
    }
}

public extension KiteClient {
    /// Retrieves mutual-fund orders placed within the last seven days.
    /// - Returns: Order records with fractional quantities and optional server metadata.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func mutualFundOrders() async throws -> [KiteMutualFundOrder] {
        try await execute(KiteRequest(path: "/mf/orders"), as: [KiteMutualFundOrder].self)
    }
}

/// Regular, SIP, or AMC SIP classification, preserving unfamiliar server strings.
public enum KiteMutualFundVariety: KiteStringValue {
    /// Regular order or fund plan classification reported by Kite.
    case regular
    /// Order generated through a systematic investment plan.
    case sip
    /// Order generated through an asset management company SIP.
    case amcSIP
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "regular": self = .regular
        case "sip": self = .sip
        case "amc_sip": self = .amcSIP
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .regular: "regular"
        case .sip: "sip"
        case .amcSIP: "amc_sip"
        case let .unknown(value): value
        }
    }
}

/// Initial or additional fund purchase classification, preserving unfamiliar server strings.
public enum KiteMutualFundPurchaseType: KiteStringValue {
    /// Initial purchase in a mutual-fund scheme.
    case fresh
    /// Additional purchase in an existing mutual-fund investment.
    case additional
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "FRESH": self = .fresh
        case "ADDITIONAL": self = .additional
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .fresh: "FRESH"
        case .additional: "ADDITIONAL"
        case let .unknown(value): value
        }
    }
}

public extension KiteClient {
    /// Retrieves one mutual-fund order irrespective of its age.
    /// - Parameter orderID: A nonempty path component without whitespace, controls, separators, or `..`.
    /// - Returns: The matching order record.
    /// - Throws: `KiteError.validation` for malformed input, or authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func mutualFundOrder(orderID: String) async throws -> KiteMutualFundOrder {
        guard !orderID.isEmpty, !orderID.contains(".."),
              !orderID.contains(where: { $0.isWhitespace || "/\\?#".contains($0) }),
              !orderID.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else {
            throw KiteError.validation(
                field: "orderID", message: "Expected a single nonempty order ID path component",
            )
        }
        return try await execute(
            KiteRequest(path: "/mf/orders/" + orderID), as: KiteMutualFundOrder.self,
        )
    }
}
