//
//  Alerts.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// The simple notification or alert-triggered order basket kind reported by Kite.
public enum KiteAlertType: KiteStringValue {
    /// An alert that reports its condition without an order-triggering basket.
    case simple
    /// An alert with a basket of orders to submit when its condition fires.
    case ato
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Creates a known case from its exact wire string, preserving any unfamiliar value unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "simple": self = .simple
        case "ato": self = .ato
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .simple: "simple"
        case .ato: "ato"
        case let .unknown(raw): raw
        }
    }
}

/// The alert lifecycle state, preserving unfamiliar server strings for compatibility.
public enum KiteAlertStatus: KiteStringValue {
    /// The alert is enabled for server-side condition evaluation.
    case enabled
    /// The server has disabled this trigger or alert definition.
    case disabled
    /// The server reports this trigger or alert as deleted.
    case deleted
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Creates a known case from its exact wire string, preserving any unfamiliar value unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "enabled": self = .enabled
        case "disabled": self = .disabled
        case "deleted": self = .deleted
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .enabled: "enabled"
        case .disabled: "disabled"
        case .deleted: "deleted"
        case let .unknown(raw): raw
        }
    }
}

/// The comparison operator between alert operands, preserving unfamiliar response strings.
public enum KiteAlertOperator: KiteStringValue {
    /// The comparison succeeds when the left operand is less than or equal to the right.
    case lessThanOrEqual
    /// The comparison succeeds when the left operand is greater than or equal to the right.
    case greaterThanOrEqual
    /// The comparison succeeds when the left operand is less than the right.
    case lessThan
    /// The comparison succeeds when the left operand is greater than the right.
    case greaterThan
    /// The comparison succeeds when both operand values are equal.
    case equal
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Creates a known case from its exact wire string, preserving any unfamiliar value unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "<=": self = .lessThanOrEqual
        case ">=": self = .greaterThanOrEqual
        case "<": self = .lessThan
        case ">": self = .greaterThan
        case "==": self = .equal
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .lessThanOrEqual: "<="
        case .greaterThanOrEqual: ">="
        case .lessThan: "<"
        case .greaterThan: ">"
        case .equal: "=="
        case let .unknown(raw): raw
        }
    }
}

/// The right-hand operand kind reported in an alert response.
public enum KiteAlertOperandType: KiteStringValue {
    /// A decimal constant used as the right-hand comparison operand.
    case constant
    /// An instrument attribute used as the right-hand comparison operand.
    case instrument
    /// An unfamiliar server value retained with its original wire string.
    case unknown(String)
    /// Creates a known case from its exact wire string, preserving any unfamiliar value unchanged.
    public init(rawValue: String) {
        switch rawValue {
        case "constant": self = .constant
        case "instrument": self = .instrument
        default: self = .unknown(rawValue)
        }
    }

    /// The exact wire string; unfamiliar response strings are preserved without substitution.
    public var rawValue: String {
        switch self {
        case .constant: "constant"
        case .instrument: "instrument"
        case let .unknown(raw): raw
        }
    }
}
