import Foundation

/// Known server values with lossless preservation of unfamiliar strings.
public enum KiteOrderStatus: KiteStringValue {
  case open, complete, cancelled, rejected, putOrderRequestReceived, validationPending, openPending,
    modifyValidationPending, modifyPending, triggerPending, cancelPending, amoRequestReceived,
    modified, update
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "OPEN": self = .open
    case "COMPLETE": self = .complete
    case "CANCELLED": self = .cancelled
    case "REJECTED": self = .rejected
    case "PUT ORDER REQ RECEIVED": self = .putOrderRequestReceived
    case "VALIDATION PENDING": self = .validationPending
    case "OPEN PENDING": self = .openPending
    case "MODIFY VALIDATION PENDING": self = .modifyValidationPending
    case "MODIFY PENDING": self = .modifyPending
    case "TRIGGER PENDING": self = .triggerPending
    case "CANCEL PENDING": self = .cancelPending
    case "AMO REQ RECEIVED": self = .amoRequestReceived
    case "MODIFIED": self = .modified
    case "UPDATE": self = .update
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .open: "OPEN"
    case .complete: "COMPLETE"
    case .cancelled: "CANCELLED"
    case .rejected: "REJECTED"
    case .putOrderRequestReceived: "PUT ORDER REQ RECEIVED"
    case .validationPending: "VALIDATION PENDING"
    case .openPending: "OPEN PENDING"
    case .modifyValidationPending: "MODIFY VALIDATION PENDING"
    case .modifyPending: "MODIFY PENDING"
    case .triggerPending: "TRIGGER PENDING"
    case .cancelPending: "CANCEL PENDING"
    case .amoRequestReceived: "AMO REQ RECEIVED"
    case .modified: "MODIFIED"
    case .update: "UPDATE"
    case .unknown(let value): value
    }
  }
}

/// Known server values with lossless preservation of unfamiliar strings.
public enum KiteTransactionType: KiteStringValue {
  case buy, sell
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "BUY": self = .buy
    case "SELL": self = .sell
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .buy: "BUY"
    case .sell: "SELL"
    case .unknown(let value): value
    }
  }
}

/// Known server values with lossless preservation of unfamiliar strings.
public enum KiteOrderValidity: KiteStringValue {
  case day, immediateOrCancel, timeToLive
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "DAY": self = .day
    case "IOC": self = .immediateOrCancel
    case "TTL": self = .timeToLive
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .day: "DAY"
    case .immediateOrCancel: "IOC"
    case .timeToLive: "TTL"
    case .unknown(let value): value
    }
  }
}

/// Known server values with lossless preservation of unfamiliar strings.
public enum KiteOrderVariety: KiteStringValue {
  case regular, afterMarket, cover, iceberg, auction
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "regular": self = .regular
    case "amo": self = .afterMarket
    case "co": self = .cover
    case "iceberg": self = .iceberg
    case "auction": self = .auction
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .regular: "regular"
    case .afterMarket: "amo"
    case .cover: "co"
    case .iceberg: "iceberg"
    case .auction: "auction"
    case .unknown(let value): value
    }
  }
}

