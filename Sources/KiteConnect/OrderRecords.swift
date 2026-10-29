//
//  OrderRecords.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// A strict REST order-book/history record. A successful submission alone does not prove a fill.
public struct KiteOrder: Decodable, Sendable, Equatable {
    /// The shared order state underlying this stricter REST record.
    public let update: KiteOrderUpdate
    /// The required REST order state; completion and partial fills require separate interpretation.
    public let status: KiteOrderStatus
    /// Whether Kite reports a modification to this order.
    public let modified: Bool
    /// The opaque Kite order identifier used for history, trades, and reconciliation.
    public var orderID: String {
        update.orderID
    }

    /// The exchange-assigned order identifier, when reported by Kite.
    public var exchangeOrderID: String? {
        update.exchangeOrderID
    }

    /// The parent order identifier for a child leg, when reported.
    public var parentOrderID: String? {
        update.parentOrderID
    }

    /// The identifier of the user who placed the order.
    public var placedBy: String {
        update.placedBy
    }

    /// The exchange on which the instrument is identified.
    public var exchange: KiteExchange {
        update.exchange
    }

    /// The trading symbol within the specified exchange.
    public var tradingSymbol: String {
        update.tradingSymbol
    }

    /// The numeric instrument token supplied by Kite; tokens may be reused after expiry.
    public var instrumentToken: UInt32 {
        update.instrumentToken
    }

    /// The order routing variety, such as regular, after-market, or cover.
    public var variety: KiteOrderVariety {
        update.variety
    }

    /// The reported buy or sell direction, retaining unfamiliar server values.
    public var transactionType: KiteTransactionType {
        update.transactionType
    }

    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public var orderType: KiteOrderType {
        update.orderType
    }

    /// The broker product used for the order or execution.
    public var product: KiteProduct {
        update.product
    }

    /// The reported order lifetime instruction, retaining unfamiliar server values.
    public var validity: KiteOrderValidity {
        update.validity
    }

    /// The nonnegative order quantity reported by Kite, without recomputing it from fills.
    public var quantity: Int64 {
        update.quantity
    }

    /// The quantity disclosed to the market; supplied values must be nonnegative.
    public var disclosedQuantity: Int64 {
        update.disclosedQuantity
    }

    /// The quantity already executed; cancellation does not reverse these fills.
    public var filledQuantity: Int64 {
        update.filledQuantity
    }

    /// The quantity awaiting execution as reported by Kite.
    public var pendingQuantity: Int64 {
        update.pendingQuantity
    }

    /// The quantity cancelled without execution as reported by Kite.
    public var cancelledQuantity: Int64 {
        update.cancelledQuantity
    }

    /// The order price as a decimal value, distinct from its execution price.
    public var price: Decimal {
        update.price
    }

    /// The stop-loss trigger price, separate from the order limit price.
    public var triggerPrice: Decimal {
        update.triggerPrice
    }

    /// The average execution price reported by Kite, without local recalculation.
    public var averagePrice: Decimal {
        update.averagePrice
    }

    /// The order timestamp supplied by Kite, interpreted with the configured trading timezone when offsetless.
    public var orderTimestamp: Date {
        update.orderTimestamp
    }

    /// The exchange timestamp, when the response reports one.
    public var exchangeTimestamp: Date? {
        update.exchangeTimestamp
    }

    /// The timestamp of the latest exchange update, when reported.
    public var exchangeUpdateTimestamp: Date? {
        update.exchangeUpdateTimestamp
    }

    /// The human-readable status or rejection explanation supplied by Kite.
    public var statusMessage: String? {
        update.statusMessage
    }

    /// The unmodified underlying status message supplied by Kite.
    public var statusMessageRaw: String? {
        update.statusMessageRaw
    }

    /// The optional market-protection value reported by Kite without recomputing protection.
    public var marketProtection: Decimal? {
        update.marketProtection
    }

    /// The optional order time-to-live in minutes, validated as nonnegative in REST state.
    public var validityTTL: Int64? {
        update.validityTTL
    }

