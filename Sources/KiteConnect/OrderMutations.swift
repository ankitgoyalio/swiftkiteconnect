import Foundation

/// Request varieties in the release's orders documentation snapshot.
public enum KiteOrderMutationVariety: String, Sendable, CaseIterable {
  case regular, amo, co, iceberg, auction
}
public enum KiteOrderMutationSide: String, Sendable {
  case buy = "BUY"
  case sell = "SELL"
}
public enum KiteOrderMutationValidity: String, Sendable {
  case day = "DAY"
  case ioc = "IOC"
  case ttl = "TTL"
}

public struct KiteOrderPlacement: Sendable {
  public var variety: KiteOrderMutationVariety = .regular
  public var tradingSymbol: String
  public var exchange: KiteExchange
  public var transactionType: KiteOrderMutationSide
  public var orderType: KiteOrderType
  public var quantity: Int64
  public var product: KiteProduct
  public var price: Decimal?
  public var validity: KiteOrderMutationValidity?
  public var triggerPrice: Decimal?
  public var disclosedQuantity: Int64?
  public var validityTTL: Int?
  public var icebergLegs: Int?
  public var icebergQuantity: Int64?
  public var auctionNumber: String?
  /// -1 requests automatic protection; otherwise a percentage greater than 0 and at most 100.
  public var marketProtection: Decimal?
  public var autoslice: Bool?
  public var tag: String?

  public init(
    tradingSymbol: String, exchange: KiteExchange,
    transactionType: KiteOrderMutationSide, orderType: KiteOrderType,
    quantity: Int64, product: KiteProduct
  ) {
    self.tradingSymbol = tradingSymbol
    self.exchange = exchange
    self.transactionType = transactionType
    self.orderType = orderType
    self.quantity = quantity
    self.product = product
  }
}

/// Receipt of submission, never proof of exchange acceptance or execution.
public struct KiteOrderMutationReceipt: Decodable, Sendable, Equatable {
  public let orderID: String
  public let children: [KiteOrderSliceResult]?
  enum CodingKeys: String, CodingKey {
    case orderID = "order_id"
    case children
  }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    orderID = try container.decode(String.self, forKey: .orderID)
    guard !orderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .orderID, in: container, debugDescription: "Empty order ID")
    }
    children =
      container.contains(.children)
      ? try container.decode([KiteOrderSliceResult].self, forKey: .children) : nil
  }
}
public enum KiteOrderPlacementResult: Decodable, Sendable, Equatable {
  case order(KiteOrderMutationReceipt)
  case slices([KiteOrderSliceResult])
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let slices = try? container.decode([KiteOrderSliceResult].self) {
      self = .slices(slices)
    } else {
      self = .order(try container.decode(KiteOrderMutationReceipt.self))
    }
  }
}

