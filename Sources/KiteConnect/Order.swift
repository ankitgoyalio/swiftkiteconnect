import Foundation

/// An order snapshot from the Kite order book or an entry in its order history.
///
/// Timestamps retain Kite's wall-clock strings. Blank optional exchange identifiers
/// and timestamps are represented as nil.
public struct Order: Decodable, Equatable, Sendable {
    public let orderID: String
    public let exchangeOrderID: String?
    public let parentOrderID: String?
    public let accountID: String?
    public let terminalID: String?
    public let placedBy: String
    public let status: OrderStatus
    public let statusMessage: String?
    public let statusMessageRaw: String?
    public let orderTimestamp: String
    public let exchangeTimestamp: String?
    public let exchangeUpdateTimestamp: String?
    public let variety: OrderVariety
    public let modified: Bool?
    public let exchange: String
    public let tradingSymbol: String
    public let instrumentToken: UInt32
    public let orderType: OrderType
    public let transactionType: TransactionType
    public let validity: OrderValidity
    public let validityTTL: Int?
    public let product: OrderProduct
    public let quantity: Double
    public let disclosedQuantity: Double
    public let price: Double
    public let triggerPrice: Double
    public let averagePrice: Double
    public let filledQuantity: Double
    public let pendingQuantity: Double
    public let cancelledQuantity: Double
    public let marketProtection: Double?
    public let auctionNumber: String?
    public let meta: Metadata?
    public let tag: String?
    public let tags: [String]?
    public let guid: String?

    private enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case exchangeOrderID = "exchange_order_id"
        case parentOrderID = "parent_order_id"
        case accountID = "account_id"
        case terminalID = "terminal_id"
        case placedBy = "placed_by"
        case status
        case statusMessage = "status_message"
        case statusMessageRaw = "status_message_raw"
        case orderTimestamp = "order_timestamp"
        case exchangeTimestamp = "exchange_timestamp"
        case exchangeUpdateTimestamp = "exchange_update_timestamp"
        case variety, modified, exchange
        case tradingSymbol = "tradingsymbol"
        case instrumentToken = "instrument_token"
        case orderType = "order_type"
        case transactionType = "transaction_type"
        case validity
        case validityTTL = "validity_ttl"
        case product, quantity
        case disclosedQuantity = "disclosed_quantity"
        case price
        case triggerPrice = "trigger_price"
        case averagePrice = "average_price"
        case filledQuantity = "filled_quantity"
        case pendingQuantity = "pending_quantity"
        case cancelledQuantity = "cancelled_quantity"
        case marketProtection = "market_protection"
        case auctionNumber = "auction_number"
        case meta, tag, tags, guid
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        orderID = try values.decode(String.self, forKey: .orderID)
        exchangeOrderID = try values.decodeNonblankString(forKey: .exchangeOrderID)
        parentOrderID = try values.decodeNonblankString(forKey: .parentOrderID)
        accountID = try values.decodeNonblankString(forKey: .accountID)
        terminalID = try values.decodeNonblankString(forKey: .terminalID)
        placedBy = try values.decode(String.self, forKey: .placedBy)
        status = try values.decode(OrderStatus.self, forKey: .status)
        statusMessage = try values.decodeIfPresent(String.self, forKey: .statusMessage)
        statusMessageRaw = try values.decodeIfPresent(String.self, forKey: .statusMessageRaw)
        orderTimestamp = try values.decode(String.self, forKey: .orderTimestamp)
        exchangeTimestamp = try values.decodeNonblankString(forKey: .exchangeTimestamp)
        exchangeUpdateTimestamp = try values.decodeNonblankString(forKey: .exchangeUpdateTimestamp)
        variety = try values.decode(OrderVariety.self, forKey: .variety)
        modified = try values.decodeIfPresent(Bool.self, forKey: .modified)
        exchange = try values.decode(String.self, forKey: .exchange)
        tradingSymbol = try values.decode(String.self, forKey: .tradingSymbol)
        instrumentToken = try values.decode(UInt32.self, forKey: .instrumentToken)
        orderType = try values.decode(OrderType.self, forKey: .orderType)
        transactionType = try values.decode(TransactionType.self, forKey: .transactionType)
        validity = try values.decode(OrderValidity.self, forKey: .validity)
        validityTTL = try values.decodeIfPresent(Int.self, forKey: .validityTTL)
        product = try values.decode(OrderProduct.self, forKey: .product)
        quantity = try values.decode(Double.self, forKey: .quantity)
        disclosedQuantity = try values.decode(Double.self, forKey: .disclosedQuantity)
        price = try values.decode(Double.self, forKey: .price)
        triggerPrice = try values.decode(Double.self, forKey: .triggerPrice)
        averagePrice = try values.decode(Double.self, forKey: .averagePrice)
        filledQuantity = try values.decode(Double.self, forKey: .filledQuantity)
        pendingQuantity = try values.decode(Double.self, forKey: .pendingQuantity)
        cancelledQuantity = try values.decode(Double.self, forKey: .cancelledQuantity)
        marketProtection = try values.decodeIfPresent(Double.self, forKey: .marketProtection)
        auctionNumber = try values.decodeIfPresent(String.self, forKey: .auctionNumber)
        meta = try values.decodeIfPresent(Metadata.self, forKey: .meta)
        tag = try values.decodeIfPresent(String.self, forKey: .tag)
        tags = try values.decodeIfPresent([String].self, forKey: .tags)
        guid = try values.decodeIfPresent(String.self, forKey: .guid)
    }

    /// An arbitrary value attached to an order by Kite, such as iceberg leg details.
    public enum Metadata: Decodable, Equatable, Sendable {
        case object([String: Metadata])
        case array([Metadata])
        case string(String)
        case number(Decimal)
        case bool(Bool)
        case null

        public init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()
            if value.decodeNil() {
                self = .null
            } else if let object = try? value.decode([String: Metadata].self) {
                self = .object(object)
            } else if let array = try? value.decode([Metadata].self) {
                self = .array(array)
            } else if let string = try? value.decode(String.self) {
                self = .string(string)
            } else if let bool = try? value.decode(Bool.self) {
                self = .bool(bool)
            } else {
                self = .number(try value.decode(Decimal.self))
            }
        }
    }
}

extension KeyedDecodingContainer {
    func decodeNonblankString(forKey key: Key) throws -> String? {
        guard let value = try decodeIfPresent(String.self, forKey: key),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return value
    }
}
