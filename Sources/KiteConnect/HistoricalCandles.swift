//
//  HistoricalCandles.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// The eight supported historical candle intervals. These request options form a closed set.
public enum KiteHistoricalInterval: String, Sendable, CaseIterable {
    /// One-minute candles, encoded as `minute` in historical requests.
    case minute
    /// Daily candles, also required for continuous futures history.
    case day
    /// Three-minute candles, encoded as `3minute` in historical requests.
    case threeMinute = "3minute"
    /// Five-minute candles, encoded as `5minute` in historical requests.
    case fiveMinute = "5minute"
    /// Ten-minute candles, encoded as `10minute` in historical requests.
    case tenMinute = "10minute"
    /// Fifteen-minute candles, encoded as `15minute` in historical requests.
    case fifteenMinute = "15minute"
    /// Thirty-minute candles, encoded as `30minute` in historical requests.
    case thirtyMinute = "30minute"
    /// Sixty-minute candles, encoded as `60minute` in historical requests.
    case sixtyMinute = "60minute"
}

/// A historical candle decoded from six or seven positional values into decimal prices and integer counts.
///
/// Malformed rows fail the entire response. An empty candle list is valid. See <doc:Request-historical-candles>.
public struct KiteHistoricalCandle: Sendable, Equatable {
    /// The candle timestamp as an instant. Explicit offsets take precedence over the configured trading time zone.
    public let timestamp: Date
    /// The opening price for this candle interval, decoded directly as `Decimal`.
    public let open: Decimal
    /// The highest price for this candle interval, without local price-plausibility checks.
    public let high: Decimal
    /// The lowest price for this candle interval, without local price-plausibility checks.
    public let low: Decimal
    /// The closing price for this candle interval, decoded directly as `Decimal`.
    public let close: Decimal
    /// The nonnegative integer volume for this candle interval.
    public let volume: Int64
    /// The nonnegative integer open interest, or `nil` when omitted. Every row must contain it when `oi` was requested.
    public let openInterest: Int64?
}

public extension KiteClient {
    /// Retrieves historical candles for a numeric instrument token.
    ///
    /// Bounds become whole-second text in ``KiteConfiguration/tradingTimeZone``. Explicit response
    /// offsets determine instants. Offsetless timestamps use that zone, which defaults to `Asia/Kolkata`.
    /// Continuous history is documented for daily NFO and MCX futures using a live token.
    /// Applications own expired-token retention and request splitting. The SDK does not discover expired option tokens.
    ///
    /// - Parameters:
    ///   - instrumentToken: A positive Kite instrument token, not an exchange token.
    ///   - interval: The requested candle interval.
    ///   - from: The finite lower bound, no later than `to`. Equal bounds are allowed.
    ///   - to: The finite upper bound. Both bounds must have Gregorian years from 1 through 9999 in the configured zone.
    ///   - continuous: Whether to request continuous futures history. Requires ``KiteHistoricalInterval/day``.
    ///     Contract eligibility remains server-owned.
    ///   - oi: Whether every returned candle must contain open interest. Defaults to `false`.
    /// - Returns: Candles in server order, including an empty array when no candles are returned.
    ///   Supplied open interest is retained even when `oi` is `false`.
    /// - Throws: ``KiteError/validation(field:message:)`` for invalid bounds, a zero token, a missing access token,
    ///   or continuous history with a non-day interval. ``KiteError/decoding(statusCode:message:)`` reports
    ///   malformed rows, invalid timestamps, or missing requested open interest. API and transport errors
    ///   propagate, as does cancellation. The request is attempted once.
    func historicalCandles(
        instrumentToken: UInt32, interval: KiteHistoricalInterval, from: Date, to: Date,
        continuous: Bool = false, oi: Bool = false,
    ) async throws -> [KiteHistoricalCandle] {
        guard instrumentToken > 0 else {
            throw KiteError.validation(field: "instrumentToken", message: "Expected a positive token")
        }
        guard from.timeIntervalSince1970.isFinite, to.timeIntervalSince1970.isFinite, from <= to else {
            throw KiteError.validation(field: "from/to", message: "Expected finite, ordered bounds")
        }
        guard !continuous || interval == .day else {
            throw KiteError.validation(
                field: "continuous", message: "Continuous data requires day candles",
            )
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = configuration.tradingTimeZone
        for bound in [from, to] {
            let parts = calendar.dateComponents([.era, .year], from: bound)
            guard parts.era == 1, let year = parts.year, (1 ... 9999).contains(year) else {
                throw KiteError.validation(field: "from/to", message: "Expected four-digit Gregorian years")
            }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = configuration.tradingTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let response = try await response(
            for: KiteRequest(
                path: "/instruments/historical/\(instrumentToken)/\(interval.rawValue)",
                query: [
                    KiteParameter("from", formatter.string(from: from)),
                    KiteParameter("to", formatter.string(from: to)),
                    KiteParameter("continuous", continuous ? "1" : "0"),
                    KiteParameter("oi", oi ? "1" : "0"),
                ],
            ),
        )
        do {
            let result = try JSONDecoder().decode(HistoricalEnvelope.self, from: response.body)
            guard result.status == "success" else { throw HistoricalFailure("Expected success envelope") }
            return try result.data.candles.map { row in
                if oi, row.openInterest == nil {
                    throw HistoricalFailure("Missing requested open interest")
                }
                guard
                    let timestamp = KiteTimestamp.parse(
                        row.timestamp, timeZone: configuration.tradingTimeZone,
                    )
                else { throw HistoricalFailure("Invalid candle timestamp") }
                return KiteHistoricalCandle(
                    timestamp: timestamp, open: row.open, high: row.high,
                    low: row.low, close: row.close, volume: row.volume, openInterest: row.openInterest,
                )
            }
        } catch {
            throw KiteError.decoding(
                statusCode: response.statusCode, message: "Malformed historical candles: \(error)",
            )
        }
    }
}

private struct HistoricalFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) {
        self.description = description
    }
}

private struct HistoricalEnvelope: Decodable {
    let status: String
    let data: HistoricalData
}

private struct HistoricalData: Decodable { let candles: [HistoricalRow] }
private struct HistoricalRow: Decodable {
    let timestamp: String
    let open: Decimal
    let high: Decimal
    let low: Decimal
    let close: Decimal
    let volume: Int64
    let openInterest: Int64?
    init(from decoder: any Decoder) throws {
        var row = try decoder.unkeyedContainer()
        timestamp = try row.decode(String.self)
        open = try row.decode(Decimal.self)
        high = try row.decode(Decimal.self)
        low = try row.decode(Decimal.self)
        close = try row.decode(Decimal.self)
        volume = try row.decode(Int64.self)
        openInterest = row.isAtEnd ? nil : try row.decode(Int64.self)
        guard row.isAtEnd, volume >= 0, openInterest.map({ $0 >= 0 }) ?? true else {
            throw HistoricalFailure("Expected six or seven candle fields with nonnegative volume and OI")
        }
    }
}
