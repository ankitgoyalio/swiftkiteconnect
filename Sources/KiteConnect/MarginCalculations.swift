import Foundation

/// A hypothetical order. Calculating margins never submits this order.
public struct KiteMarginOrder: Sendable, Encodable {
  public var instrument: KiteInstrumentIdentity
  public var transactionType: KiteTransactionType
  public var variety: KiteOrderVariety
  public var product: KiteProduct
  public var orderType: KiteOrderType
  public var quantity: Int64
  public var price: Decimal
  public var triggerPrice: Decimal

  public init(
    instrument: KiteInstrumentIdentity, transactionType: KiteTransactionType,
    variety: KiteOrderVariety = .regular, product: KiteProduct, orderType: KiteOrderType,
    quantity: Int64, price: Decimal = 0, triggerPrice: Decimal = 0
  ) {
    self.instrument = instrument
    self.transactionType = transactionType
    self.variety = variety
    self.product = product
    self.orderType = orderType
    self.quantity = quantity
    self.price = price
    self.triggerPrice = triggerPrice
  }

  enum CodingKeys: String, CodingKey {
    case exchange, variety, product, quantity, price
    case tradingSymbol = "tradingsymbol"
    case transactionType = "transaction_type"
    case orderType = "order_type"
    case triggerPrice = "trigger_price"
  }
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(instrument.exchange, forKey: .exchange)
    try c.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
    try c.encode(transactionType, forKey: .transactionType)
    try c.encode(variety, forKey: .variety)
    try c.encode(product, forKey: .product)
    try c.encode(orderType, forKey: .orderType)
    try c.encode(quantity, forKey: .quantity)
    try c.encode(price, forKey: .price)
    try c.encode(triggerPrice, forKey: .triggerPrice)
  }
}

public struct KiteCalculationGST: Decodable, Sendable, Equatable {
  public let igst: Decimal
  public let cgst: Decimal
  public let sgst: Decimal
  public let total: Decimal
}

/// Raw tax types preserve future server values, including the empty aggregate tax type.
public struct KiteCalculationCharges: Decodable, Sendable, Equatable {
  public let transactionTax: Decimal
  public let transactionTaxType: String
  public let exchangeTurnoverCharge: Decimal
  public let sebiTurnoverCharge: Decimal
  public let brokerage: Decimal
  public let stampDuty: Decimal
  public let gst: KiteCalculationGST
  public let total: Decimal
  enum CodingKeys: String, CodingKey {
    case brokerage, gst, total
    case transactionTax = "transaction_tax"
    case transactionTaxType = "transaction_tax_type"
    case exchangeTurnoverCharge = "exchange_turnover_charge"
    case sebiTurnoverCharge = "sebi_turnover_charge"
    case stampDuty = "stamp_duty"
  }
}

public struct KiteCalculationPnL: Decodable, Sendable, Equatable {
  public let realised: Decimal
  public let unrealised: Decimal
}

/// Full margin breakdown, also used for basket initial/final aggregate margins.
/// Aggregate exchange and trading symbol can be empty; no instrument identity is invented.
public struct KiteCalculatedMargin: Decodable, Sendable, Equatable {
  public let type: String
  public let tradingSymbol: String
  public let exchange: KiteExchange
  public let span: Decimal
  public let exposure: Decimal
  public let optionPremium: Decimal
  public let additional: Decimal
  public let bo: Decimal
  public let cash: Decimal
  public let valueAtRisk: Decimal
  public let pnl: KiteCalculationPnL
  public let leverage: Decimal
  public let charges: KiteCalculationCharges
  public let total: Decimal
  public var instrument: KiteInstrumentIdentity? {
    try? KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
  }
  enum CodingKeys: String, CodingKey {
    case type, exchange, span, exposure, additional, bo, cash, pnl, leverage, charges, total
    case tradingSymbol = "tradingsymbol"
    case optionPremium = "option_premium"
    case valueAtRisk = "var"
  }
}

