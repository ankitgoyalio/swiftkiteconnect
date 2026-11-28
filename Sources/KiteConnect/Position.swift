/// The aggregate open portfolio and the current day's trading activity.
public struct Positions: Decodable, Equatable, Sendable {
    public let net: [Position]
    public let day: [Position]
}

/// The quantities, prices and trading activity for one instrument and product.
public struct Position: Decodable, Equatable, Sendable {
    public let tradingSymbol: String
    public let exchange: String
    public let instrumentToken: UInt32
    public let product: String
    public let quantity: Int64
    public let overnightQuantity: Int64
    public let multiplier: Double
    public let averagePrice: Double
    public let closePrice: Double
    public let lastPrice: Double
    public let value: Double
    public let pnl: Double
    public let m2m: Double
    public let unrealised: Double
    public let realised: Double
    public let buyQuantity: Int64
    public let buyPrice: Double
    public let buyValue: Double
    public let buyM2M: Double
    public let sellQuantity: Int64
    public let sellPrice: Double
    public let sellValue: Double
    public let sellM2M: Double
    public let dayBuyQuantity: Int64
    public let dayBuyPrice: Double
    public let dayBuyValue: Double
    public let daySellQuantity: Int64
    public let daySellPrice: Double
    public let daySellValue: Double

    private enum CodingKeys: String, CodingKey {
        case tradingSymbol = "tradingsymbol"
        case exchange
        case instrumentToken = "instrument_token"
        case product
        case quantity
        case overnightQuantity = "overnight_quantity"
        case multiplier
        case averagePrice = "average_price"
        case closePrice = "close_price"
        case lastPrice = "last_price"
        case value
        case pnl
        case m2m
        case unrealised
        case realised
        case buyQuantity = "buy_quantity"
        case buyPrice = "buy_price"
        case buyValue = "buy_value"
        case buyM2M = "buy_m2m"
        case sellQuantity = "sell_quantity"
        case sellPrice = "sell_price"
        case sellValue = "sell_value"
        case sellM2M = "sell_m2m"
        case dayBuyQuantity = "day_buy_quantity"
        case dayBuyPrice = "day_buy_price"
        case dayBuyValue = "day_buy_value"
        case daySellQuantity = "day_sell_quantity"
        case daySellPrice = "day_sell_price"
        case daySellValue = "day_sell_value"
    }
}

extension KiteConnectClient {
    /// Retrieves the user's net and day positions.
    public func positions() async throws -> Positions {
        try await rest.send(.init(.get, path: ["portfolio", "positions"]))
    }
}
