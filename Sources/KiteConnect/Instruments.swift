//
//  Instruments.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// An entry in the daily instrument catalogue, with decimal prices and a date-only expiry.
///
/// Use ``identity`` for persistent storage. Numeric tokens can be reused after derivative expiry.
/// The catalogue is not a live quote feed. See <doc:Discover-instruments>.
public struct KiteInstrument: Sendable, Equatable {
    /// The Kite numeric token used for subscriptions and historical requests, which may be reused after expiry.
    public let instrumentToken: UInt32
    /// The exchange-issued numeric token reported in the daily catalogue.
    public let exchangeToken: UInt32
    /// The exchange-local trading symbol, taken from ``identity``.
    public var tradingSymbol: String {
        identity.tradingSymbol
    }

    /// The exchange and trading symbol used as the persistent instrument key.
    public let identity: KiteInstrumentIdentity
    /// The catalogue name, or `nil` when the CSV name field is empty.
    public let name: String?
    /// The last price recorded in the daily dump, which is not a live quote.
    public let lastPrice: Decimal
    /// The contract expiry as a calendar date without a time zone, or `nil` for an empty expiry field.
    public let expiry: KiteDateOnly?
    /// The strike price supplied by the catalogue, or `nil` for an empty strike field.
    public let strike: Decimal?
    /// The minimum price increment reported by the catalogue.
    public let tickSize: Decimal
    /// The trading lot size reported by the catalogue, retained as an integer quantity.
    public let lotSize: Int64
    /// The instrument classification, retaining unfamiliar server strings as an unknown case.
    public let instrumentType: KiteInstrumentType
    /// The exchange segment string, such as `NFO-OPT`, retained without a closed list of values.
    public let segment: String
    /// The exchange from ``identity``, including unfamiliar server values.
    public var exchange: KiteExchange {
        identity.exchange
    }
}

public extension KiteClient {
    /// Downloads the daily instrument catalogue, optionally restricted to one exchange.
    ///
    /// Applications own caching, refresh schedules, and expired-token mappings. The dump bypasses
    /// ``KiteConfiguration/routePrefix`` and uses session credentials only when present.
    /// Injected transports must return HTTP-decoded bytes. The default URLSession transport handles gzip.
    ///
    /// - Parameter exchange: An exchange identifier containing only ASCII letters, digits, hyphens,
    ///   or underscores. `nil` requests all exchanges.
    /// - Returns: Catalogue entries in CSV row order, or an empty array for a header-only dump.
    /// - Throws: ``KiteError/validation(field:message:)`` for an invalid exchange,
    ///   ``KiteError/decoding(statusCode:message:)`` for malformed CSV, or API and transport errors.
    ///   Cancellation propagates as `CancellationError`. The request is attempted once.
    func instruments(exchange: KiteExchange? = nil) async throws -> [KiteInstrument] {
        if let exchange = exchange?.rawValue {
            guard !exchange.isEmpty,
                  exchange.utf8.allSatisfy({
                      (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 45
                          || $0 == 95
                  })
            else {
                throw KiteError.validation(
                    field: "exchange", message: "Expected a single exchange identifier",
                )
            }
        }
        let response = try await response(
            for: KiteRequest(
                path: "/instruments" + (exchange.map { "/" + $0.rawValue } ?? ""),
                authenticated: accessToken != nil,
                isInstrumentDump: true,
            ),
        )
        do { return try parseInstruments(response.body) } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw KiteError.decoding(statusCode: response.statusCode, message: String(describing: error))
        }
    }
}

private func parseInstruments(_ data: Data) throws -> [KiteInstrument] {
    let required = [
        "instrument_token", "exchange_token", "tradingsymbol", "name", "last_price", "expiry", "strike",
        "tick_size", "lot_size", "instrument_type", "segment", "exchange",
    ]
    let table = try KiteCSV.Table(data, required: required)
    return try table.rows.enumerated().map { offset, values in
        let row = try table.row(values, record: offset + 2)
        let identity: KiteInstrumentIdentity
        do {
            identity = try KiteInstrumentIdentity(
                exchange: KiteExchange(rawValue: row.nonempty("exchange")),
                tradingSymbol: row.nonempty("tradingsymbol"),
            )
        } catch { throw row.failure("exchange/tradingsymbol") }
        let expiry: KiteDateOnly?
        do { expiry = try row.value("expiry").nilIfEmpty.map { try KiteDateOnly($0) } } catch {
            throw row.failure("expiry")
        }
        return try KiteInstrument(
            instrumentToken: row.integer("instrument_token", UInt32.init),
            exchangeToken: row.integer("exchange_token", UInt32.init),
            identity: identity, name: row.value("name").nilIfEmpty,
            lastPrice: row.decimal("last_price"), expiry: expiry,
            strike: row.value("strike").isEmpty ? nil : row.decimal("strike"),
            tickSize: row.decimal("tick_size"), lotSize: row.integer("lot_size", Int64.init),
            instrumentType: KiteInstrumentType(rawValue: row.nonempty("instrument_type")),
            segment: row.nonempty("segment"),
        )
    }
}

private extension String { var nilIfEmpty: String? {
    isEmpty ? nil : self
} }

/// An instrument classification from the daily catalogue, preserving unfamiliar server strings.
public enum KiteInstrumentType: KiteStringValue {
    /// An equity instrument, represented by `EQ` in the catalogue.
    case equity
    /// A futures contract, represented by `FUT` in the catalogue.
    case future
    /// A call option contract, represented by `CE` in the catalogue.
    case call
    /// A put option contract, represented by `PE` in the catalogue.
    case put
    /// An unfamiliar instrument classification with its original server string.
    case unknown(String)
    /// Maps `EQ`, `FUT`, `CE`, and `PE` to known cases and retains every other string as ``unknown(_:)``.
    ///
    /// - Parameter rawValue: The unmodified instrument type string from Kite.
    public init(rawValue: String) {
        switch rawValue {
        case "EQ": self = .equity
        case "FUT": self = .future
        case "CE": self = .call
        case "PE": self = .put
        default: self = .unknown(rawValue)
        }
    }

    /// The Kite wire value, preserving the original string for an unknown classification.
    public var rawValue: String {
        switch self {
        case .equity: "EQ"
        case .future: "FUT"
        case .call: "CE"
        case .put: "PE"
        case let .unknown(value): value
        }
    }
}
