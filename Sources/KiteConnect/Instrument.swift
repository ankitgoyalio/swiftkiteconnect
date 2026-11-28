import Foundation

/// An entry in Kite's daily instrument list.
public struct Instrument: Equatable, Sendable {
    public let instrumentToken: UInt32
    public let exchangeToken: UInt32
    public let tradingSymbol: String
    public let name: String
    public let lastPrice: Double
    /// The expiry calendar date as YYYY-MM-DD, when supplied.
    public let expiry: String?
    public let strike: Double?
    public let tickSize: Double
    public let lotSize: Int64
    public let instrumentType: String
    public let segment: String
    public let exchange: String

    fileprivate static let columns = [
        "instrument_token", "exchange_token", "tradingsymbol", "name", "last_price", "expiry",
        "strike", "tick_size", "lot_size", "instrument_type", "segment", "exchange",
    ]

    fileprivate init(row: CSV.Row) throws {
        instrumentToken = try row.integer("instrument_token")
        exchangeToken = try row.integer("exchange_token")
        tradingSymbol = try row.nonempty("tradingsymbol")
        name = try row.field("name")
        lastPrice = try row.decimal("last_price")
        let expiry = try row.field("expiry")
        self.expiry = expiry.isEmpty ? nil : expiry
        strike = try row.optionalDecimal("strike")
        tickSize = try row.decimal("tick_size")
        lotSize = try row.integer("lot_size")
        instrumentType = try row.field("instrument_type")
        segment = try row.field("segment")
        exchange = try row.nonempty("exchange")
    }
}

extension KiteConnectClient {
    /// Retrieves the daily instrument list for all exchanges.
    public func instruments() async throws -> [Instrument] {
        try await fetchInstruments(path: ["instruments"])
    }

    /// Retrieves the daily instrument list for a single exchange, such as NSE or NFO.
    public func instruments(exchange: String) async throws -> [Instrument] {
        try await fetchInstruments(path: ["instruments", exchange])
    }

    private func fetchInstruments(path: [String]) async throws -> [Instrument] {
        let (data, _) = try await rest.sendRaw(.init(.get, path: path))
        do {
            return try CSV.decode(data, requiredColumns: Instrument.columns, transform: Instrument.init(row:))
        } catch {
            throw KiteError.decoding(error)
        }
    }
}