extension KiteClient {
  /// Estimates each supplied order against existing positions/open orders. Sends once.
  public func orderMargins(_ orders: [KiteMarginOrder]) async throws -> [KiteCalculatedMargin] {
    try validateMarginOrders(orders)
    return try await execute(
      KiteRequest(
        method: .post, path: "/margins/orders", body: .json(JSONEncoder().encode(orders))),
      as: [KiteCalculatedMargin].self)
  }
}

private func validateMarginOrders(_ orders: [KiteMarginOrder]) throws {
  guard !orders.isEmpty else {
    throw KiteError.validation(field: "orders", message: "Supply at least one order")
  }
  for order in orders {
    for (field, value) in [
      ("transaction_type", order.transactionType.rawValue), ("variety", order.variety.rawValue),
      ("product", order.product.rawValue), ("order_type", order.orderType.rawValue),
    ] {
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
      else {
        throw KiteError.validation(
          field: field, message: "Expected a nonempty value without controls")
      }
    }
    guard order.quantity > 0 else {
      throw KiteError.validation(field: "quantity", message: "Must be positive")
    }
    for (field, value) in [("price", order.price), ("trigger_price", order.triggerPrice)] {
      guard !value.isNaN, value >= 0 else {
        throw KiteError.validation(field: field, message: "Must be a nonnegative decimal")
      }
    }
  }
}

public struct KiteCalculatedBasketMargins: Decodable, Sendable, Equatable {
  public let initial: KiteCalculatedMargin
  public let final: KiteCalculatedMargin
  public let orders: [KiteCalculatedMargin]
  /// May omit transaction taxes for mixed tax types. Prefer individual order charges.
  public let charges: KiteCalculationCharges
}

extension KiteClient {
  public func basketMargins(_ orders: [KiteMarginOrder], considerPositions: Bool = true)
    async throws -> KiteCalculatedBasketMargins
  {
    try validateMarginOrders(orders)
    return try await execute(
      KiteRequest(
        method: .post, path: "/margins/basket",
        query: [.init("consider_positions", considerPositions ? "true" : "false")],
        body: .json(JSONEncoder().encode(orders))), as: KiteCalculatedBasketMargins.self)
  }
}

/// Compact mode guarantees only the total. Additional documented fields are retained if supplied.
public struct KiteCompactMargin: Decodable, Sendable, Equatable {
  public let type: String?
  public let tradingSymbol: String?
  public let exchange: KiteExchange?
  public let span: Decimal?
  public let exposure: Decimal?
  public let optionPremium: Decimal?
  public let additional: Decimal?
  public let bo: Decimal?
  public let cash: Decimal?
  public let valueAtRisk: Decimal?
  public let pnl: KiteCalculationPnL?
  public let leverage: Decimal?
  public let charges: KiteCalculationCharges?
  public let total: Decimal
  public var instrument: KiteInstrumentIdentity? {
    guard let exchange, let tradingSymbol else { return nil }
    return try? KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
  }
  enum CodingKeys: String, CodingKey {
    case type, exchange, span, exposure, additional, bo, cash, pnl, leverage, charges, total
    case tradingSymbol = "tradingsymbol"
    case optionPremium = "option_premium"
    case valueAtRisk = "var"
  }
}

public struct KiteCompactBasketMargins: Decodable, Sendable, Equatable {
  public let initial: KiteCompactMargin
  public let final: KiteCompactMargin
  public let orders: [KiteCompactMargin]?
  public let charges: KiteCalculationCharges?
}

extension KiteClient {
  public func compactOrderMargins(_ orders: [KiteMarginOrder]) async throws -> [KiteCompactMargin] {
    try validateMarginOrders(orders)
    return try await execute(
      KiteRequest(
        method: .post, path: "/margins/orders", query: [.init("mode", "compact")],
        body: .json(JSONEncoder().encode(orders))), as: [KiteCompactMargin].self)
  }

