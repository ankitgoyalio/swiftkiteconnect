import Foundation

public enum KiteGTTType: KiteStringValue {
  case single, twoLeg
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "single": self = .single
    case "two-leg": self = .twoLeg
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .single: "single"
    case .twoLeg: "two-leg"
    case .unknown(let value): value
    }
  }
}

public enum KiteGTTStatus: KiteStringValue {
  case active, triggered, disabled, expired, cancelled, rejected, deleted
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "active": self = .active
    case "triggered": self = .triggered
    case "disabled": self = .disabled
    case "expired": self = .expired
    case "cancelled": self = .cancelled
    case "rejected": self = .rejected
    case "deleted": self = .deleted
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .active: "active"
    case .triggered: "triggered"
    case .disabled: "disabled"
    case .expired: "expired"
    case .cancelled: "cancelled"
    case .rejected: "rejected"
    case .deleted: "deleted"
    case .unknown(let value): value
    }
  }
}

public enum KiteGTTOrderResultStatus: KiteStringValue {
  case success, failed
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "success": self = .success
    case "failed": self = .failed
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .success: "success"
    case .failed: "failed"
    case .unknown(let value): value
    }
  }
}

/// Trigger condition returned by Kite, including its response-only instrument token.
public struct KiteGTTCondition: Decodable, Sendable, Equatable {
  public let exchange: KiteExchange
  public let tradingSymbol: String
  public let triggerValues: [Decimal]
  public let lastPrice: Decimal
  public let instrumentToken: UInt32
  enum CodingKeys: String, CodingKey {
    case exchange = "exchange"
    case tradingSymbol = "tradingsymbol"
    case triggerValues = "trigger_values"
    case lastPrice = "last_price"
    case instrumentToken = "instrument_token"
  }
}

/// Embedded order definition and its optional execution result. This is not a standalone order.
public struct KiteGTTOrder: Decodable, Sendable, Equatable {
  public let exchange: KiteExchange
  public let tradingSymbol: String
  public let transactionType: KiteTransactionType
  public let quantity: Int64
  public let orderType: KiteOrderType
  public let product: KiteProduct
  public let price: Decimal
  public let result: KiteGTTExecution?
  enum CodingKeys: String, CodingKey {
    case exchange = "exchange"
    case tradingSymbol = "tradingsymbol"
    case transactionType = "transaction_type"
    case quantity = "quantity"
    case orderType = "order_type"
    case product = "product"
    case price = "price"
    case result = "result"
  }
}

/// Execution attempt details. `meta` is the documented JSON-encoded string, preserved verbatim.
public struct KiteGTTExecution: Decodable, Sendable, Equatable {
  public let accountID: String
  public let exchange: KiteExchange
  public let tradingSymbol: String
  public let transactionType: KiteTransactionType
  public let quantity: Int64
  public let orderType: KiteOrderType
  public let product: KiteProduct
  public let price: Decimal
  public let validity: KiteOrderValidity
  public let meta: String?
  public let timestamp: Date
  public let triggeredAt: Decimal
  public let orderResult: KiteGTTOrderResult?
  enum CodingKeys: String, CodingKey {
    case accountID = "account_id"
    case exchange = "exchange"
    case tradingSymbol = "tradingsymbol"
    case transactionType = "transaction_type"
    case quantity = "quantity"
    case orderType = "order_type"
    case product = "product"
    case price = "price"
    case validity = "validity"
    case meta = "meta"
    case timestamp = "timestamp"
    case triggeredAt = "triggered_at"
    case orderResult = "order_result"
  }
}

/// Result fields may be missing or null. A failed attempt can have an empty order ID.
public struct KiteGTTOrderResult: Decodable, Sendable, Equatable {
  public let status: KiteGTTOrderResultStatus?
  public let orderID: String?
  public let rejectionReason: String?
  enum CodingKeys: String, CodingKey {
    case status = "status"
    case orderID = "order_id"
    case rejectionReason = "rejection_reason"
  }
}

public struct KiteGTTTrigger: Decodable, Sendable, Equatable {
  public let id: Int64
  public let userID: String
  public let parentTrigger: Int64?
  public let type: KiteGTTType
  public let createdAt: Date
  public let updatedAt: Date
  public let expiresAt: Date
  public let status: KiteGTTStatus
  public let condition: KiteGTTCondition
  public let orders: [KiteGTTOrder]
  public let meta: KiteOrderMutationJSONValue?
  enum CodingKeys: String, CodingKey {
    case id = "id"
    case userID = "user_id"
    case parentTrigger = "parent_trigger"
    case type = "type"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case expiresAt = "expires_at"
    case status = "status"
    case condition = "condition"
    case orders = "orders"
    case meta = "meta"
  }
}

extension KiteClient {
  public func gttTriggers() async throws -> [KiteGTTTrigger] {
    try await execute(KiteRequest(path: "/gtt/triggers"), as: [KiteGTTTrigger].self)
  }
}

extension KiteClient {
  public func gttTrigger(id: Int64) async throws -> KiteGTTTrigger {
    try gttIdentifier(id)
    return try await execute(KiteRequest(path: "/gtt/triggers/\(id)"), as: KiteGTTTrigger.self)
  }
}

private func gttIdentifier(_ id: Int64) throws {
  guard id > 0 else {
    throw KiteError.validation(
      field: "trigger_id", message: "Expected a positive trigger identifier")
  }
}