extension KiteClient {
  /// Sends once. Reconcile an uncertain outcome before deciding on another action.
  public func placeOrder(_ order: KiteOrderPlacement) async throws -> KiteOrderPlacementResult {
    try mutationText(order.tradingSymbol, field: "tradingsymbol")
    try mutationText(order.exchange.rawValue, field: "exchange")
    try mutationText(order.product.rawValue, field: "product")
    try mutationText(order.orderType.rawValue, field: "order_type")
    try mutationNumbers(
      quantity: order.quantity, price: order.price, trigger: order.triggerPrice,
      disclosed: order.disclosedQuantity, ttl: order.validityTTL, protection: order.marketProtection
    )
    if [.limit, .stopLoss].contains(order.orderType), order.price == nil {
      throw mutationValidation("price", "Required for LIMIT and SL placement")
    }
    if [.stopLoss, .stopLossMarket].contains(order.orderType), order.triggerPrice == nil {
      throw mutationValidation("trigger_price", "Required for stop-loss placement")
    }
    if order.validity == .ttl, order.validityTTL == nil {
      throw mutationValidation("validity_ttl", "Required for TTL placement")
    }
    if order.variety == .iceberg, order.icebergLegs == nil {
      throw mutationValidation("iceberg_legs", "Required for iceberg placement")
    }
    if let legs = order.icebergLegs, !(2...50).contains(legs) {
      throw mutationValidation("iceberg_legs", "Expected 2 through 50 legs")
    }
    if order.variety == .iceberg, order.icebergQuantity == nil {
      throw mutationValidation("iceberg_quantity", "Required for iceberg placement")
    }
    if let quantity = order.icebergQuantity, quantity <= 0 {
      throw mutationValidation("iceberg_quantity", "Must be positive")
    }
    if order.variety == .auction, order.auctionNumber == nil {
      throw mutationValidation("auction_number", "Required for auction placement")
    }
    if let auction = order.auctionNumber { try mutationText(auction, field: "auction_number") }
    if let tag = order.tag {
      let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
      guard !tag.isEmpty, tag.utf8.count <= 20,
        tag.unicodeScalars.allSatisfy({ allowed.contains($0) })
      else {
        throw mutationValidation("tag", "Expected 1 through 20 alphanumeric ASCII characters")
      }
    }
    var fields: [KiteParameter] = [
      .init("tradingsymbol", order.tradingSymbol), .init("exchange", order.exchange.rawValue),
      .init("transaction_type", order.transactionType.rawValue),
      .init("order_type", order.orderType.rawValue), .init("quantity", String(order.quantity)),
      .init("product", order.product.rawValue),
    ]
    if let price = order.price { fields.append(.init("price", price.description)) }
    if let validity = order.validity { fields.append(.init("validity", validity.rawValue)) }
    if let value = order.triggerPrice { fields.append(.init("trigger_price", value.description)) }
    if let value = order.disclosedQuantity {
      fields.append(.init("disclosed_quantity", String(value)))
    }
    if let value = order.validityTTL { fields.append(.init("validity_ttl", String(value))) }
    if let value = order.icebergLegs { fields.append(.init("iceberg_legs", String(value))) }
    if let value = order.icebergQuantity { fields.append(.init("iceberg_quantity", String(value))) }
    if let value = order.auctionNumber { fields.append(.init("auction_number", value)) }
    if let value = order.marketProtection {
      fields.append(.init("market_protection", value.description))
    }
    if let value = order.autoslice { fields.append(.init("autoslice", value ? "true" : "false")) }
    if let value = order.tag { fields.append(.init("tag", value)) }
    return try await execute(
      KiteRequest(
        method: .post, path: "/orders/\(order.variety.rawValue)",
        body: .form(fields), isTradingMutation: true), as: KiteOrderPlacementResult.self)
  }
}

/// Omitted fields remain unchanged. Existing order state and broker eligibility belong to Kite.
public struct KiteOrderModification: Sendable {
  public var orderType: KiteOrderType?
  public var quantity: Int64?
  public var price: Decimal?
  public var triggerPrice: Decimal?
  public var disclosedQuantity: Int64?
  public var validity: KiteOrderMutationValidity?
  public var validityTTL: Int?
  public var marketProtection: Decimal?
  public init() {}
}

extension KiteClient {
  public func modifyOrder(
    orderID: String, variety: KiteOrderMutationVariety = .regular,
    parentOrderID: String? = nil, changes: KiteOrderModification
  ) async throws -> KiteOrderMutationReceipt {
    try mutationIdentifier(orderID, field: "order_id")
    if let parentOrderID { try mutationIdentifier(parentOrderID, field: "parent_order_id") }
    if let type = changes.orderType { try mutationText(type.rawValue, field: "order_type") }
    try mutationNumbers(
      quantity: changes.quantity, price: changes.price, trigger: changes.triggerPrice,
      disclosed: changes.disclosedQuantity, ttl: changes.validityTTL,
      protection: changes.marketProtection)
    var fields: [KiteParameter] = []
    if let value = changes.orderType { fields.append(.init("order_type", value.rawValue)) }
    if let value = changes.quantity { fields.append(.init("quantity", String(value))) }
    if let value = changes.price { fields.append(.init("price", value.description)) }
    if let value = changes.triggerPrice { fields.append(.init("trigger_price", value.description)) }
    if let value = changes.disclosedQuantity {
      fields.append(.init("disclosed_quantity", String(value)))
    }
    if let value = changes.validity { fields.append(.init("validity", value.rawValue)) }
    if let value = changes.validityTTL { fields.append(.init("validity_ttl", String(value))) }
    if let value = changes.marketProtection {
      fields.append(.init("market_protection", value.description))
    }
    guard !fields.isEmpty else {
      throw mutationValidation("changes", "Supply at least one changed field")
    }
    if let parentOrderID { fields.append(.init("parent_order_id", parentOrderID)) }
    return try await execute(
      KiteRequest(
        method: .put, path: "/orders/\(variety.rawValue)/\(orderID)",
        body: .form(fields), isTradingMutation: true), as: KiteOrderMutationReceipt.self)
  }