  public func compactBasketMargins(_ orders: [KiteMarginOrder], considerPositions: Bool = true)
    async throws -> KiteCompactBasketMargins
  {
    try validateMarginOrders(orders)
    return try await execute(
      KiteRequest(
        method: .post, path: "/margins/basket",
        query: [
          .init("consider_positions", considerPositions ? "true" : "false"),
          .init("mode", "compact"),
        ],
        body: .json(JSONEncoder().encode(orders))), as: KiteCompactBasketMargins.self)
  }
}

/// Virtual contract-note input. `orderID` can be any nonempty hypothetical identifier.
public struct KiteChargeOrder: Sendable, Encodable {
  public var orderID: String
  public var instrument: KiteInstrumentIdentity
  public var transactionType: KiteTransactionType
  public var variety: KiteOrderVariety
  public var product: KiteProduct
  public var orderType: KiteOrderType
  public var quantity: Int64
  public var averagePrice: Decimal

  public init(
    orderID: String, instrument: KiteInstrumentIdentity, transactionType: KiteTransactionType,
    variety: KiteOrderVariety = .regular, product: KiteProduct, orderType: KiteOrderType,
    quantity: Int64, averagePrice: Decimal
  ) {
    self.orderID = orderID
    self.instrument = instrument
    self.transactionType = transactionType
    self.variety = variety
    self.product = product
    self.orderType = orderType
    self.quantity = quantity
    self.averagePrice = averagePrice
  }
  enum CodingKeys: String, CodingKey {
    case exchange, variety, product, quantity
    case orderID = "order_id"
    case tradingSymbol = "tradingsymbol"
    case transactionType = "transaction_type"
    case orderType = "order_type"
    case averagePrice = "average_price"
  }
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(orderID, forKey: .orderID)
    try c.encode(instrument.exchange, forKey: .exchange)
    try c.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
    try c.encode(transactionType, forKey: .transactionType)
    try c.encode(variety, forKey: .variety)
    try c.encode(product, forKey: .product)
    try c.encode(orderType, forKey: .orderType)
    try c.encode(quantity, forKey: .quantity)
    try c.encode(averagePrice, forKey: .averagePrice)
  }
}

public struct KiteCalculatedOrderCharges: Decodable, Sendable, Equatable {
  /// Not present in the documented response; retained if returned by the server.
  public let orderID: String?
  public let exchange: KiteExchange
  public let tradingSymbol: String
  public let transactionType: KiteTransactionType
  public let variety: KiteOrderVariety
  public let product: KiteProduct
  public let orderType: KiteOrderType
  public let quantity: Int64
  public let price: Decimal
  public let charges: KiteCalculationCharges
  public var instrument: KiteInstrumentIdentity? {
    try? KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
  }
  enum CodingKeys: String, CodingKey {
    case exchange, variety, product, quantity, price, charges
    case orderID = "order_id"
    case tradingSymbol = "tradingsymbol"
    case transactionType = "transaction_type"
    case orderType = "order_type"
  }
}

extension KiteClient {
  /// Calculates charges without requiring an actual order or placing one.
  public func orderCharges(_ orders: [KiteChargeOrder]) async throws -> [KiteCalculatedOrderCharges]
  {
    try validateMarginOrders(
      orders.map {
        KiteMarginOrder(
          instrument: $0.instrument, transactionType: $0.transactionType,
          variety: $0.variety, product: $0.product, orderType: $0.orderType, quantity: $0.quantity)
      })
    for order in orders {
      guard !order.orderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !order.orderID.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
      else {
        throw KiteError.validation(
          field: "order_id", message: "Expected a nonempty identifier without controls")
      }
      guard !order.averagePrice.isNaN, order.averagePrice > 0 else {
        throw KiteError.validation(field: "average_price", message: "Must be a positive decimal")
      }
    }
    return try await execute(
      KiteRequest(
        method: .post, path: "/charges/orders", body: .json(JSONEncoder().encode(orders))),
      as: [KiteCalculatedOrderCharges].self)
  }
}