/// Common state payload for REST, WebSocket order updates and postbacks.
/// Status may be null in postbacks; modified is absent in their documented payload.
/// REST reads enforce both fields through KiteOrder. Event envelope metadata and checksum
/// validation belong to the streaming/postback adapters, not this state model.
public struct KiteOrderUpdate: Decodable, Sendable, Equatable {
  public let orderID: String
  public let status: KiteOrderStatus?
  public let exchangeOrderID: String?
  public let parentOrderID: String?
  public let placedBy: String
  public let modified: Bool?
  public let exchange: KiteExchange
  public let tradingSymbol: String
  public let instrumentToken: UInt32
  public let variety: KiteOrderVariety
  public let transactionType: KiteTransactionType
  public let orderType: KiteOrderType
  public let product: KiteProduct
  public let validity: KiteOrderValidity
  public let quantity: Int64
  public let disclosedQuantity: Int64
  public let filledQuantity: Int64
  public let pendingQuantity: Int64
  public let cancelledQuantity: Int64
  public let price: Decimal
  public let triggerPrice: Decimal
  public let averagePrice: Decimal
  public let orderTimestamp: Date
  public let exchangeTimestamp: Date?
  public let exchangeUpdateTimestamp: Date?
  public let statusMessage: String?
  public let statusMessageRaw: String?
  public let marketProtection: Decimal?
  /// Present in order update/postback payloads; absent in REST examples.
  public let unfilledQuantity: Int64?
  public let validityTTL: Int64?
  public let auctionNumber: String?
  public let tag: String?
  public let tags: [String]?
  public let guid: String?
  public let accountID: String?
  public let terminalID: String?
  public let meta: KiteOrderMetadata?
  /// Original text, retained for postback checksum verification before any date formatting.
  public let orderTimestampRaw: String
  enum CodingKeys: String, CodingKey {
    case validityTTL = "validity_ttl"
    case auctionNumber = "auction_number"
    case tag = "tag"
    case tags = "tags"
    case guid = "guid"
    case accountID = "account_id"
    case terminalID = "terminal_id"
    case meta = "meta"
    case orderID = "order_id"
    case status = "status"
    case exchangeOrderID = "exchange_order_id"
    case parentOrderID = "parent_order_id"
    case placedBy = "placed_by"
    case modified = "modified"
    case exchange = "exchange"
    case tradingSymbol = "tradingsymbol"
    case instrumentToken = "instrument_token"
    case variety = "variety"
    case transactionType = "transaction_type"
    case orderType = "order_type"
    case product = "product"
    case validity = "validity"
    case quantity = "quantity"
    case disclosedQuantity = "disclosed_quantity"
    case filledQuantity = "filled_quantity"
    case pendingQuantity = "pending_quantity"
    case cancelledQuantity = "cancelled_quantity"
    case price = "price"
    case triggerPrice = "trigger_price"
    case averagePrice = "average_price"
    case orderTimestamp = "order_timestamp"
    case exchangeTimestamp = "exchange_timestamp"
    case exchangeUpdateTimestamp = "exchange_update_timestamp"
    case statusMessage = "status_message"
    case statusMessageRaw = "status_message_raw"
    case marketProtection = "market_protection"
    case unfilledQuantity = "unfilled_quantity"
  }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    orderID = try container.decode(String.self, forKey: .orderID)
    guard !orderID.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .orderID, in: container,
        debugDescription: "Expected a nonempty order ID")
    }
    status = try container.decodeIfPresent(KiteOrderStatus.self, forKey: .status)
    exchangeOrderID = try container.decodeIfPresent(String.self, forKey: .exchangeOrderID)
    parentOrderID = try container.decodeIfPresent(String.self, forKey: .parentOrderID)
    placedBy = try container.decode(String.self, forKey: .placedBy)
    modified = try container.decodeIfPresent(Bool.self, forKey: .modified)
    exchange = try container.decode(KiteExchange.self, forKey: .exchange)
    tradingSymbol = try container.decode(String.self, forKey: .tradingSymbol)
    instrumentToken = try decodeOrderInstrumentToken(container, forKey: .instrumentToken)
    variety = try container.decode(KiteOrderVariety.self, forKey: .variety)
    transactionType = try container.decode(KiteTransactionType.self, forKey: .transactionType)
    orderType = try container.decode(KiteOrderType.self, forKey: .orderType)
    product = try container.decode(KiteProduct.self, forKey: .product)
    validity = try container.decode(KiteOrderValidity.self, forKey: .validity)
    quantity = try container.decode(Int64.self, forKey: .quantity)
    disclosedQuantity = try container.decode(Int64.self, forKey: .disclosedQuantity)
    filledQuantity = try container.decode(Int64.self, forKey: .filledQuantity)
    pendingQuantity = try container.decode(Int64.self, forKey: .pendingQuantity)
    cancelledQuantity = try container.decode(Int64.self, forKey: .cancelledQuantity)
    price = try container.decode(Decimal.self, forKey: .price)
    triggerPrice = try container.decode(Decimal.self, forKey: .triggerPrice)
    averagePrice = try container.decode(Decimal.self, forKey: .averagePrice)
    orderTimestamp = try container.decode(Date.self, forKey: .orderTimestamp)
    exchangeTimestamp = try container.decodeIfPresent(Date.self, forKey: .exchangeTimestamp)
    exchangeUpdateTimestamp = try container.decodeIfPresent(
      Date.self, forKey: .exchangeUpdateTimestamp)
    statusMessage = try container.decodeIfPresent(String.self, forKey: .statusMessage)
    statusMessageRaw = try container.decodeIfPresent(String.self, forKey: .statusMessageRaw)
    marketProtection = try container.decodeIfPresent(Decimal.self, forKey: .marketProtection)
    unfilledQuantity = try container.decodeIfPresent(Int64.self, forKey: .unfilledQuantity)
    validityTTL = try container.decodeIfPresent(Int64.self, forKey: .validityTTL)
    auctionNumber = try container.decodeIfPresent(String.self, forKey: .auctionNumber)
    tag = try container.decodeIfPresent(String.self, forKey: .tag)
    tags = try container.decodeIfPresent([String].self, forKey: .tags)
    guid = try container.decodeIfPresent(String.self, forKey: .guid)
    accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
    terminalID = try container.decodeIfPresent(String.self, forKey: .terminalID)
    meta = try container.decodeIfPresent(KiteOrderMetadata.self, forKey: .meta)
    guard
      [quantity, disclosedQuantity, filledQuantity, pendingQuantity, cancelledQuantity].allSatisfy({
        $0 >= 0
      }),
      validityTTL.map({ $0 >= 0 }) ?? true, unfilledQuantity.map({ $0 >= 0 }) ?? true
    else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Expected nonnegative order quantities and validity TTL"))
    }
    orderTimestampRaw = try container.decode(String.self, forKey: .orderTimestamp)
  }
}

