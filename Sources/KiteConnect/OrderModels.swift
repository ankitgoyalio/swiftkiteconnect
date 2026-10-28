//
//  OrderModels.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// The order lifecycle state reported by Kite, retaining unfamiliar server strings.
public enum KiteOrderStatus: KiteStringValue {
    /// The order is open and may still receive executions.
    case open
    /// Kite reports the order as complete; inspect trades for individual fills.
    case complete
    /// Kite reports cancellation; earlier partial fills remain possible.
    case cancelled
    /// Kite reports rejection; inspect the associated reason and any earlier fills.
    case rejected
    /// Kite has received the placement request for processing.
    case putOrderRequestReceived
    /// The order is awaiting server validation before further processing.
    case validationPending
    /// The order is awaiting transition to the open state.
    case openPending
    /// The modification is awaiting validation by Kite.
    case modifyValidationPending
    /// The order modification is pending server processing.
    case modifyPending
    /// The stop-loss order is awaiting its trigger condition.
    case triggerPending
    /// Cancellation is pending; the order can still receive fills.
    case cancelPending
    /// Kite has received the after-market placement request.
    case amoRequestReceived
    /// Kite reports an order modification in the notification state.
    case modified
    /// Kite reports an intermediate order-state update.
    case update
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Maps exact server spellings to known cases without rejecting unfamiliar values.
    ///
    /// - Parameter rawValue: Case-sensitive wire text; unknown values remain unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "OPEN": self = .open
        case "COMPLETE": self = .complete
        case "CANCELLED": self = .cancelled
        case "REJECTED": self = .rejected
        case "PUT ORDER REQ RECEIVED": self = .putOrderRequestReceived
        case "VALIDATION PENDING": self = .validationPending
        case "OPEN PENDING": self = .openPending
        case "MODIFY VALIDATION PENDING": self = .modifyValidationPending
        case "MODIFY PENDING": self = .modifyPending
        case "TRIGGER PENDING": self = .triggerPending
        case "CANCEL PENDING": self = .cancelPending
        case "AMO REQ RECEIVED": self = .amoRequestReceived
        case "MODIFIED": self = .modified
        case "UPDATE": self = .update
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .open: "OPEN"
        case .complete: "COMPLETE"
        case .cancelled: "CANCELLED"
        case .rejected: "REJECTED"
        case .putOrderRequestReceived: "PUT ORDER REQ RECEIVED"
        case .validationPending: "VALIDATION PENDING"
        case .openPending: "OPEN PENDING"
        case .modifyValidationPending: "MODIFY VALIDATION PENDING"
        case .modifyPending: "MODIFY PENDING"
        case .triggerPending: "TRIGGER PENDING"
        case .cancelPending: "CANCEL PENDING"
        case .amoRequestReceived: "AMO REQ RECEIVED"
        case .modified: "MODIFIED"
        case .update: "UPDATE"
        case let .unknown(value): value
        }
    }
}

/// The buy or sell direction reported by Kite, retaining unfamiliar server strings.
public enum KiteTransactionType: KiteStringValue {
    /// A purchase direction encoded as the BUY wire value.
    case buy
    /// A sale direction encoded as the SELL wire value.
    case sell
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Maps exact server spellings to known cases without rejecting unfamiliar values.
    ///
    /// - Parameter rawValue: Case-sensitive wire text; unknown values remain unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "BUY": self = .buy
        case "SELL": self = .sell
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .buy: "BUY"
        case .sell: "SELL"
        case let .unknown(value): value
        }
    }
}

/// The server-reported order lifetime instruction, including DAY, IOC, and TTL.
public enum KiteOrderValidity: KiteStringValue {
    /// The DAY instruction keeps the order valid for the trading day.
    case day
    /// The IOC instruction executes available quantity and cancels the remainder.
    case immediateOrCancel
    /// The TTL instruction uses a supplied lifetime in minutes.
    case timeToLive
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Maps exact server spellings to known cases without rejecting unfamiliar values.
    ///
    /// - Parameter rawValue: Case-sensitive wire text; unknown values remain unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "DAY": self = .day
        case "IOC": self = .immediateOrCancel
        case "TTL": self = .timeToLive
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .day: "DAY"
        case .immediateOrCancel: "IOC"
        case .timeToLive: "TTL"
        case let .unknown(value): value
        }
    }
}

/// The server-reported order routing variety, retaining unfamiliar wire values.
public enum KiteOrderVariety: KiteStringValue {
    /// The regular standalone order route used for ordinary orders.
    case regular
    /// The after-market order variety encoded as amo on the wire.
    case afterMarket
    /// The cover order variety with a linked protective order leg.
    case cover
    /// The iceberg variety divides the order into configured legs.
    case iceberg
    /// The auction variety requires a supplied auction session number.
    case auction
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Maps exact server spellings to known cases without rejecting unfamiliar values.
    ///
    /// - Parameter rawValue: Case-sensitive wire text; unknown values remain unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "regular": self = .regular
        case "amo": self = .afterMarket
        case "co": self = .cover
        case "iceberg": self = .iceberg
        case "auction": self = .auction
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .regular: "regular"
        case .afterMarket: "amo"
        case .cover: "co"
        case .iceberg: "iceberg"
        case .auction: "auction"
        case let .unknown(value): value
        }
    }
}
