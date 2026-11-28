import Foundation

/// Parameters for placing a Kite order. Kite validates values for the selected variety.
/// Optional fields are omitted when nil.
public struct OrderPlacement: Sendable {
    public let exchange: String
    public let tradingSymbol: String
    public let transactionType: TransactionType
    public let orderType: OrderType
    public let quantity: Int
    public let product: OrderProduct
    public var validity: OrderValidity?
    public var price: Double?
    public var triggerPrice: Double?
    public var disclosedQuantity: Int?
    /// Lifetime in minutes for `.ttl` orders.
    public var validityTTL: Int?
    /// Total number of legs for an iceberg order.
    public var icebergLegs: Int?
    /// Quantity per leg for an iceberg order.
    public var icebergQuantity: Int?
    /// The auction identifier returned by Kite for the instrument.
    public var auctionNumber: String?
    /// For market and stop-loss market orders, use -1 for automatic protection or a positive percentage up to 100.
    public var marketProtection: Double?
    /// Enables slicing when the requested quantity exceeds the exchange freeze limit.
    public var autoslice: Bool?
    /// An optional alphanumeric identifier of at most 20 characters.
    public var tag: String?

    public init(
        exchange: String,
        tradingSymbol: String,
        transactionType: TransactionType,
        orderType: OrderType,
        quantity: Int,
        product: OrderProduct,
        validity: OrderValidity? = nil,
        price: Double? = nil,
        triggerPrice: Double? = nil,
        disclosedQuantity: Int? = nil,
        validityTTL: Int? = nil,
        icebergLegs: Int? = nil,
        icebergQuantity: Int? = nil,
        auctionNumber: String? = nil,
        marketProtection: Double? = nil,
        autoslice: Bool? = nil,
        tag: String? = nil
    ) {
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
        self.transactionType = transactionType
        self.orderType = orderType
        self.quantity = quantity
        self.product = product
        self.validity = validity
        self.price = price
        self.triggerPrice = triggerPrice
        self.disclosedQuantity = disclosedQuantity
        self.validityTTL = validityTTL
        self.icebergLegs = icebergLegs
        self.icebergQuantity = icebergQuantity
        self.auctionNumber = auctionNumber
        self.marketProtection = marketProtection
        self.autoslice = autoslice
        self.tag = tag
    }

    fileprivate var form: [URLQueryItem] {
        orderFields([
            ("exchange", exchange),
            ("tradingsymbol", tradingSymbol),
            ("transaction_type", transactionType.rawValue),
            ("order_type", orderType.rawValue),
            ("quantity", String(quantity)),
            ("product", product.rawValue),
            ("validity", validity?.rawValue),
            ("price", orderDecimal(price)),
            ("trigger_price", orderDecimal(triggerPrice)),
            ("disclosed_quantity", disclosedQuantity.map(String.init)),
            ("validity_ttl", validityTTL.map(String.init)),
            ("iceberg_legs", icebergLegs.map(String.init)),
            ("iceberg_quantity", icebergQuantity.map(String.init)),
            ("auction_number", auctionNumber),
            ("market_protection", orderDecimal(marketProtection)),
            ("autoslice", autoslice.map { String($0) }),
            ("tag", tag),
        ])
    }
}

/// Changes to an open or pending Kite order. Each nil field is omitted.
public struct OrderModification: Sendable {
    public var orderType: OrderType?
    public var quantity: Int?
    public var price: Double?
    public var triggerPrice: Double?
    public var disclosedQuantity: Int?
    public var validity: OrderValidity?
    /// For market and stop-loss market orders, use -1 for automatic protection or a positive percentage up to 100.
    public var marketProtection: Double?

    public init(
        orderType: OrderType? = nil,
        quantity: Int? = nil,
        price: Double? = nil,
        triggerPrice: Double? = nil,
        disclosedQuantity: Int? = nil,
        validity: OrderValidity? = nil,
        marketProtection: Double? = nil
    ) {
        self.orderType = orderType
        self.quantity = quantity
        self.price = price
        self.triggerPrice = triggerPrice
        self.disclosedQuantity = disclosedQuantity
        self.validity = validity
        self.marketProtection = marketProtection
    }

