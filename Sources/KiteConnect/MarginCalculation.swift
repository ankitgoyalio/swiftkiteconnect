import Foundation

/// An order to include in an individual or basket margin calculation.
public struct MarginOrder: Encodable, Equatable, Sendable {
    public let exchange: String
    public let tradingSymbol: String
    public let transactionType: String
    public let variety: String
    public let product: String
    public let orderType: String
    public let quantity: Int64
    public let price: Double?
    public let triggerPrice: Double?

    /// Supply a price for limit orders and a trigger price for SL, SL-M, and CO orders.
    /// Nil prices are omitted from the request.
    public init(
        exchange: String,
        tradingSymbol: String,
        transactionType: String,
        variety: String,
        product: String,
        orderType: String,
        quantity: Int64,
        price: Double? = nil,
        triggerPrice: Double? = nil
    ) {
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
        self.transactionType = transactionType
        self.variety = variety
        self.product = product
        self.orderType = orderType
        self.quantity = quantity
        self.price = price
        self.triggerPrice = triggerPrice
    }

    private enum CodingKeys: String, CodingKey {
        case exchange, variety, product, quantity, price
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case orderType = "order_type"
        case triggerPrice = "trigger_price"
    }
}

/// An executed or hypothetical order to include in a virtual contract note.
public struct ChargeOrder: Encodable, Equatable, Sendable {
    public let orderID: String
    public let exchange: String
    public let tradingSymbol: String
    public let transactionType: String
    public let variety: String
    public let product: String
    public let orderType: String
    public let quantity: Int64
    public let averagePrice: Double

    /// Supply a unique order ID and a nonzero average price.
    /// For a hypothetical order, the ID can be any unique string.
    public init(
        orderID: String,
        exchange: String,
        tradingSymbol: String,
        transactionType: String,
        variety: String,
        product: String,
        orderType: String,
        quantity: Int64,
        averagePrice: Double
    ) {
        self.orderID = orderID
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
        self.transactionType = transactionType
        self.variety = variety
        self.product = product
        self.orderType = orderType
        self.quantity = quantity
        self.averagePrice = averagePrice
    }

    private enum CodingKeys: String, CodingKey {
        case exchange, variety, product, quantity
        case orderID = "order_id"
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case orderType = "order_type"
        case averagePrice = "average_price"
    }
}

/// An order or basket margin total with the breakdown supplied by Kite.
/// Compact responses may omit all fields except `total`.
public struct OrderMargin: Decodable, Equatable, Sendable {
    public let marginType: String?
    public let tradingSymbol: String?
    public let exchange: String?
    public let span: Double?
    public let exposure: Double?
    public let optionPremium: Double?
    public let additional: Double?
    public let bo: Double?
    public let cash: Double?
    public let varMargin: Double?
    public let pnl: ProfitAndLoss?
    public let leverage: Double?
    public let charges: ChargeBreakdown?
    public let total: Double

    public struct ProfitAndLoss: Decodable, Equatable, Sendable {
        public let realised: Double
        public let unrealised: Double
    }

    private enum CodingKeys: String, CodingKey {
        case exchange, span, exposure, additional, bo, cash, pnl, leverage, charges, total
        case marginType = "type"
        case tradingSymbol = "tradingsymbol"
        case optionPremium = "option_premium"
        case varMargin = "var"
    }
}

/// Initial, final, and per-order margins for a basket.
public struct BasketMargins: Decodable, Equatable, Sendable {
    /// Margin required to execute the orders.
    public let initial: OrderMargin
    /// Margin with the spread benefit applied.
    public let final: OrderMargin
    /// Per-order margins, when included by Kite.
    public let orders: [OrderMargin]?
    /// Aggregate charges, which may omit taxes reported in the per-order charges.
    public let charges: ChargeBreakdown?
}

/// The virtual contract note for one order.
public struct OrderCharge: Decodable, Equatable, Sendable {
    public let exchange: String
    public let tradingSymbol: String
    public let transactionType: String
    public let variety: String
    public let product: String
    public let orderType: String
    public let quantity: Int64
    public let price: Double
    public let charges: ChargeBreakdown

    private enum CodingKeys: String, CodingKey {
        case exchange, variety, product, quantity, price, charges
        case tradingSymbol = "tradingsymbol"
        case transactionType = "transaction_type"
        case orderType = "order_type"
    }
}

/// Taxes, fees, and brokerage returned by the margin and virtual contract note APIs.
public struct ChargeBreakdown: Decodable, Equatable, Sendable {
    public let transactionTax: Double
    public let transactionTaxType: String
    public let exchangeTurnoverCharge: Double
    public let sebiTurnoverCharge: Double
    public let brokerage: Double
    public let stampDuty: Double
    public let gst: GST
    public let total: Double

    public struct GST: Decodable, Equatable, Sendable {
        public let igst: Double
        public let cgst: Double
        public let sgst: Double
        public let total: Double
    }

    private enum CodingKeys: String, CodingKey {
        case brokerage, gst, total
        case transactionTax = "transaction_tax"
        case transactionTaxType = "transaction_tax_type"
        case exchangeTurnoverCharge = "exchange_turnover_charge"
        case sebiTurnoverCharge = "sebi_turnover_charge"
        case stampDuty = "stamp_duty"
    }
}

extension KiteConnectClient {
    /// Estimates margins for each order, considering existing positions and open orders.
    /// Pass `compact: true` to send `mode=compact` and request totals only.
    public func orderMargins(_ orders: [MarginOrder], compact: Bool = false) async throws -> [OrderMargin] {
        let query: [URLQueryItem] = compact ? [.init(name: "mode", value: "compact")] : []
        return try await rest.send(.init(
            .post,
            path: ["margins", "orders"],
            query: query,
            body: .json(RESTRequest.encodeJSON(orders))
        ))
    }

    /// Estimates initial and final margin requirements for a basket of orders.
    /// Pass `considerPositions: true` to include existing positions. Nil omits `consider_positions`.
    /// Pass `compact: true` to send `mode=compact` and request totals only.
    public func basketMargins(
        _ orders: [MarginOrder],
        considerPositions: Bool? = nil,
        compact: Bool = false
    ) async throws -> BasketMargins {
        var query: [URLQueryItem] = []
        if let considerPositions {
            query.append(.init(name: "consider_positions", value: String(considerPositions)))
        }
        if compact {
            query.append(.init(name: "mode", value: "compact"))
        }
        return try await rest.send(.init(
            .post,
            path: ["margins", "basket"],
            query: query,
            body: .json(RESTRequest.encodeJSON(orders))
        ))
    }

    /// Calculates virtual contract notes with a breakdown of charges for each order.
    public func orderCharges(_ orders: [ChargeOrder]) async throws -> [OrderCharge] {
        try await rest.send(.init(
            .post,
            path: ["charges", "orders"],
            body: .json(RESTRequest.encodeJSON(orders))
        ))
    }
}
