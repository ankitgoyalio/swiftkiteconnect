import Foundation

extension KiteTicker {
    /// A market tick. Fields unavailable in the packet's mode or for its instrument are nil.
    public struct Tick: Sendable, Equatable {
        public let instrumentToken: UInt32
        public let lastPrice: Double
        public internal(set) var mode: Mode = .ltp
        public var isIndex: Bool { instrumentToken & 0xFF == 9 }

        public internal(set) var lastQuantity: UInt32?
        public internal(set) var averagePrice: Double?
        public internal(set) var volume: UInt32?
        public internal(set) var buyQuantity: UInt32?
        public internal(set) var sellQuantity: UInt32?
        public internal(set) var open: Double?
        public internal(set) var high: Double?
        public internal(set) var low: Double?
        public internal(set) var close: Double?

        /// Last traded price minus the previous close, matching Kite's Go SDK.
        public var netChange: Double? { close.map { lastPrice - $0 } }

        public internal(set) var lastTradeTime: Date?
        public internal(set) var exchangeTime: Date?
        public internal(set) var openInterest: UInt32?
        public internal(set) var openInterestDayHigh: UInt32?
        public internal(set) var openInterestDayLow: UInt32?
        public internal(set) var depth: MarketDepth?

        public init(instrumentToken: UInt32, lastPrice: Double) {
            self.instrumentToken = instrumentToken
            self.lastPrice = lastPrice
        }
    }

    /// Five bids and five offers in the order supplied by Kite.
    public struct MarketDepth: Sendable, Equatable {
        public let buy: [DepthEntry]
        public let sell: [DepthEntry]
    }

    public struct DepthEntry: Sendable, Equatable {
        public let quantity: UInt32
        public let price: Double
        public let orders: UInt16
    }
}
