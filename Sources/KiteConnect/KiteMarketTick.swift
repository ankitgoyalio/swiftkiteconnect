//
//  KiteMarketTick.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// Outgoing request options; incoming layouts are identified by packet length.
public enum KiteTickerMode: String, Sendable, CaseIterable {
    /// Requests last price only for each subscribed instrument.
    case ltp
    /// Requests quote fields, with an index-specific layout for index instruments.
    case quote
    /// Requests depth and timestamps where available. Index full packets have no depth.
    case full
}

/// Trade quantities and daily prices from a tradable instrument quote packet.
public struct KiteQuoteFields: Sendable, Equatable {
    /// The quantity in the most recent trade reported by the exchange.
    public let lastTradedQuantity: UInt32
    /// The average traded price reported for the trading day, in price units.
    public let averageTradedPrice: Decimal
    /// Total traded quantity reported for the trading day.
    public let volumeTraded: UInt32
    /// Aggregate outstanding buy quantity reported in the quote.
    public let totalBuyQuantity: UInt32
    /// Aggregate outstanding sell quantity reported in the quote.
    public let totalSellQuantity: UInt32
    /// Open, high, low, and previous close prices reported in the packet.
    public let ohlc: KiteOHLC
}

/// Binary market data, including layouts arriving while a mode change is in flight.
public struct KiteMarketTick: Sendable, Equatable {
    /// The layout decoded from packet length, even during a subscription mode change.
    public enum Details: Sendable, Equatable {
        /// Only instrument token and last price are present in the packet.
        case ltp
        /// Tradable instrument quote fields without depth or exchange timestamps.
        case quote(KiteQuoteFields)
        /// Tradable instrument quote, open interest, timestamps, and market depth.
        case full(KiteFullFields)
        /// Index prices and signed price change, without tradable instrument quantities.
        case indexQuote(KiteIndexFields)
        /// Index prices and signed price change with a Unix-second exchange timestamp.
        case indexFull(KiteIndexFields, exchangeTimestamp: Date)
    }

    /// The numeric subscription identifier, which may be reused after derivative expiry.
    public let instrumentToken: UInt32
    /// The last price in price units, scaled for the instrument segment.
    public let lastPrice: Decimal
    /// Fields present in this packet. Requested mode does not override the received layout.
    public let details: Details
}

/// Full tradable-instrument data with quote fields, open interest, timestamps, and depth.
public struct KiteFullFields: Sendable, Equatable {
    /// Trade quantities and daily prices shared with quote-mode packets.
    public let quote: KiteQuoteFields
    /// Wire timestamps are Unix seconds, independent of the trading time zone.
    public let lastTradeTime: Date
    /// The exchange-reported outstanding contracts for this instrument.
    public let openInterest: UInt32
    /// The highest open interest reported during the trading day.
    public let openInterestDayHigh: UInt32
    /// The lowest open interest reported during the trading day.
    public let openInterestDayLow: UInt32
    /// The exchange timestamp decoded as Unix seconds, independent of trading time zone.
    public let exchangeTimestamp: Date
    /// Five buy levels and five sell levels decoded in wire order.
    public let depth: KiteMarketDepth
}

/// Index daily prices and signed price change without trade quantity or depth fields.
public struct KiteIndexFields: Sendable, Equatable {
    /// Index open, high, low, and previous close prices in price units.
    public let ohlc: KiteOHLC
    /// Signed wire price change in price units, not a calculated percentage.
    public let priceChange: Decimal
}
