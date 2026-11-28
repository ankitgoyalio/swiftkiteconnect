/// Order parameters inside an Alert Triggers Order basket.
public struct AlertBasketOrder: Codable, Equatable, Sendable {
    public struct GTT: Codable, Equatable, Sendable {
        public let target: Double
        public let stoploss: Double

        public init(target: Double, stoploss: Double) {
            self.target = target
            self.stoploss = stoploss
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
