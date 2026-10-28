//
//  QuoteSnapshots.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// A last-traded-price snapshot returned by ``KiteClient/ltp(instruments:)``.
///
/// Unavailable instruments are absent from the response map. No zero-price snapshot is synthesized.
public struct KiteLTPSnapshot: Decodable, Sendable, Equatable {
    /// The numeric Kite instrument token reported with this snapshot, which may be reused after derivative expiry.
    public let instrumentToken: UInt32
    /// The last traded price, decoded directly as `Decimal` without a binary floating-point conversion.
    public let lastPrice: Decimal
    enum CodingKeys: String, CodingKey {
        case instrumentToken = "instrument_token"
        case lastPrice = "last_price"
    }
}

/// Current trading-day opening, high, and low prices with the previous trading day's closing price.
///
/// This quote summary differs from a historical candle, whose close belongs to its own interval.
public struct KiteOHLC: Decodable, Sendable, Equatable {
    /// The opening price for the current trading day.
    public let open: Decimal
    /// The highest price recorded during the current trading day.
    public let high: Decimal
    /// The lowest price recorded during the current trading day.
    public let low: Decimal
    /// The previous trading day's closing price, rather than the latest traded price.
    public let close: Decimal
}

/// A last-traded price and trading-day OHLC summary returned by ``KiteClient/ohlc(instruments:)``.
public struct KiteOHLCSnapshot: Decodable, Sendable, Equatable {
    /// The numeric Kite instrument token reported with this snapshot, which may be reused after derivative expiry.
    public let instrumentToken: UInt32
    /// The last traded price, decoded directly as `Decimal` without a binary floating-point conversion.
    public let lastPrice: Decimal
    /// The current trading-day OHLC summary, whose close is the previous trading day's close.
    public let ohlc: KiteOHLC
    enum CodingKeys: String, CodingKey {
        case instrumentToken = "instrument_token"
        case lastPrice = "last_price"
        case ohlc
    }
}

/// One aggregated price level on the buy or sell side of the order book.
public struct KiteDepthLevel: Decodable, Sendable, Equatable {
    /// The price shared by the orders aggregated at this depth level.
    public let price: Decimal
    /// The total quantity reported at this depth price level.
    public let quantity: Int64
    /// The number of orders reported at this depth price level.
    public let orders: Int64
}

/// The buy and sell levels reported in a full quote. Arrays may be empty or have variable lengths.
public struct KiteMarketDepth: Decodable, Sendable, Equatable {
    /// The buy-side levels in server order, without padding to a fixed length.
    public let buy: [KiteDepthLevel]
    /// The sell-side levels in server order, without padding to a fixed length.
    public let sell: [KiteDepthLevel]
}

/// A full REST quote with trading-day prices, quantities, timestamps, and market depth.
///
/// Prices and financial values decode directly as `Decimal`. Missing or malformed required fields
/// fail the response. See <doc:Request-quote-snapshots> for limits and unavailable instruments.
public struct KiteQuoteSnapshot: Decodable, Sendable, Equatable {
    /// The numeric Kite instrument token reported with this snapshot, which may be reused after derivative expiry.
    public let instrumentToken: UInt32
    /// The quote timestamp as an instant. Offsetless text uses the configured trading time zone, defaulting to `Asia/Kolkata`.
    public let timestamp: Date
    /// The last trade instant, or `nil` when absent or null. Explicit offsets override the configured trading time zone.
    public let lastTradeTime: Date?
    /// The last traded price, decoded directly as `Decimal` without a binary floating-point conversion.
    public let lastPrice: Decimal
    /// The quantity of the last reported trade for this instrument.
    public let lastQuantity: Int64
    /// The total outstanding buy quantity reported by Kite.
    public let buyQuantity: Int64
    /// The total outstanding sell quantity reported by Kite.
    public let sellQuantity: Int64
    /// The traded volume reported for the current trading day.
    public let volume: Int64
    /// The average traded price reported for the current trading day.
    public let averagePrice: Decimal
    /// The required `oi` value reported by Kite, retained separately from the optional ``openInterest`` field.
    public let oi: Decimal
    /// The highest open interest reported for the current trading day.
    public let oiDayHigh: Decimal
    /// The lowest open interest reported for the current trading day.
    public let oiDayLow: Decimal
    /// The optional derivatives-only `open_interest` attribute, distinct from ``oi``. Neither field substitutes for the other.
    public let openInterest: Decimal?
    /// The net change value reported by Kite, retained without local recalculation.
    public let netChange: Decimal
    /// The lower circuit price limit reported by Kite for this instrument.
    public let lowerCircuitLimit: Decimal
    /// The upper circuit price limit reported by Kite for this instrument.
    public let upperCircuitLimit: Decimal
    /// The current trading-day OHLC summary, whose close is the previous trading day's close.
    public let ohlc: KiteOHLC
    /// The reported buy and sell depth arrays, which may be empty or vary in length.
    public let depth: KiteMarketDepth
    enum CodingKeys: String, CodingKey {
        case instrumentToken = "instrument_token"
        case timestamp
        case lastTradeTime = "last_trade_time"
        case lastPrice = "last_price"
        case lastQuantity = "last_quantity"
        case buyQuantity = "buy_quantity"
        case sellQuantity = "sell_quantity"
        case volume
        case averagePrice = "average_price"
        case oi
        case oiDayHigh = "oi_day_high"
        case oiDayLow = "oi_day_low"
        case openInterest = "open_interest"
        case netChange = "net_change"
        case lowerCircuitLimit = "lower_circuit_limit"
        case upperCircuitLimit = "upper_circuit_limit"
        case ohlc, depth
    }
}