/// A strict REST order-book/history record. A successful submission alone does not prove a fill.
public struct KiteOrder: Decodable, Sendable, Equatable {
  public let update: KiteOrderUpdate
  public let status: KiteOrderStatus
  public let modified: Bool
  public var orderID: String { update.orderID }
  public var exchangeOrderID: String? { update.exchangeOrderID }
  public var parentOrderID: String? { update.parentOrderID }
  public var placedBy: String { update.placedBy }
  public var exchange: KiteExchange { update.exchange }
  public var tradingSymbol: String { update.tradingSymbol }
  public var instrumentToken: UInt32 { update.instrumentToken }
  public var variety: KiteOrderVariety { update.variety }
  public var transactionType: KiteTransactionType { update.transactionType }
  public var orderType: KiteOrderType { update.orderType }
  public var product: KiteProduct { update.product }
  public var validity: KiteOrderValidity { update.validity }
  public var quantity: Int64 { update.quantity }
  public var disclosedQuantity: Int64 { update.disclosedQuantity }
  public var filledQuantity: Int64 { update.filledQuantity }
  public var pendingQuantity: Int64 { update.pendingQuantity }
  public var cancelledQuantity: Int64 { update.cancelledQuantity }
  public var price: Decimal { update.price }
  public var triggerPrice: Decimal { update.triggerPrice }
  public var averagePrice: Decimal { update.averagePrice }
  public var orderTimestamp: Date { update.orderTimestamp }
  public var exchangeTimestamp: Date? { update.exchangeTimestamp }
  public var exchangeUpdateTimestamp: Date? { update.exchangeUpdateTimestamp }
  public var statusMessage: String? { update.statusMessage }
  public var statusMessageRaw: String? { update.statusMessageRaw }
  public var marketProtection: Decimal? { update.marketProtection }
  public var validityTTL: Int64? { update.validityTTL }
  public var auctionNumber: String? { update.auctionNumber }
  public var tag: String? { update.tag }
  public var tags: [String]? { update.tags }
  public var guid: String? { update.guid }
  public var accountID: String? { update.accountID }
  public var terminalID: String? { update.terminalID }
  public var meta: KiteOrderMetadata? { update.meta }
  public var orderTimestampRaw: String { update.orderTimestampRaw }
  public init(from decoder: any Decoder) throws {
    update = try KiteOrderUpdate(from: decoder)
    let container = try decoder.container(keyedBy: KiteOrderUpdate.CodingKeys.self)
    status = try container.decode(KiteOrderStatus.self, forKey: .status)
    modified = try container.decode(Bool.self, forKey: .modified)
  }
}

/// The documented trade examples contain a clock time without a date for order_timestamp.
/// Preserve that distinction: a time of day is not an instant and has no inferred date or zone.
public enum KiteTradeOrderTimestamp: Sendable, Equatable {
  case timeOfDay(hour: Int, minute: Int, second: Int)
  case instant(Date)
}