    /// The auction session identifier reported by Kite, or nil when absent or null.
    public var auctionNumber: String? {
        update.auctionNumber
    }

    /// The application tag returned by Kite, when present; it is not an idempotency key.
    public var tag: String? {
        update.tag
    }

    /// The application tags preserved as supplied by the server or basket definition.
    public var tags: [String]? {
        update.tags
    }

    /// The server-supplied request identifier, when reported.
    public var guid: String? {
        update.guid
    }

    /// The account identifier associated with this order or execution attempt.
    public var accountID: String? {
        update.accountID
    }

    /// The terminal identifier reported by Kite, when available.
    public var terminalID: String? {
        update.terminalID
    }

    /// The server metadata preserved without assuming a fixed JSON schema.
    public var meta: KiteOrderMetadata? {
        update.meta
    }

    /// The original timestamp text, preserved without reformatting for checksum use.
    public var orderTimestampRaw: String {
        update.orderTimestampRaw
    }

    /// Decodes a REST order with required status and modified fields in addition to shared update data.
    ///
    /// - Parameter decoder: The decoder positioned at the response value, outside any Kite envelope.
    /// - Throws: A decoding error for missing or malformed required values. Optional
    ///   fields allow absence or null, but malformed present values fail.
    public init(from decoder: any Decoder) throws {
        update = try KiteOrderUpdate(from: decoder)
        let container = try decoder.container(keyedBy: KiteOrderUpdate.CodingKeys.self)
        status = try container.decode(KiteOrderStatus.self, forKey: .status)
        modified = try container.decode(Bool.self, forKey: .modified)
    }
}

/// The documented trade examples contain a clock time without a date for order_timestamp.
/// Preserve that distinction: a time of day is not an instant and has no inferred date or zone.
public enum KiteTradeOrderTimestamp: Sendable, Equatable {
    /// A clock time with no inferred calendar date or timezone.
    case timeOfDay(hour: Int, minute: Int, second: Int)
    /// A full timestamp decoded as a Date instant with timezone handling.
    case instant(Date)
}

/// One exchange execution (partial fill). Multiple trades may refer to the same order.
public struct KiteTrade: Decodable, Sendable, Equatable {
    /// The identifier of this individual execution; several trades may share one order ID.
    public let tradeID: String
    /// The opaque Kite order identifier used for history, trades, and reconciliation.
    public let orderID: String
    /// The exchange-assigned order identifier, when reported by Kite.
    public let exchangeOrderID: String?
    /// The exchange on which the instrument is identified.
    public let exchange: KiteExchange
    /// The trading symbol within the specified exchange.
    public let tradingSymbol: String
    /// The numeric instrument token supplied by Kite; tokens may be reused after expiry.
    public let instrumentToken: UInt32
    /// The broker product used for the order or execution.
    public let product: KiteProduct
    /// The reported buy or sell direction, retaining unfamiliar server values.
    public let transactionType: KiteTransactionType
    /// The average execution price reported by Kite, without local recalculation.
    public let averagePrice: Decimal
    /// The table calls this field filled; JSON examples use quantity. Either spelling is accepted.
    public let quantity: Int64
    /// The optional original filled quantity; quantity takes precedence when both spellings are supplied.
    public let filled: Int64?
    /// The instant at which the trade filled, using the configured timezone for offsetless text.
    public let fillTimestamp: Date
    /// The required exchange timestamp for this execution, decoded as an instant.
    public let exchangeTimestamp: Date
    /// The order time as a clock-only value or a full instant; no date is invented.
    public let orderTimestamp: KiteTradeOrderTimestamp
    /// The original timestamp text, preserved without reformatting for checksum use.
    public let orderTimestampRaw: String
    enum CodingKeys: String, CodingKey {
        case exchange, product, quantity, filled
        case tradeID = "trade_id"
        case orderID = "order_id"
        case exchangeOrderID = "exchange_order_id"
        case tradingSymbol = "tradingsymbol"
        case instrumentToken = "instrument_token"
        case transactionType = "transaction_type"
        case averagePrice = "average_price"
        case fillTimestamp = "fill_timestamp"
        case exchangeTimestamp = "exchange_timestamp"
        case orderTimestamp = "order_timestamp"
    }

