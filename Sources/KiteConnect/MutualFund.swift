import Foundation

/// An order to buy or sell mutual fund units.
/// Dates and timestamps retain the strings supplied by Kite.
public struct MutualFundOrder: Decodable, Equatable, Sendable {
    public let orderID: String
    public let exchangeOrderID: String?
    /// The ISIN of the fund.
    public let tradingSymbol: String
    public let status: String?
    public let statusMessage: String?
    public let folio: String?
    public let fund: String
    public let orderTimestamp: String
    public let exchangeTimestamp: String?
    public let settlementID: String?
    public let transactionType: String
    public let variety: String
    public let purchaseType: String?
    public let quantity: Double
    public let amount: Double
    public let price: Double?
    public let lastPrice: Double
    public let lastPriceDate: String?
    public let averagePrice: Double
    public let placedBy: String
    public let tag: String?

    private enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case exchangeOrderID = "exchange_order_id"
        case tradingSymbol = "tradingsymbol"
        case status
        case statusMessage = "status_message"
        case folio, fund
        case orderTimestamp = "order_timestamp"
        case exchangeTimestamp = "exchange_timestamp"
        case settlementID = "settlement_id"
        case transactionType = "transaction_type"
        case variety
        case purchaseType = "purchase_type"
        case quantity, amount, price
        case lastPrice = "last_price"
        case lastPriceDate = "last_price_date"
        case averagePrice = "average_price"
        case placedBy = "placed_by"
        case tag
    }
}

/// An open systematic investment plan for a mutual fund.
public struct MutualFundSIP: Decodable, Equatable, Sendable {
    public let sipID: String
    public let registrationNumber: String?
    /// The ISIN of the fund.
    public let tradingSymbol: String
    public let fund: String
    public let dividendType: String
    public let transactionType: String
    public let status: String
    public let sipType: String?
    public let created: String
    public let frequency: String
    public let nextInstalment: String?
    public let lastInstalment: String?
    public let instalmentAmount: Double
    /// A value of -1 indicates the SIP runs until cancelled.
    public let instalments: Int
    public let pendingInstalments: Int
    public let instalmentDay: Int
    public let completedInstalments: Int
    public let triggerPrice: Double?
    /// Step-up percentages keyed by day and month (DD-MM).
    public let stepUp: [String: Int]?
    public let tag: String?

    private enum CodingKeys: String, CodingKey {
        case sipID = "sip_id"
        case registrationNumber = "sip_reg_num"
        case tradingSymbol = "tradingsymbol"
        case fund
        case dividendType = "dividend_type"
        case transactionType = "transaction_type"
        case status
        case sipType = "sip_type"
        case created, frequency
        case nextInstalment = "next_instalment"
        case lastInstalment = "last_instalment"
        case instalmentAmount = "instalment_amount"
        case instalments
        case pendingInstalments = "pending_instalments"
        case instalmentDay = "instalment_day"
        case completedInstalments = "completed_instalments"
        case triggerPrice = "trigger_price"
        case stepUp = "step_up"
        case tag
    }
}

/// Allotted mutual fund units held in the user's demat account.
public struct MutualFundHolding: Decodable, Equatable, Sendable {
    public let folio: String?
    public let fund: String?
    /// The ISIN of the fund.
    public let tradingSymbol: String
    public let averagePrice: Double
    public let lastPrice: Double
    /// The latest NAV date supplied by Kite, which can be an empty string.
    public let lastPriceDate: String?
    public let pnl: Double
    public let quantity: Double
    public let pledgedQuantity: Double?

    private enum CodingKeys: String, CodingKey {
        case folio, fund
        case tradingSymbol = "tradingsymbol"
        case averagePrice = "average_price"
        case lastPrice = "last_price"
        case lastPriceDate = "last_price_date"
        case pnl, quantity
        case pledgedQuantity = "pledged_quantity"
    }
}

