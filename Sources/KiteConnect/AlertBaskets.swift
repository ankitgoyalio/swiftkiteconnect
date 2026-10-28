import Foundation

/// ATO basket. Read responses can omit name, type, tags, and item action fields.
/// Keep these absent values when modifying a fetched basket; do not fabricate server metadata.
public struct KiteAlertBasket: Codable, Sendable, Equatable {
  public var name: String?
  public var type: String?
  public var tags: [String]?
  public var items: [KiteAlertBasketItem]

  public init(name: String, items: [KiteAlertBasketItem], tags: [String] = []) {
    self.name = name
    self.type = "alert"
    self.tags = tags
    self.items = items
  }
}

public struct KiteAlertBasketItem: Codable, Sendable, Equatable {
  public var type: String?
  public var id: Int64?
  public var instrumentToken: UInt32?
  public var tradingSymbol: String
  public var exchange: KiteExchange
  public var weight: Decimal
  public var params: KiteAlertOrderParameters

  public init(
    tradingSymbol: String, exchange: KiteExchange, weight: Decimal = 10000,
    params: KiteAlertOrderParameters
  ) {
    self.type = "insert"
    self.tradingSymbol = tradingSymbol
    self.exchange = exchange
    self.weight = weight
    self.params = params
  }

  enum CodingKeys: String, CodingKey {
    case type, id, exchange, weight, params
    case instrumentToken = "instrument_token"
    case tradingSymbol = "tradingsymbol"
  }
}

/// Basket-specific wire parameters, distinct from standalone order placement.
/// Zero TTL/iceberg fields and plural tags are documented here; standalone order rules do not apply.
public struct KiteAlertOrderParameters: Codable, Sendable, Equatable {
  public var transactionType: KiteTransactionType
  public var product: KiteProduct
  public var orderType: KiteOrderType
  public var validity: KiteOrderValidity
  public var validityTTL: Int
  public var quantity: Int64
  public var price: Decimal
  public var triggerPrice: Decimal
  public var disclosedQuantity: Int64
  public var lastPrice: Decimal?
  public var variety: KiteOrderVariety
  public var tags: [String]
  public var squareoff: Decimal
  public var stoploss: Decimal
  public var trailingStoploss: Decimal
  public var icebergLegs: Int?
  public var marketProtection: Decimal?
  public var gtt: KiteAlertBasketGTT?

  public init(
    transactionType: KiteTransactionType, product: KiteProduct, orderType: KiteOrderType,
    quantity: Int64
  ) {
    self.transactionType = transactionType
    self.product = product
    self.orderType = orderType
    self.quantity = quantity
    validity = .day
    validityTTL = 1
    price = 0
    triggerPrice = 0
    disclosedQuantity = 0
    lastPrice = 0
    variety = .regular
    tags = []
    squareoff = 0
    stoploss = 0
    trailingStoploss = 0
    icebergLegs = 0
    marketProtection = -1
  }

  enum CodingKeys: String, CodingKey {
    case product, validity, quantity, price, variety, tags, squareoff, stoploss, gtt
    case transactionType = "transaction_type"
    case orderType = "order_type"
    case validityTTL = "validity_ttl"
    case triggerPrice = "trigger_price"
    case disclosedQuantity = "disclosed_quantity"
    case lastPrice = "last_price"
    case trailingStoploss = "trailing_stoploss"
    case icebergLegs = "iceberg_legs"
    case marketProtection = "market_protection"
  }
}

/// Nested target/stoploss values shown in the documented retrieved ATO basket.
public struct KiteAlertBasketGTT: Codable, Sendable, Equatable {
  public var target: Decimal
  public var stoploss: Decimal
  public init(target: Decimal, stoploss: Decimal) {
    self.target = target
    self.stoploss = stoploss
  }
}

extension KiteAlertBasket {
  func validate() throws {
    if let name { try alertText(name, field: "basket.name") }
    if let type { try alertText(type, field: "basket.type") }
    for tag in tags ?? [] { try alertText(tag, field: "basket.tags") }
    guard !items.isEmpty else {
      throw KiteError.validation(field: "basket.items", message: "Expected at least one order")
    }
    for item in items {
      if let type = item.type { try alertText(type, field: "basket.items.type") }
      try alertText(item.tradingSymbol, field: "basket.items.tradingsymbol")
      try alertText(item.exchange.rawValue, field: "basket.items.exchange")
      try basketDecimal(item.weight, field: "weight", nonnegative: false)
      let params = item.params
      for (field, value) in [
        ("transaction_type", params.transactionType.rawValue), ("product", params.product.rawValue),
        ("order_type", params.orderType.rawValue), ("validity", params.validity.rawValue),
        ("variety", params.variety.rawValue),
      ] { try alertText(value, field: "basket.items.params.\(field)") }
      guard params.quantity > 0 else {
        throw KiteError.validation(
          field: "basket.items.params.quantity", message: "Must be positive")
      }
      for (field, value) in [
        ("validity_ttl", params.validityTTL),
        ("iceberg_legs", params.icebergLegs ?? 0),
      ] where value < 0 {
        throw KiteError.validation(
          field: "basket.items.params.\(field)", message: "Must be nonnegative")
      }
      guard params.disclosedQuantity >= 0 else {
        throw KiteError.validation(
          field: "basket.items.params.disclosed_quantity", message: "Must be nonnegative")
      }
      for (field, value) in [
        ("price", params.price), ("trigger_price", params.triggerPrice),
        ("last_price", params.lastPrice), ("squareoff", params.squareoff),
        ("stoploss", params.stoploss), ("trailing_stoploss", params.trailingStoploss),
        ("gtt.target", params.gtt?.target), ("gtt.stoploss", params.gtt?.stoploss),
      ] {
        if let value { try basketDecimal(value, field: field) }
      }
      if let protection = params.marketProtection {
        // The ATO docs show -1 but do not publish a range; do not import standalone order rules.
        try basketDecimal(protection, field: "market_protection", nonnegative: false)
      }
      for tag in params.tags { try alertText(tag, field: "basket.items.params.tags") }
    }
  }
}

private func basketDecimal(_ value: Decimal, field: String, nonnegative: Bool = true) throws {
  guard !value.isNaN, !nonnegative || value >= 0 else {
    throw KiteError.validation(
      field: "basket.items.params.\(field)",
      message: nonnegative ? "Must be finite and nonnegative" : "Must be finite")
  }
}
