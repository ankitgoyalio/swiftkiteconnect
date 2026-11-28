import Foundation

/// A supported candle interval in Kite's historical data API.
public enum HistoricalInterval: String, Sendable {
    case minute
    case threeMinutes = "3minute"
    case fiveMinutes = "5minute"
    case tenMinutes = "10minute"
    case fifteenMinutes = "15minute"
    case thirtyMinutes = "30minute"
    case sixtyMinutes = "60minute"
    case day
}

/// The opening timestamp, prices and traded volume of a historical candle.
public struct HistoricalCandle: Decodable, Equatable, Sendable {
    public let timestamp: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: UInt64
    public let openInterest: Int64?

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.isLenient = false
        return formatter
    }()

    public init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        let timestamp = try values.decode(String.self)
        guard let date = Self.timestampFormatter.date(from: timestamp) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid historical candle timestamp."
            ))
        }
        self.timestamp = date
        open = try values.decode(Double.self)
        high = try values.decode(Double.self)
        low = try values.decode(Double.self)
        close = try values.decode(Double.self)
        volume = try values.decode(UInt64.self)
        openInterest = values.isAtEnd ? nil : try values.decodeIfPresent(Int64.self)
    }
}

extension KiteConnectClient {
    /// Returns historical candles in the order supplied by Kite.
    /// The request uses exchange time (Asia/Kolkata) at second precision.
    /// Pass `continuous: true` with `.day` for expired NFO or MCX futures candles.
    /// Pass `includeOpenInterest: true` to request open interest. A nil flag is omitted.
    public func historicalCandles(
        instrumentToken: UInt32,
        interval: HistoricalInterval,
        from: Date,
        to: Date,
        continuous: Bool? = nil,
        includeOpenInterest: Bool? = nil
    ) async throws -> [HistoricalCandle] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var query: [URLQueryItem] = [
            .init(name: "from", value: formatter.string(from: from)),
            .init(name: "to", value: formatter.string(from: to)),
        ]
        if let continuous {
            query.append(.init(name: "continuous", value: continuous ? "1" : "0"))
        }
        if let includeOpenInterest {
            query.append(.init(name: "oi", value: includeOpenInterest ? "1" : "0"))
        }

        let response = try await rest.send(.init(
            .get,
            path: ["instruments", "historical", String(instrumentToken), interval.rawValue],
            query: query
        ), as: HistoricalResponse.self)
        return response.candles
    }
}

private struct HistoricalResponse: Decodable {
    let candles: [HistoricalCandle]
}