/// An entry in Kite's mutual fund instrument list.
public struct MutualFundInstrument: Equatable, Sendable {
    /// The ISIN of the fund.
    public let tradingSymbol: String
    public let amc: String
    public let name: String
    public let purchaseAllowed: Bool
    public let redemptionAllowed: Bool
    public let minimumPurchaseAmount: Double
    public let purchaseAmountMultiplier: Double
    public let minimumAdditionalPurchaseAmount: Double
    public let minimumRedemptionQuantity: Double
    public let redemptionQuantityMultiplier: Double
    public let dividendType: String
    public let schemeType: String
    public let plan: String
    public let settlementType: String
    public let lastPrice: Double
    /// The latest NAV date as YYYY-MM-DD.
    public let lastPriceDate: String

    fileprivate static let columns = [
        "tradingsymbol", "amc", "name", "purchase_allowed", "redemption_allowed",
        "minimum_purchase_amount", "purchase_amount_multiplier", "minimum_additional_purchase_amount",
        "minimum_redemption_quantity", "redemption_quantity_multiplier", "dividend_type", "scheme_type",
        "plan", "settlement_type", "last_price", "last_price_date",
    ]

    fileprivate init(row: CSV.Row) throws {
        tradingSymbol = try row.nonempty("tradingsymbol")
        amc = try row.field("amc")
        name = try row.field("name")
        purchaseAllowed = try Self.flag("purchase_allowed", in: row)
        redemptionAllowed = try Self.flag("redemption_allowed", in: row)
        minimumPurchaseAmount = try row.decimal("minimum_purchase_amount")
        purchaseAmountMultiplier = try row.decimal("purchase_amount_multiplier")
        minimumAdditionalPurchaseAmount = try row.decimal("minimum_additional_purchase_amount")
        minimumRedemptionQuantity = try row.decimal("minimum_redemption_quantity")
        redemptionQuantityMultiplier = try row.decimal("redemption_quantity_multiplier")
        dividendType = try row.field("dividend_type")
        schemeType = try row.field("scheme_type")
        plan = try row.field("plan")
        settlementType = try row.field("settlement_type")
        lastPrice = try row.decimal("last_price")
        lastPriceDate = try row.field("last_price_date")
    }

    private static func flag(_ column: String, in row: CSV.Row) throws -> Bool {
        switch try row.field(column) {
        case "0": return false
        case "1": return true
        default: throw CSVError(row: row.number, reason: "Invalid value in column \(column).")
        }
    }
}

extension KiteConnectClient {
    /// Retrieves mutual fund orders placed within the last seven days.
    public func mutualFundOrders() async throws -> [MutualFundOrder] {
        try await rest.send(.init(.get, path: ["mf", "orders"]))
    }

    /// Retrieves a mutual fund order by its Kite order ID, regardless of its age.
    public func mutualFundOrder(orderID: String) async throws -> MutualFundOrder {
        try await rest.send(.init(.get, path: ["mf", "orders", orderID]))
    }

    /// Retrieves active and paused mutual fund SIPs.
    public func mutualFundSIPs() async throws -> [MutualFundSIP] {
        // The documented SIP listing can contain data without a top-level status.
        try await rest.send(.init(.get, path: ["mf", "sips"]), allowsOmittedStatus: true)
    }

    /// Retrieves allotted mutual fund holdings from the user's demat account.
    public func mutualFundHoldings() async throws -> [MutualFundHolding] {
        try await rest.send(.init(.get, path: ["mf", "holdings"]))
    }

    /// Retrieves the master list of mutual fund instruments available on Coin.
    public func mutualFundInstruments() async throws -> [MutualFundInstrument] {
        let data = try await rest.sendCSV(.init(.get, path: ["mf", "instruments"]))
        do {
            return try CSV.decode(
                data,
                requiredColumns: MutualFundInstrument.columns,
                transform: MutualFundInstrument.init(row:)
            )
        } catch {
            throw KiteError.decoding(error)
        }
    }
}
