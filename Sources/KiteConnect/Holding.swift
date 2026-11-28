/// An equity holding and its settlement, valuation and margin trading details.
public struct Holding: Decodable, Equatable, Sendable {
    public let tradingSymbol: String
    public let exchange: String
    public let instrumentToken: UInt32
    public let isin: String
    public let product: String
    public let price: Double
    public let quantity: Int64
    public let usedQuantity: Int64
    public let t1Quantity: Int64
    public let realisedQuantity: Int64
    public let authorisedQuantity: Int64
    /// The authorisation date and time as supplied by Kite.
    public let authorisedDate: String?
    /// Authorised quantities keyed by transfer type and then by the timestamp supplied by Kite.
    public let authorisation: [String: [String: Int64]]?
    public let openingQuantity: Int64
    public let shortQuantity: Int64?
    public let collateralQuantity: Int64
    public let collateralType: String?
    public let discrepancy: Bool
    public let averagePrice: Double
    public let lastPrice: Double
    public let closePrice: Double
    public let pnl: Double
    public let dayChange: Double?
    public let dayChangePercentage: Double?
    public let mtf: MarginTradingDetails?

    /// The margin trading facility portion of a holding.
    public struct MarginTradingDetails: Decodable, Equatable, Sendable {
        public let quantity: Int64
        public let usedQuantity: Int64
        public let averagePrice: Double
        public let value: Double
        public let initialMargin: Double

        private enum CodingKeys: String, CodingKey {
            case quantity
            case usedQuantity = "used_quantity"
            case averagePrice = "average_price"
            case value
            case initialMargin = "initial_margin"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case tradingSymbol = "tradingsymbol"
        case exchange
        case instrumentToken = "instrument_token"
        case isin
        case product
        case price
        case quantity
        case usedQuantity = "used_quantity"
        case t1Quantity = "t1_quantity"
        case realisedQuantity = "realised_quantity"
        case authorisedQuantity = "authorised_quantity"
        case authorisedDate = "authorised_date"
        case authorisation
        case openingQuantity = "opening_quantity"
        case shortQuantity = "short_quantity"
        case collateralQuantity = "collateral_quantity"
        case collateralType = "collateral_type"
        case discrepancy
        case averagePrice = "average_price"
        case lastPrice = "last_price"
        case closePrice = "close_price"
        case pnl
        case dayChange = "day_change"
        case dayChangePercentage = "day_change_percentage"
        case mtf
    }
}

extension KiteConnectClient {
    /// Retrieves the user's equity holdings.
    public func holdings() async throws -> [Holding] {
        try await rest.send(.init(.get, path: ["portfolio", "holdings"]))
    }
}