public extension KiteClient {
    /// Retrieves full quote snapshots, including market depth, for 1 through 500 identities.
    ///
    /// No catalogue lookup is required. Input order and duplicate query parameters are preserved.
    /// The SDK does not batch or deduplicate requests. See <doc:Request-quote-snapshots>.
    ///
    /// - Parameter instruments: Exchange and trading-symbol identities. Duplicates count toward the limit.
    /// - Returns: A map keyed by instrument identity. Unavailable keys remain absent, without synthetic zero quotes.
    /// - Throws: ``KiteError/validation(field:message:)`` for invalid count or missing access token,
    ///   ``KiteError/decoding(statusCode:message:)`` for malformed data, or API and transport errors.
    ///   Cancellation propagates. The request is attempted once.
    func quotes(instruments: [KiteInstrumentIdentity]) async throws
        -> [KiteInstrumentIdentity: KiteQuoteSnapshot]
    {
        try await snapshots(path: "/quote", instruments: instruments, as: KiteQuoteSnapshot.self)
    }

    /// Retrieves last-traded prices and OHLC summaries for 1 through 1000 identities.
    ///
    /// OHLC close is the previous trading day's close. Input order and duplicate query parameters are
    /// preserved without batching or a catalogue lookup.
    ///
    /// - Parameter instruments: Exchange and trading-symbol identities. Duplicates count toward the limit.
    /// - Returns: Snapshots keyed by identity. Unavailable instruments remain absent.
    /// - Throws: ``KiteError/validation(field:message:)`` for invalid count or missing access token,
    ///   ``KiteError/decoding(statusCode:message:)`` for malformed data, or API and transport errors.
    ///   Cancellation propagates. The request is attempted once.
    func ohlc(instruments: [KiteInstrumentIdentity]) async throws
        -> [KiteInstrumentIdentity: KiteOHLCSnapshot]
    {
        try await snapshots(path: "/quote/ohlc", instruments: instruments, as: KiteOHLCSnapshot.self)
    }

    /// Retrieves last-traded prices for 1 through 1000 identities without a catalogue lookup.
    ///
    /// Input order and duplicate query parameters are preserved without batching or deduplication.
    ///
    /// - Parameter instruments: Exchange and trading-symbol identities. Duplicates count toward the limit.
    /// - Returns: Prices and tokens keyed by identity. Unavailable instruments remain absent, rather than receiving zero prices.
    /// - Throws: ``KiteError/validation(field:message:)`` for invalid count or missing access token,
    ///   ``KiteError/decoding(statusCode:message:)`` for malformed data, or API and transport errors.
    ///   Cancellation propagates. The request is attempted once.
    func ltp(instruments: [KiteInstrumentIdentity]) async throws
        -> [KiteInstrumentIdentity: KiteLTPSnapshot]
    {
        try await snapshots(path: "/quote/ltp", instruments: instruments, as: KiteLTPSnapshot.self)
    }

    private func snapshots<Value: Decodable & Sendable>(
        path: String, instruments: [KiteInstrumentIdentity], as _: Value.Type,
    ) async throws -> [KiteInstrumentIdentity: Value] {
        let limit = path == "/quote" ? 500 : 1000
        guard (1 ... limit).contains(instruments.count) else {
            throw KiteError.validation(field: "instruments", message: "Expected 1...\(limit) identities")
        }
        return try await execute(
            KiteRequest(path: path, query: instruments.map { KiteParameter("i", $0.description) }),
            as: KiteSnapshotMap<Value>.self,
        ).values
    }
}

private struct KiteSnapshotMap<Value: Decodable & Sendable>: Decodable, Sendable {
    let values: [KiteInstrumentIdentity: Value]
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let wire = try container.decode([String: Value].self)
        var result: [KiteInstrumentIdentity: Value] = [:]
        for (key, value) in wire {
            let parts = key.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let identity = try? KiteInstrumentIdentity(
                      exchange: KiteExchange(rawValue: String(parts[0])), tradingSymbol: String(parts[1]),
                  )
            else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Invalid quote identity: \(key)",
                )
            }
            result[identity] = value
        }
        values = result
    }
}