/// Request condition: no response-only instrument token is sent to Kite.
public struct KiteGTTConditionRequest: Encodable, Sendable, Equatable {
  public var instrument: KiteInstrumentIdentity
  public var triggerValues: [Decimal]
  public var lastPrice: Decimal
  public init(instrument: KiteInstrumentIdentity, triggerValues: [Decimal], lastPrice: Decimal) {
    self.instrument = instrument
    self.triggerValues = triggerValues
    self.lastPrice = lastPrice
  }
  enum CodingKeys: String, CodingKey {
    case exchange
    case tradingSymbol = "tradingsymbol"
    case triggerValues = "trigger_values"
    case lastPrice = "last_price"
  }
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(instrument.exchange, forKey: .exchange)
    try container.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
    try container.encode(triggerValues, forKey: .triggerValues)
    try container.encode(lastPrice, forKey: .lastPrice)
  }
}

/// Embedded GTT order, distinct from standalone order placement. GTT supports LIMIT orders.
public struct KiteGTTOrderRequest: Encodable, Sendable, Equatable {
  public var instrument: KiteInstrumentIdentity
  public var transactionType: KiteTransactionType
  public var quantity: Int64
  public var orderType: KiteOrderType
  public var product: KiteProduct
  public var price: Decimal
  public init(
    instrument: KiteInstrumentIdentity, transactionType: KiteTransactionType,
    quantity: Int64, orderType: KiteOrderType = .limit, product: KiteProduct, price: Decimal
  ) {
    self.instrument = instrument
    self.transactionType = transactionType
    self.quantity = quantity
    self.orderType = orderType
    self.product = product
    self.price = price
  }
  enum CodingKeys: String, CodingKey {
    case exchange
    case tradingSymbol = "tradingsymbol"
    case transactionType = "transaction_type"
    case quantity
    case orderType = "order_type"
    case product, price
  }
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(instrument.exchange, forKey: .exchange)
    try container.encode(instrument.tradingSymbol, forKey: .tradingSymbol)
    try container.encode(transactionType, forKey: .transactionType)
    try container.encode(quantity, forKey: .quantity)
    try container.encode(orderType, forKey: .orderType)
    try container.encode(product, forKey: .product)
    try container.encode(price, forKey: .price)
  }
}

/// Complete definition used for both creation and replacement-style modification.
/// Trigger values and orders correspond by array index; their order is preserved.
public struct KiteGTTRequest: Sendable, Equatable {
  public var type: KiteGTTType
  public var condition: KiteGTTConditionRequest
  public var orders: [KiteGTTOrderRequest]
  public init(type: KiteGTTType, condition: KiteGTTConditionRequest, orders: [KiteGTTOrderRequest])
  {
    self.type = type
    self.condition = condition
    self.orders = orders
  }
  func parameters() throws -> [KiteParameter] {
    let count: Int
    switch type {
    case .single: count = 1
    case .twoLeg: count = 2
    case .unknown:
      throw KiteError.validation(field: "type", message: "Expected single or two-leg")
    }
    guard condition.triggerValues.count == count, orders.count == count else {
      throw KiteError.validation(
        field: "orders",
        message: "Trigger values and orders must match the trigger type's leg count")
    }
    for value in condition.triggerValues + [condition.lastPrice] + orders.map(\.price) {
      guard !value.isNaN else {
        throw KiteError.validation(field: "price", message: "Expected finite decimal values")
      }
    }
    for order in orders {
      guard order.orderType == .limit else {
        throw KiteError.validation(field: "order_type", message: "GTT orders require LIMIT")
      }
      guard order.transactionType == .buy || order.transactionType == .sell else {
        throw KiteError.validation(field: "transaction_type", message: "Expected BUY or SELL")
      }
      guard order.quantity > 0 else {
        throw KiteError.validation(field: "quantity", message: "Expected a positive quantity")
      }
      guard !order.product.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !order.product.rawValue.unicodeScalars.contains(where: {
          CharacterSet.controlCharacters.contains($0)
        })
      else {
        throw KiteError.validation(
          field: "product", message: "Expected a nonempty product without controls")
      }
    }
    let encoder = JSONEncoder()
    return [
      .init("type", type.rawValue),
      .init("condition", String(decoding: try encoder.encode(condition), as: UTF8.self)),
      .init("orders", String(decoding: try encoder.encode(orders), as: UTF8.self)),
    ]
  }
}

/// Acknowledges a trigger mutation; does not establish that an embedded order executed.
public struct KiteGTTReceipt: Decodable, Sendable, Equatable {
  public let triggerID: Int64
  enum CodingKeys: String, CodingKey { case triggerID = "trigger_id" }
}

extension KiteClient {
  /// Sends once. Reconcile an uncertain outcome through GTT reads before deciding to resubmit.
  public func createGTT(_ trigger: KiteGTTRequest) async throws -> KiteGTTReceipt {
    try await execute(
      KiteRequest(
        method: .post, path: "/gtt/triggers",
        body: .form(try trigger.parameters()), isTradingMutation: true), as: KiteGTTReceipt.self)
  }
}

extension KiteClient {
  /// Fetch current state first, then supply the complete desired definition. Sends once.
  public func modifyGTT(id: Int64, trigger: KiteGTTRequest) async throws -> KiteGTTReceipt {
    try gttIdentifier(id)
    return try await execute(
      KiteRequest(
        method: .put, path: "/gtt/triggers/\(id)",
        body: .form(try trigger.parameters()), isTradingMutation: true), as: KiteGTTReceipt.self)
  }

  /// Sends once; on uncertainty inspect trigger state before deciding on another action.
  public func deleteGTT(id: Int64) async throws -> KiteGTTReceipt {
    try gttIdentifier(id)
    return try await execute(
      KiteRequest(
        method: .delete, path: "/gtt/triggers/\(id)",
        isTradingMutation: true), as: KiteGTTReceipt.self)
  }
}