    fileprivate func form(parentOrderID: String?) -> [URLQueryItem] {
        orderFields([
            ("order_type", orderType?.rawValue),
            ("quantity", quantity.map(String.init)),
            ("price", orderDecimal(price)),
            ("trigger_price", orderDecimal(triggerPrice)),
            ("disclosed_quantity", disclosedQuantity.map(String.init)),
            ("validity", validity?.rawValue),
            ("market_protection", orderDecimal(marketProtection)),
            ("parent_order_id", parentOrderID),
        ])
    }
}

/// Kite's acknowledgement of an order request. Use the order book or trades to check execution.
public struct OrderAcknowledgement: Decodable, Equatable, Sendable {
    /// The parent order ID when Kite returns autoslice children.
    public let orderID: String
    /// Outcomes in the order reported by Kite. Nil when no list was returned.
    public let children: [OrderSliceOutcome]?

    private enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case children
    }
}

/// The result of placing one child of an autoslice order.
public enum OrderSliceOutcome: Decodable, Equatable, Sendable {
    case placed(orderID: String)
    case failed(OrderSliceError)

    private enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case error
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let orderID = try values.decodeIfPresent(String.self, forKey: .orderID)
        let error = try values.decodeIfPresent(OrderSliceError.self, forKey: .error)
        switch (orderID, error) {
        case (let orderID?, nil):
            self = .placed(orderID: orderID)
        case (nil, let error?):
            self = .failed(error)
        default:
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a slice order ID or a slice error."
            ))
        }
    }
}

/// An error reported for an individual autoslice child in a successful placement response.
public struct OrderSliceError: Error, Decodable, Equatable, Sendable {
    /// The error code for this child.
    public let code: Int
    public let errorType: String
    public let message: String
    /// Additional service data, including an explicit JSON null.
    public let data: Order.Metadata

    public var kind: KiteServiceError.Kind? { .init(rawValue: errorType) }

    private enum CodingKeys: String, CodingKey {
        case code, message, data
        case errorType = "error_type"
    }
}

extension KiteConnectClient {
    /// Places an order. Route the request through a static IP registered with Zerodha.
    /// After a timeout, reconcile with `orders()` before deciding whether to submit again.
    public func placeOrder(_ variety: OrderVariety, parameters: OrderPlacement) async throws -> OrderAcknowledgement {
        try await rest.send(.init(.post, path: ["orders", variety.rawValue], body: .form(parameters.form)))
    }

    /// Changes the supplied fields of an open or pending order.
    /// Supply the parent order ID if Kite requires it for the second leg of a cover order.
    public func modifyOrder(
        _ variety: OrderVariety,
        orderID: String,
        parentOrderID: String? = nil,
        parameters: OrderModification
    ) async throws -> OrderAcknowledgement {
        try await rest.send(.init(
            .put,
            path: ["orders", variety.rawValue, orderID],
            body: .form(parameters.form(parentOrderID: parentOrderID))
        ))
    }

    /// Cancels an open or pending order or exits the second leg of a cover order.
    /// Supply the parent order ID when Kite requires it for the second leg.
    public func cancelOrder(
        _ variety: OrderVariety,
        orderID: String,
        parentOrderID: String? = nil
    ) async throws -> OrderAcknowledgement {
        try await rest.send(.init(
            .delete,
            path: ["orders", variety.rawValue, orderID],
            query: orderFields([("parent_order_id", parentOrderID)])
        ))
    }
}

private func orderFields(_ fields: [(String, String?)]) -> [URLQueryItem] {
    fields.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
}

private func orderDecimal(_ value: Double?) -> String? {
    value.map { number in
        let text = String(number)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }
}
