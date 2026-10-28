//
//  AlertHistory.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Trigger-time market data, whose documented shape differs from a full quote.
public struct KiteAlertMarketData: Decodable, Sendable, Equatable {
    /// The numeric instrument token supplied by Kite; tokens may be reused after expiry.
    public let instrumentToken: UInt32
    /// The trading symbol within the specified exchange.
    public let tradingSymbol: String
    /// The event instant, using the configured trading timezone for offsetless text.
    public let timestamp: Date
    /// The last trade instant in the trigger-time market data.
    public let lastTradeTime: Date
    /// The exchange on which the instrument is identified.
    public let exchange: KiteExchange
    /// The last traded price supplied with the trigger condition or basket.
    public let lastPrice: Decimal
    /// The open, high, low, and close prices supplied at trigger time.
    public let ohlc: KiteOHLC
    /// The net price change reported in the trigger-time market data.
    public let netChange: Decimal
    /// The quantity of the most recent trade at trigger time.
    public let lastQuantity: Int64
    /// The total buy quantity reported at trigger time.
    public let buyQuantity: Int64
    /// The total sell quantity reported at trigger time.
    public let sellQuantity: Int64
    /// The traded volume supplied in the trigger-time market data.
    public let volume: Int64
    /// The per-tick volume supplied in the trigger-time market data.
    public let volumeTick: Int64
    /// The average traded price reported in the trigger-time market data.
    public let averagePrice: Decimal
    /// The open interest supplied in the trigger-time market data.
    public let oi: Decimal
    /// The highest open interest reported for the day at trigger time.
    public let oiDayHigh: Decimal
    /// The lowest open interest reported for the day at trigger time.
    public let oiDayLow: Decimal
    /// The lower price circuit limit reported at trigger time.
    public let lowerCircuitLimit: Decimal
    /// The upper price circuit limit reported at trigger time.
    public let upperCircuitLimit: Decimal
    enum CodingKeys: String, CodingKey {
        case instrumentToken = "instrument_token"
        case tradingSymbol = "tradingsymbol"
        case timestamp
        case lastTradeTime = "last_trade_time"
        case exchange
        case lastPrice = "last_price"
        case ohlc
        case netChange = "net_change"
        case lastQuantity = "last_quantity"
        case buyQuantity = "buy_quantity"
        case sellQuantity = "sell_quantity"
        case volume
        case volumeTick = "volume_tick"
        case averagePrice = "average_price"
        case oi
        case oiDayHigh = "oi_day_high"
        case oiDayLow = "oi_day_low"
        case lowerCircuitLimit = "lower_circuit_limit"
        case upperCircuitLimit = "upper_circuit_limit"
    }
}

/// The alerts docs specify only null order_meta, with no non-null ATO schema.
/// Do not assume that an undocumented value is a standalone order or proof of execution.
public enum KiteAlertOrderMetadata: Sendable, Equatable {
    /// No order metadata was reported, because the field was missing or null.
    case notReported
    /// Non-null order metadata preserved without assuming an unpublished schema.
    case undocumented(KiteOrderMutationJSONValue)
}

/// Lifecycle history shared by simple and alert-triggered order basket alerts.
public struct KiteAlertHistoryEntry: Decodable, Sendable, Equatable {
    /// The opaque alert identifier used for lookup, history, modification, and deletion.
    public let uuid: String
    /// The simple or order-triggering alert kind recorded in this history entry.
    public let type: KiteAlertType
    /// The trigger-time market data recorded for the alert operands.
    public let meta: [KiteAlertMarketData]
    /// The comparison or trigger condition associated with this definition.
    public let condition: String
    /// The creation instant reported by Kite, using the configured timezone when offsetless.
    public let createdAt: Date
    /// Lossless compatibility view of order_meta. Null and missing values are nil.
    public let orderMeta: KiteOrderMutationJSONValue?
    /// Typed documented absence, or preserved non-null metadata whose schema is unpublished.
    public var orderMetadata: KiteAlertOrderMetadata {
        orderMeta.map(KiteAlertOrderMetadata.undocumented) ?? .notReported
    }

    enum CodingKeys: String, CodingKey {
        case uuid, type, meta, condition
        case createdAt = "created_at"
        case orderMeta = "order_meta"
    }
}