/// One exchange execution (partial fill). Multiple trades may refer to the same order.
public struct KiteTrade: Decodable, Sendable, Equatable {
  public let tradeID: String
  public let orderID: String
  public let exchangeOrderID: String?
  public let exchange: KiteExchange
  public let tradingSymbol: String
  public let instrumentToken: UInt32
  public let product: KiteProduct
  public let transactionType: KiteTransactionType
  public let averagePrice: Decimal
  /// The table calls this field filled; JSON examples use quantity. Either spelling is accepted.
  public let quantity: Int64
  public let filled: Int64?
  public let fillTimestamp: Date
  public let exchangeTimestamp: Date
  public let orderTimestamp: KiteTradeOrderTimestamp
  public let orderTimestampRaw: String
  enum CodingKeys: String, CodingKey {
    case exchange, product, quantity, filled
    case tradeID = "trade_id"
    case orderID = "order_id"
    case exchangeOrderID = "exchange_order_id"
    case tradingSymbol = "tradingsymbol"
    case instrumentToken = "instrument_token"
    case transactionType = "transaction_type"
    case averagePrice = "average_price"
    case fillTimestamp = "fill_timestamp"
    case exchangeTimestamp = "exchange_timestamp"
    case orderTimestamp = "order_timestamp"
  }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    tradeID = try container.decode(String.self, forKey: .tradeID)
    guard !tradeID.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .tradeID, in: container,
        debugDescription: "Expected a nonempty trade ID")
    }
    orderID = try container.decode(String.self, forKey: .orderID)
    guard !orderID.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .orderID, in: container,
        debugDescription: "Expected a nonempty order ID")
    }
    exchangeOrderID = try container.decodeIfPresent(String.self, forKey: .exchangeOrderID)
    exchange = try container.decode(KiteExchange.self, forKey: .exchange)
    tradingSymbol = try container.decode(String.self, forKey: .tradingSymbol)
    instrumentToken = try decodeOrderInstrumentToken(container, forKey: .instrumentToken)
    product = try container.decode(KiteProduct.self, forKey: .product)
    transactionType = try container.decode(KiteTransactionType.self, forKey: .transactionType)
    averagePrice = try container.decode(Decimal.self, forKey: .averagePrice)
    filled = try container.decodeIfPresent(Int64.self, forKey: .filled)
    if container.contains(.quantity) {
      quantity = try container.decode(Int64.self, forKey: .quantity)
    } else {
      quantity = try container.decode(Int64.self, forKey: .filled)
    }
    guard quantity >= 0, filled.map({ $0 >= 0 }) ?? true else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Expected nonnegative trade quantities"))
    }
    fillTimestamp = try container.decode(Date.self, forKey: .fillTimestamp)
    exchangeTimestamp = try container.decode(Date.self, forKey: .exchangeTimestamp)
    orderTimestampRaw = try container.decode(String.self, forKey: .orderTimestamp)
    if orderTimestampRaw.range(of: #"\A[0-9]{2}:[0-9]{2}:[0-9]{2}\z"#, options: .regularExpression)
      != nil
    {
      let parts = orderTimestampRaw.split(separator: ":").compactMap { Int($0) }
      guard parts[0] < 24, parts[1] < 60, parts[2] < 60 else {
        throw DecodingError.dataCorruptedError(
          forKey: .orderTimestamp, in: container,
          debugDescription: "Invalid trade order clock time")
      }
      orderTimestamp = .timeOfDay(hour: parts[0], minute: parts[1], second: parts[2])
    } else {
      orderTimestamp = .instant(try container.decode(Date.self, forKey: .orderTimestamp))
    }
  }
}

/// Arbitrary order metadata, including nested iceberg details. Numeric values stay decimal.
public indirect enum KiteOrderMetadata: Decodable, Sendable, Equatable {
  case object([String: KiteOrderMetadata])
  case array([KiteOrderMetadata])
  case string(String)
  case number(Decimal)
  case bool(Bool)
  case null

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([String: KiteOrderMetadata].self) {
      self = .object(value)
    } else if let value = try? container.decode([KiteOrderMetadata].self) {
      self = .array(value)
    } else {
      self = .number(try container.decode(Decimal.self))
    }
  }
}

// The orders response tables say string while their JSON examples use numeric tokens.
private func decodeOrderInstrumentToken<Key: CodingKey>(
  _ container: KeyedDecodingContainer<Key>, forKey key: Key
) throws -> UInt32 {
  if let raw = try? container.decode(String.self, forKey: key) {
    guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }), let token = UInt32(raw)
    else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: container,
        debugDescription: "Expected a uint32 instrument token")
    }
    return token
  }
  return try container.decode(UInt32.self, forKey: key)
}
