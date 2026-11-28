import Foundation

/// The exchange and trading symbol used to identify an instrument in quote requests.
public struct InstrumentKey: Hashable, Sendable {
    public let exchange: String
    public let tradingSymbol: String

    public init(exchange: String, tradingSymbol: String) {
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
    }

    /// The key Kite uses for this instrument in quote responses.
    public var rawValue: String { "\(exchange):\(tradingSymbol)" }
}

/// Opening, high, low and previous closing prices in a market snapshot.
public struct QuoteOHLC: Decodable, Equatable, Sendable {
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
}

/// The bid and ask levels in a full market quote.
public struct QuoteDepth: Decodable, Equatable, Sendable {
    public let buy: [Level]
    public let sell: [Level]

    public struct Level: Decodable, Equatable, Sendable {
        public let price: Double
        public let quantity: Int64
        public let orders: Int64
    }
}

/// A full market data snapshot. Fields that depend on the instrument may be absent.
public struct MarketQuote: Decodable, Equatable, Sendable {
    public let instrumentToken: UInt32
    /// The exchange-local quote timestamp in Kite's YYYY-MM-DD HH:MM:SS format.
    public let timestamp: String
    /// The exchange-local last trade timestamp, when supplied.
    public let lastTradeTime: String?
    public let lastPrice: Double
    public let lastQuantity: Int64?
    public let buyQuantity: Int64?
    public let sellQuantity: Int64?
    public let volume: Int64?
    public let averagePrice: Double?
    public let openInterest: Double?
    public let openInterestDayHigh: Double?
    public let openInterestDayLow: Double?
    public let netChange: Double
    public let lowerCircuitLimit: Double?
    public let upperCircuitLimit: Double?
    public let ohlc: QuoteOHLC
    public let depth: QuoteDepth?

    private enum CodingKeys: String, CodingKey {
        case timestamp, volume, ohlc, depth
        case instrumentToken = "instrument_token"
        case lastTradeTime = "last_trade_time"
        case lastPrice = "last_price"
        case lastQuantity = "last_quantity"
        case buyQuantity = "buy_quantity"
        case sellQuantity = "sell_quantity"
        case averagePrice = "average_price"
        case openInterest = "oi"
        case openInterestDayHigh = "oi_day_high"
        case openInterestDayLow = "oi_day_low"
        case netChange = "net_change"
        case lowerCircuitLimit = "lower_circuit_limit"
        case upperCircuitLimit = "upper_circuit_limit"
    }
}

/// A snapshot containing the latest traded price and OHLC prices.
public struct OHLCQuote: Decodable, Equatable, Sendable {
    public let instrumentToken: UInt32
    public let lastPrice: Double
    public let ohlc: QuoteOHLC

    private enum CodingKeys: String, CodingKey {
        case instrumentToken = "instrument_token"
        case lastPrice = "last_price"
        case ohlc
    }
}

/// A last traded price snapshot.
public struct LTPQuote: Decodable, Equatable, Sendable {
    public let instrumentToken: UInt32
    public let lastPrice: Double

    private enum CodingKeys: String, CodingKey {
        case instrumentToken = "instrument_token"
        case lastPrice = "last_price"
    }
}

extension KiteConnectClient {
    /// Retrieves full market quotes keyed by `exchange:tradingsymbol`.
    /// Kite omits the keys of instruments for which it has no data.
    public func quote(instruments: [InstrumentKey]) async throws -> [String: MarketQuote] {
        try await fetchQuotes(path: ["quote"], instruments: instruments)
    }

    /// Retrieves OHLC and last traded prices keyed by `exchange:tradingsymbol`.
    /// Kite omits the keys of instruments for which it has no data.
    public func ohlc(instruments: [InstrumentKey]) async throws -> [String: OHLCQuote] {
        try await fetchQuotes(path: ["quote", "ohlc"], instruments: instruments)
    }

    /// Retrieves last traded prices keyed by `exchange:tradingsymbol`.
    /// Kite omits the keys of instruments for which it has no data.
    public func ltp(instruments: [InstrumentKey]) async throws -> [String: LTPQuote] {
        try await fetchQuotes(path: ["quote", "ltp"], instruments: instruments)
    }

    private func fetchQuotes<Value: Decodable>(
        path: [String], instruments: [InstrumentKey]
    ) async throws -> [String: Value] {
        let query = instruments.map { URLQueryItem(name: "i", value: $0.rawValue) }
        return try await rest.send(.init(.get, path: path, query: query))
    }
}
