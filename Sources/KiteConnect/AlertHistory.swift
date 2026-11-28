import Foundation

/// An alert trigger and the market data captured when it fired.
public struct AlertHistory: Decodable, Equatable, Sendable {
    public let uuid: String
    public let type: AlertType
    public let meta: [AlertHistoryQuote]
    public let condition: String
    public let createdAt: String
    public let orderMeta: AlertOrderMetadata?

    private enum CodingKeys: String, CodingKey {
        case uuid, type, meta, condition
        case createdAt = "created_at"
        case orderMeta = "order_meta"
    }
}

/// An instrument snapshot captured when an alert fired.
public struct AlertHistoryQuote: Decodable, Equatable, Sendable {
    public struct OHLC: Decodable, Equatable, Sendable {
        public let open: Double
        public let high: Double
        public let low: Double
        public let close: Double
    }

    public let instrumentToken: Int
    public let tradingSymbol: String
    public let timestamp: String
    public let lastPrice: Double
    public let ohlc: OHLC
    public let netChange: Double
    public let exchange: String
    public let lastTradeTime: String?
    public let lastQuantity: Int
    public let buyQuantity: Int
    public let sellQuantity: Int
    public let volume: Int
    public let volumeTick: Int
    public let averagePrice: Double
    public let openInterest: Int
    public let openInterestDayHigh: Int
    public let openInterestDayLow: Int
    public let lowerCircuitLimit: Double
    public let upperCircuitLimit: Double

    private enum CodingKeys: String, CodingKey {
        case timestamp, ohlc, exchange, volume
        case instrumentToken = "instrument_token"
        case tradingSymbol = "tradingsymbol"
        case lastPrice = "last_price"
        case netChange = "net_change"
        case lastTradeTime = "last_trade_time"
        case lastQuantity = "last_quantity"
        case buyQuantity = "buy_quantity"
        case sellQuantity = "sell_quantity"
        case volumeTick = "volume_tick"
        case averagePrice = "average_price"
        case openInterest = "oi"
        case openInterestDayHigh = "oi_day_high"
        case openInterestDayLow = "oi_day_low"
        case lowerCircuitLimit = "lower_circuit_limit"
        case upperCircuitLimit = "upper_circuit_limit"
    }
}

/// Order metadata returned for an ATO trigger. Kite does not specify a fixed schema for this field.
public enum AlertOrderMetadata: Codable, Equatable, Sendable {
    case object([String: Self])
    case array([Self])
    case string(String)
    case number(Decimal)
    case boolean(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let boolean = try? value.decode(Bool.self) {
            self = .boolean(boolean)
        } else if let string = try? value.decode(String.self) {
            self = .string(string)
        } else if let number = try? value.decode(Decimal.self) {
            self = .number(number)
        } else if let array = try? value.decode([Self].self) {
            self = .array(array)
        } else {
            self = .object(try value.decode([String: Self].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .object(let object): try value.encode(object)
        case .array(let array): try value.encode(array)
        case .string(let string): try value.encode(string)
        case .number(let number): try value.encode(number)
        case .boolean(let boolean): try value.encode(boolean)
        case .null: try value.encodeNil()
        }
    }
}

extension KiteConnectClient {
    /// Retrieves the trigger history for an alert.
    public func alertHistory(uuid: String) async throws -> [AlertHistory] {
        try await rest.send(.init(.get, path: ["alerts", uuid, "history"]))
    }
}
