/// Order parameters inside an Alert Triggers Order basket.
/// A decoded order preserves the server's params object when encoded for an update.
/// Typed fields use their authoring defaults when absent, or an empty string or zero for required fields.
public struct AlertBasketOrder: Codable, Equatable, Sendable {
    public struct GTT: Codable, Equatable, Sendable {
        public let target: Double
        public let stoploss: Double

        public init(target: Double, stoploss: Double) {
            self.target = target
            self.stoploss = stoploss
        }

        private enum CodingKeys: String, CodingKey { case target, stoploss }

        public init(from decoder: any Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            target = (try? fields.decode(Double.self, forKey: .target)) ?? 0
            stoploss = (try? fields.decode(Double.self, forKey: .stoploss)) ?? 0
        }
    }

    public let transactionType: String
    public let product: String
    public let orderType: String
    public let quantity: Int
    public let validity: String
    public let validityTTL: Int
    public let variety: String
    public let price: Double
    public let triggerPrice: Double
    public let disclosedQuantity: Int
    public let tags: [String]
    public let squareoff: Double
    public let stoploss: Double
    public let trailingStoploss: Double
    public let lastPrice: Double?
    public let icebergLegs: Int?
    public let marketProtection: Double?
    public let gtt: GTT?

    private let preservedParams: [String: AlertOrderMetadata]?

    public init(
        transactionType: String,
        product: String,
        orderType: String,
        quantity: Int,
        validity: String = "DAY",
        validityTTL: Int = 0,
        variety: String = "regular",
        price: Double = 0,
        triggerPrice: Double = 0,
        disclosedQuantity: Int = 0,
        tags: [String] = [],
        squareoff: Double = 0,
        stoploss: Double = 0,
        trailingStoploss: Double = 0,
        lastPrice: Double? = nil,
        icebergLegs: Int? = nil,
        marketProtection: Double? = nil,
        gtt: GTT? = nil
    ) {
        self.transactionType = transactionType
        self.product = product
        self.orderType = orderType
        self.quantity = quantity
        self.validity = validity
        self.validityTTL = validityTTL
        self.variety = variety
        self.price = price
        self.triggerPrice = triggerPrice
        self.disclosedQuantity = disclosedQuantity
        self.tags = tags
        self.squareoff = squareoff
        self.stoploss = stoploss
        self.trailingStoploss = trailingStoploss
        self.lastPrice = lastPrice
        self.icebergLegs = icebergLegs
        self.marketProtection = marketProtection
        self.gtt = gtt
        self.preservedParams = nil
    }

    private enum CodingKeys: String, CodingKey {
        case product, quantity, validity, variety, price, tags, squareoff, stoploss, gtt
        case transactionType = "transaction_type"
        case orderType = "order_type"
        case validityTTL = "validity_ttl"
        case triggerPrice = "trigger_price"
        case disclosedQuantity = "disclosed_quantity"
        case trailingStoploss = "trailing_stoploss"
        case lastPrice = "last_price"
        case icebergLegs = "iceberg_legs"
        case marketProtection = "market_protection"
    }

    public init(from decoder: any Decoder) throws {
        preservedParams = try decoder.singleValueContainer().decode([String: AlertOrderMetadata].self)
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, as type: T.Type = T.self) -> T? {
            try? fields.decode(type, forKey: key)
        }

