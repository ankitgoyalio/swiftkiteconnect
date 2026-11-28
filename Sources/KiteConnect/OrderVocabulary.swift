/// A Kite order's current status. The raw value preserves statuses added by Kite.
public struct OrderStatus: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let open = Self(rawValue: "OPEN")
    public static let complete = Self(rawValue: "COMPLETE")
    public static let cancelled = Self(rawValue: "CANCELLED")
    public static let rejected = Self(rawValue: "REJECTED")
    public static let putOrderRequestReceived = Self(rawValue: "PUT ORDER REQ RECEIVED")
    public static let validationPending = Self(rawValue: "VALIDATION PENDING")
    public static let openPending = Self(rawValue: "OPEN PENDING")
    public static let modifyValidationPending = Self(rawValue: "MODIFY VALIDATION PENDING")
    public static let modifyPending = Self(rawValue: "MODIFY PENDING")
    public static let modified = Self(rawValue: "MODIFIED")
    public static let triggerPending = Self(rawValue: "TRIGGER PENDING")
    public static let cancelPending = Self(rawValue: "CANCEL PENDING")
    public static let amoRequestReceived = Self(rawValue: "AMO REQ RECEIVED")
}

/// The Kite variety used to route an order.
public struct OrderVariety: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let regular = Self(rawValue: "regular")
    public static let amo = Self(rawValue: "amo")
    public static let co = Self(rawValue: "co")
    public static let iceberg = Self(rawValue: "iceberg")
    public static let auction = Self(rawValue: "auction")
}

/// A Kite order's execution instructions.
public struct OrderType: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let market = Self(rawValue: "MARKET")
    public static let limit = Self(rawValue: "LIMIT")
    public static let stopLoss = Self(rawValue: "SL")
    public static let stopLossMarket = Self(rawValue: "SL-M")
}

/// The side of a Kite order or trade.
public struct TransactionType: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let buy = Self(rawValue: "BUY")
    public static let sell = Self(rawValue: "SELL")
}

/// The margin product used by a Kite order or trade.
public struct OrderProduct: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let cnc = Self(rawValue: "CNC")
    public static let nrml = Self(rawValue: "NRML")
    public static let mis = Self(rawValue: "MIS")
    public static let mtf = Self(rawValue: "MTF")
}

/// The lifetime policy of a Kite order.
public struct OrderValidity: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let day = Self(rawValue: "DAY")
    public static let ioc = Self(rawValue: "IOC")
    public static let ttl = Self(rawValue: "TTL")
}
