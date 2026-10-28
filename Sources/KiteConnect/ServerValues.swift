//
//  ServerValues.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// Open server enums keep known cases convenient without rejecting new server values.
public protocol KiteStringValue: Codable, Hashable, Sendable {
    /// Maps a server string to a known value or preserves it unchanged as an unknown value.
    ///
    /// - Parameter rawValue: Case-sensitive protocol text; do not normalize unfamiliar values.
    init(rawValue: String)
    /// The exact server spelling, including the original string for an unfamiliar value.
    var rawValue: String { get }
}

public extension KiteStringValue {
    /// Decodes a single string without rejecting unfamiliar protocol values.
    ///
    /// - Parameter decoder: The decoder positioned at a string value.
    /// - Throws: A decoding error if the value is not a string.
    init(from decoder: any Decoder) throws {
        try self.init(rawValue: decoder.singleValueContainer().decode(String.self))
    }

    /// Encodes the exact server spelling as a single string.
    ///
    /// - Parameter encoder: The destination encoder.
    /// - Throws: Any error raised by the encoder while writing the string.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A trading product code; server eligibility and margin rules remain broker-owned.
public enum KiteProduct: KiteStringValue {
    /// Cash-and-carry delivery product, encoded as CNC.
    case cnc
    /// Normal carry-forward product, encoded as NRML.
    case nrml
    /// Intraday margin product, encoded as MIS.
    case mis
    /// Bracket-order product code BO; representation does not imply current availability.
    case bo
    /// Cover-order product code CO; eligibility is determined by Kite.
    case co
    /// An unfamiliar server code retained verbatim, without implying request eligibility.
    case unknown(String)
    /// Preserves case-sensitive server text, mapping recognized spellings to known cases.
    ///
    /// - Parameter rawValue: The wire code; unfamiliar strings remain available through rawValue.
    public init(rawValue: String) {
        switch rawValue {
        case "CNC": self = .cnc
        case "NRML": self = .nrml
        case "MIS": self = .mis
        case "BO": self = .bo
        case "CO": self = .co
        default: self = .unknown(rawValue)
        }
    }

    /// The case-sensitive wire code, preserving unfamiliar strings without normalization.
    public var rawValue: String {
        switch self {
        case .cnc: "CNC"
        case .nrml: "NRML"
        case .mis: "MIS"
        case .bo: "BO"
        case .co: "CO"
        case let .unknown(value): value
        }
    }
}

/// An order execution type; price and trigger requirements depend on this value.
public enum KiteOrderType: KiteStringValue {
    /// Executes at available market prices; availability depends on the environment.
    case market
    /// Limits execution to the supplied limit price or better.
    case limit
    /// A trigger activates a limit order, encoded as SL.
    case stopLoss
    /// A trigger activates a market order, encoded as SL-M.
    case stopLossMarket
    /// An unfamiliar server code retained verbatim, without implying request eligibility.
    case unknown(String)
    /// Preserves case-sensitive server text, mapping recognized spellings to known cases.
    ///
    /// - Parameter rawValue: The wire code; unfamiliar strings remain available through rawValue.
    public init(rawValue: String) {
        switch rawValue {
        case "MARKET": self = .market
        case "LIMIT": self = .limit
        case "SL": self = .stopLoss
        case "SL-M": self = .stopLossMarket
        default: self = .unknown(rawValue)
        }
    }

    /// The case-sensitive wire code, preserving unfamiliar strings without normalization.
    public var rawValue: String {
        switch self {
        case .market: "MARKET"
        case .limit: "LIMIT"
        case .stopLoss: "SL"
        case .stopLossMarket: "SL-M"
        case let .unknown(value): value
        }
    }
}

/// An exchange or segment identifier carried in instrument identities and API responses.
public enum KiteExchange: KiteStringValue {
    /// National Stock Exchange cash segment, encoded as NSE.
    case nse
    /// National Stock Exchange futures and options segment, encoded as NFO.
    case nfo
    /// Bombay Stock Exchange cash segment, encoded as BSE.
    case bse
    /// Bombay Stock Exchange futures and options segment, encoded as BFO.
    case bfo
    /// National Stock Exchange currency derivatives segment, encoded as CDS.
    case cds
    /// Bombay Stock Exchange currency derivatives segment, encoded as BCD.
    case bcd
    /// Multi Commodity Exchange segment, encoded as MCX.
    case mcx
    /// Mutual-fund segment code MF; it does not add mutation support to the SDK.
    case mf
    /// An unfamiliar server code retained verbatim, without implying request eligibility.
    case unknown(String)
    /// Preserves case-sensitive server text, mapping recognized spellings to known cases.
    ///
    /// - Parameter rawValue: The wire code; unfamiliar strings remain available through rawValue.
    public init(rawValue: String) {
        switch rawValue {
        case "NSE": self = .nse
        case "NFO": self = .nfo
        case "BSE": self = .bse
        case "BFO": self = .bfo
        case "CDS": self = .cds
        case "BCD": self = .bcd
        case "MCX": self = .mcx
        case "MF": self = .mf
        default: self = .unknown(rawValue)
        }
    }

    /// The case-sensitive wire code, preserving unfamiliar strings without normalization.
    public var rawValue: String {
        switch self {
        case .nse: "NSE"
        case .nfo: "NFO"
        case .bse: "BSE"
        case .bfo: "BFO"
        case .cds: "CDS"
        case .bcd: "BCD"
        case .mcx: "MCX"
        case .mf: "MF"
        case let .unknown(value): value
        }
    }
}