        transactionType = value(.transactionType) ?? ""
        product = value(.product) ?? ""
        orderType = value(.orderType) ?? ""
        quantity = value(.quantity) ?? 0
        validity = value(.validity) ?? "DAY"
        validityTTL = value(.validityTTL) ?? 0
        variety = value(.variety) ?? "regular"
        price = value(.price) ?? 0
        triggerPrice = value(.triggerPrice) ?? 0
        disclosedQuantity = value(.disclosedQuantity) ?? 0
        tags = value(.tags) ?? []
        squareoff = value(.squareoff) ?? 0
        stoploss = value(.stoploss) ?? 0
        trailingStoploss = value(.trailingStoploss) ?? 0
        lastPrice = value(.lastPrice)
        icebergLegs = value(.icebergLegs)
        marketProtection = value(.marketProtection)
        gtt = value(.gtt)
    }

    public func encode(to encoder: any Encoder) throws {
        if let preservedParams {
            var value = encoder.singleValueContainer()
            try value.encode(preservedParams)
            return
        }

        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(transactionType, forKey: .transactionType)
        try fields.encode(product, forKey: .product)
        try fields.encode(orderType, forKey: .orderType)
        try fields.encode(quantity, forKey: .quantity)
        try fields.encode(validity, forKey: .validity)
        try fields.encode(validityTTL, forKey: .validityTTL)
        try fields.encode(variety, forKey: .variety)
        try fields.encode(price, forKey: .price)
        try fields.encode(triggerPrice, forKey: .triggerPrice)
        try fields.encode(disclosedQuantity, forKey: .disclosedQuantity)
        try fields.encode(tags, forKey: .tags)
        try fields.encode(squareoff, forKey: .squareoff)
        try fields.encode(stoploss, forKey: .stoploss)
        try fields.encode(trailingStoploss, forKey: .trailingStoploss)
        try fields.encodeIfPresent(lastPrice, forKey: .lastPrice)
        try fields.encodeIfPresent(icebergLegs, forKey: .icebergLegs)
        try fields.encodeIfPresent(marketProtection, forKey: .marketProtection)
        try fields.encodeIfPresent(gtt, forKey: .gtt)
    }
}

/// The basket sent when creating an Alert Triggers Order.
public struct AlertBasketCreate: Encodable, Sendable {
    public struct Item: Encodable, Sendable {
        public let exchange: String
        public let tradingSymbol: String
        public let weight: Int
        public let order: AlertBasketOrder

        public init(exchange: String, tradingSymbol: String, weight: Int, order: AlertBasketOrder) {
            self.exchange = exchange
            self.tradingSymbol = tradingSymbol
            self.weight = weight
            self.order = order
        }

        private enum CodingKeys: String, CodingKey {
            case type, id, exchange, weight
            case tradingSymbol = "tradingsymbol"
            case order = "params"
        }

        public func encode(to encoder: any Encoder) throws {
            try encode(to: encoder, type: "insert", id: nil)
        }

        fileprivate func encode(to encoder: any Encoder, type: String, id: Int?) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(type, forKey: .type)
            try values.encodeIfPresent(id, forKey: .id)
            try values.encode(exchange, forKey: .exchange)
            try values.encode(tradingSymbol, forKey: .tradingSymbol)
            try values.encode(weight, forKey: .weight)
            try values.encode(order, forKey: .order)
        }
    }

    public let name: String
    public let tags: [String]
    public let items: [Item]

    private let type = "alert"

    public init(name: String, tags: [String] = [], items: [Item]) {
        self.name = name
        self.tags = tags
        self.items = items
    }
}

/// The basket returned with an Alert Triggers Order.
public struct AlertBasket: Decodable, Equatable, Sendable {
    public struct Item: Decodable, Equatable, Sendable {
        public let id: Int?
        public let type: String?
        public let exchange: String
        public let tradingSymbol: String
        public let instrumentToken: Int?
        public let weight: Int
        public let order: AlertBasketOrder

        private enum CodingKeys: String, CodingKey {
            case id, type, exchange, weight
            case tradingSymbol = "tradingsymbol"
            case instrumentToken = "instrument_token"
            case order = "params"
        }
    }

    public let name: String?
    public let type: String?
    public let tags: [String]?
    public let items: [Item]
}

/// An operation applied to an existing Alert Triggers Order basket.
public enum AlertBasketOperation: Encodable, Sendable {
    case insert(AlertBasketCreate.Item)
    case update(id: Int, item: AlertBasketCreate.Item)
    case delete(id: Int)

    private enum CodingKeys: String, CodingKey { case type, id }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .insert(let item):
            try item.encode(to: encoder)
        case .update(let id, let item):
            try item.encode(to: encoder, type: "update", id: id)
        case .delete(let id):
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode("delete", forKey: .type)
            try values.encode(id, forKey: .id)
        }
    }
}