    /// Decodes an execution with nonempty IDs and nonnegative quantities; quantity takes precedence over filled.
    ///
    /// - Parameter decoder: The decoder positioned at the response value, outside any Kite envelope.
    /// - Throws: A decoding error for missing or malformed required values. Optional
    ///   fields allow absence or null, but malformed present values fail.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tradeID = try container.decode(String.self, forKey: .tradeID)
        guard !tradeID.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .tradeID, in: container,
                debugDescription: "Expected a nonempty trade ID",
            )
        }
        orderID = try container.decode(String.self, forKey: .orderID)
        guard !orderID.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .orderID, in: container,
                debugDescription: "Expected a nonempty order ID",
            )
        }
        exchangeOrderID = try container.decodeIfPresent(String.self, forKey: .exchangeOrderID)
        exchange = try container.decode(KiteExchange.self, forKey: .exchange)
        tradingSymbol = try container.decode(String.self, forKey: .tradingSymbol)
        instrumentToken = try decodeOrderInstrumentToken(container, forKey: .instrumentToken)
        product = try container.decode(KiteProduct.self, forKey: .product)
        transactionType = try container.decode(KiteTransactionType.self, forKey: .transactionType)
        averagePrice = try container.decode(Decimal.self, forKey: .averagePrice)
        filled = try container.decodeIfPresent(Int64.self, forKey: .filled)
        if container.contains(.quantity) {
            quantity = try container.decode(Int64.self, forKey: .quantity)
        } else {
            quantity = try container.decode(Int64.self, forKey: .filled)
        }
        guard quantity >= 0, filled.map({ $0 >= 0 }) ?? true else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected nonnegative trade quantities",
                ),
            )
        }
        fillTimestamp = try container.decode(Date.self, forKey: .fillTimestamp)
        exchangeTimestamp = try container.decode(Date.self, forKey: .exchangeTimestamp)
        orderTimestampRaw = try container.decode(String.self, forKey: .orderTimestamp)
        if orderTimestampRaw.range(of: #"\A[0-9]{2}:[0-9]{2}:[0-9]{2}\z"#, options: .regularExpression)
            != nil
        {
            let parts = orderTimestampRaw.split(separator: ":").compactMap { Int($0) }
            guard parts[0] < 24, parts[1] < 60, parts[2] < 60 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .orderTimestamp, in: container,
                    debugDescription: "Invalid trade order clock time",
                )
            }
            orderTimestamp = .timeOfDay(hour: parts[0], minute: parts[1], second: parts[2])
        } else {
            orderTimestamp = try .instant(container.decode(Date.self, forKey: .orderTimestamp))
        }
    }
}

/// Arbitrary order metadata, including nested iceberg details. Numeric values stay decimal.
public indirect enum KiteOrderMetadata: Decodable, Sendable, Equatable {
    /// A JSON object retaining each named child value without a fixed schema.
    case object([String: KiteOrderMetadata])
    /// A JSON array retaining the server order of its child values.
    case array([KiteOrderMetadata])
    /// A JSON string preserved without interpreting its contents.
    case string(String)
    /// A JSON number decoded as Decimal without conversion through Double.
    case number(Decimal)
    /// A JSON Boolean preserved as its original true or false value.
    case bool(Bool)
    /// An explicit JSON null value, distinct from missing object keys.
    case null

    /// Decodes arbitrary order metadata recursively without imposing a fixed schema; numbers remain Decimal.
    ///
    /// - Parameter decoder: The decoder positioned at any JSON value.
    /// - Throws: A decoding error if the value cannot be represented by the supported JSON cases.
    public init(from decoder: any Decoder) throws {
        self = try decodeArbitraryJSON(
            from: decoder, null: .null, bool: Self.bool, string: Self.string,
            number: Self.number, array: Self.array, object: Self.object,
        )
    }
}