  /// For a CO second leg, cancellation exits the position as described by Kite.
  public func cancelOrder(
    orderID: String, variety: KiteOrderMutationVariety = .regular,
    parentOrderID: String? = nil
  ) async throws -> KiteOrderMutationReceipt {
    try mutationIdentifier(orderID, field: "order_id")
    if let parentOrderID { try mutationIdentifier(parentOrderID, field: "parent_order_id") }
    return try await execute(
      KiteRequest(
        method: .delete, path: "/orders/\(variety.rawValue)/\(orderID)",
        query: parentOrderID.map { [.init("parent_order_id", $0)] } ?? [],
        isTradingMutation: true), as: KiteOrderMutationReceipt.self)
  }
}

/// A per-slice rejection is confirmed, while other slices may already have been placed.
public enum KiteOrderSliceResult: Decodable, Sendable, Equatable {
  case placed(KiteOrderMutationReceipt)
  case rejected(KiteOrderSliceRejection)
  enum CodingKeys: String, CodingKey {
    case error
    case orderID = "order_id"
  }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if container.contains(.error) {
      guard !container.contains(.orderID) else {
        throw DecodingError.dataCorruptedError(
          forKey: .error, in: container, debugDescription: "Ambiguous slice outcome")
      }
      self = .rejected(try container.decode(KiteOrderSliceRejection.self, forKey: .error))
    } else {
      self = .placed(try KiteOrderMutationReceipt(from: decoder))
    }
  }
}
public struct KiteOrderSliceRejection: Decodable, Sendable, Equatable {
  public let code: Int
  public let errorType: String
  public let message: String
  public let data: KiteOrderMutationJSONValue
  enum CodingKeys: String, CodingKey {
    case code
    case errorType = "error_type"
    case message, data
  }
}

/// Lossless JSON structure for broker-provided slice rejection details. Numbers use Decimal.
public indirect enum KiteOrderMutationJSONValue: Decodable, Sendable, Equatable {
  case null
  case bool(Bool)
  case number(Decimal)
  case string(String)
  case array([KiteOrderMutationJSONValue])
  case object([String: KiteOrderMutationJSONValue])
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Decimal.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([KiteOrderMutationJSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: KiteOrderMutationJSONValue].self))
    }
  }
}

private func mutationValidation(_ field: String, _ message: String) -> KiteError {
  .validation(field: field, message: message)
}
private func mutationText(_ value: String, field: String) throws {
  guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
    !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
  else {
    throw mutationValidation(field, "Expected nonempty text without control characters")
  }
}
private func mutationIdentifier(_ value: String, field: String) throws {
  try mutationText(value, field: field)
  guard !value.contains(".."), !value.contains(where: { $0.isWhitespace || "/\\?#%".contains($0) })
  else {
    throw mutationValidation(field, "Expected a single order identifier")
  }
}
private func mutationNumbers(
  quantity: Int64?, price: Decimal?, trigger: Decimal?,
  disclosed: Int64?, ttl: Int?, protection: Decimal?
) throws {
  if let quantity, quantity <= 0 { throw mutationValidation("quantity", "Must be positive") }
  for (field, value) in [("price", price), ("trigger_price", trigger)] {
    if let value, value.isNaN || value < 0 {
      throw mutationValidation(field, "Must be finite and nonnegative")
    }
  }
  if let disclosed, disclosed < 0 {
    throw mutationValidation("disclosed_quantity", "Must be nonnegative")
  }
  if let ttl, ttl <= 0 { throw mutationValidation("validity_ttl", "Must be positive minutes") }
  if let protection,
    protection.isNaN || !(protection == -1 || (protection > 0 && protection <= 100))
  {
    throw mutationValidation(
      "market_protection", "Expected -1 or a percentage greater than 0 and at most 100")
  }
}
