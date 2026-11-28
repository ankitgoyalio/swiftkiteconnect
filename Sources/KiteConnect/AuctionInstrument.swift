/// A security available in the holdings auction list.
public struct AuctionInstrument: Decodable, Equatable, Sendable {
    /// Kite's identifier for the auction.
    public let auctionNumber: String
    public let tradingSymbol: String
    public let exchange: String
    public let instrumentToken: UInt32
    public let isin: String
    public let product: String
    public let price: Double
    public let quantity: Int64
    public let t1Quantity: Int64
    public let realisedQuantity: Int64
    public let authorisedQuantity: Int64
    public let authorisedDate: String?
    public let openingQuantity: Int64
    public let collateralQuantity: Int64
    public let collateralType: String?
    public let discrepancy: Bool
    public let averagePrice: Double
    public let lastPrice: Double
    public let closePrice: Double
    public let pnl: Double
    public let dayChange: Double?
    public let dayChangePercentage: Double?

    private enum CodingKeys: String, CodingKey {
        case auctionNumber = "auction_number"
        case tradingSymbol = "tradingsymbol"
        case exchange
        case instrumentToken = "instrument_token"
        case isin
        case product
        case price
        case quantity
        case t1Quantity = "t1_quantity"
        case realisedQuantity = "realised_quantity"
        case authorisedQuantity = "authorised_quantity"
        case authorisedDate = "authorised_date"
        case openingQuantity = "opening_quantity"
        case collateralQuantity = "collateral_quantity"
        case collateralType = "collateral_type"
        case discrepancy
        case averagePrice = "average_price"
        case lastPrice = "last_price"
        case closePrice = "close_price"
        case pnl
        case dayChange = "day_change"
        case dayChangePercentage = "day_change_percentage"
    }
}

extension KiteConnectClient {
    /// Lists active auctions for securities in the user's holdings.
    public func auctions() async throws -> [AuctionInstrument] {
        try await rest.send(.init(.get, path: ["portfolio", "holdings", "auctions"]))
    }
}
