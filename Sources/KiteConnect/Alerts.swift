import Foundation

public enum KiteAlertType: KiteStringValue {
  case simple, ato
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "simple": self = .simple
    case "ato": self = .ato
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .simple: "simple"
    case .ato: "ato"
    case .unknown(let raw): raw
    }
  }
}

public enum KiteAlertStatus: KiteStringValue {
  case enabled, disabled, deleted
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "enabled": self = .enabled
    case "disabled": self = .disabled
    case "deleted": self = .deleted
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .enabled: "enabled"
    case .disabled: "disabled"
    case .deleted: "deleted"
    case .unknown(let raw): raw
    }
  }
}

public enum KiteAlertOperator: KiteStringValue {
  case lessThanOrEqual, greaterThanOrEqual, lessThan, greaterThan, equal
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "<=": self = .lessThanOrEqual
    case ">=": self = .greaterThanOrEqual
    case "<": self = .lessThan
    case ">": self = .greaterThan
    case "==": self = .equal
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .lessThanOrEqual: "<="
    case .greaterThanOrEqual: ">="
    case .lessThan: "<"
    case .greaterThan: ">"
    case .equal: "=="
    case .unknown(let raw): raw
    }
  }
}

public enum KiteAlertOperandType: KiteStringValue {
  case constant, instrument
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "constant": self = .constant
    case "instrument": self = .instrument
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .constant: "constant"
    case .instrument: "instrument"
    case .unknown(let raw): raw
    }
  }
}

/// Shared lifecycle response for simple and ATO alerts. Basket support is owned by ticket #14.
public struct KiteAlert: Decodable, Sendable, Equatable {
  public let type: KiteAlertType
  public let userID: String
  public let uuid: String
  public let name: String
  public let status: KiteAlertStatus
  public let disabledReason: String
  public let lhsAttribute: String
  public let lhsExchange: KiteExchange
  public let lhsTradingSymbol: String
  public let comparison: KiteAlertOperator
  public let rhsType: KiteAlertOperandType
  public let rhsAttribute: String
  public let rhsExchange: KiteExchange
  public let rhsTradingSymbol: String
  public let rhsConstant: Decimal
  public let alertCount: Int64
  public let createdAt: Date
  public let updatedAt: Date
  enum CodingKeys: String, CodingKey {
    case type = "type"
    case userID = "user_id"
    case uuid = "uuid"
    case name = "name"
    case status = "status"
    case disabledReason = "disabled_reason"
    case lhsAttribute = "lhs_attribute"
    case lhsExchange = "lhs_exchange"
    case lhsTradingSymbol = "lhs_tradingsymbol"
    case comparison = "operator"
    case rhsType = "rhs_type"
    case rhsAttribute = "rhs_attribute"
    case rhsExchange = "rhs_exchange"
    case rhsTradingSymbol = "rhs_tradingsymbol"
    case rhsConstant = "rhs_constant"
    case alertCount = "alert_count"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decode(KiteAlertType.self, forKey: .type)
    userID = try container.decode(String.self, forKey: .userID)
    uuid = try container.decode(String.self, forKey: .uuid)
    name = try container.decode(String.self, forKey: .name)
    status = try container.decode(KiteAlertStatus.self, forKey: .status)
    disabledReason = try container.decode(String.self, forKey: .disabledReason)
    lhsAttribute = try container.decode(String.self, forKey: .lhsAttribute)
    lhsExchange = try container.decode(KiteExchange.self, forKey: .lhsExchange)
    lhsTradingSymbol = try container.decode(String.self, forKey: .lhsTradingSymbol)
    comparison = try container.decode(KiteAlertOperator.self, forKey: .comparison)
    rhsType = try container.decode(KiteAlertOperandType.self, forKey: .rhsType)
    rhsAttribute = try container.decode(String.self, forKey: .rhsAttribute)
    rhsExchange = try container.decode(KiteExchange.self, forKey: .rhsExchange)
    rhsTradingSymbol = try container.decode(String.self, forKey: .rhsTradingSymbol)
    rhsConstant = try container.decode(Decimal.self, forKey: .rhsConstant)
    alertCount = try container.decode(Int64.self, forKey: .alertCount)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    guard !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .uuid, in: container, debugDescription: "Empty alert identifier")
    }
  }

}

extension KiteClient {
  public func alert(uuid: String) async throws -> KiteAlert {
    try alertIdentifier(uuid)
    return try await execute(KiteRequest(path: "/alerts/\(uuid)"), as: KiteAlert.self)
  }
}

extension KiteClient {
  public func alerts(status: KiteAlertStatus? = nil, page: Int? = nil, pageSize: Int? = nil)
    async throws -> [KiteAlert]
  {
    if let status { try alertText(status.rawValue, field: "status") }
    if let page, page <= 0 {
      throw KiteError.validation(field: "page", message: "Must be positive")
    }
    if let pageSize, pageSize <= 0 {
      throw KiteError.validation(field: "page_size", message: "Must be positive")
    }
    var query: [KiteParameter] = []
    if let status { query.append(.init("status", status.rawValue)) }
    if let page { query.append(.init("page", String(page))) }
    if let pageSize { query.append(.init("page_size", String(pageSize))) }
    return try await execute(KiteRequest(path: "/alerts", query: query), as: [KiteAlert].self)
  }
}

/// Instrument/attribute operand shared by simple alerts and future ATO requests.
/// Attributes are server-owned strings; the docs give LastTradedPrice as an example.
public struct KiteAlertInstrument: Sendable, Equatable {
  public var exchange: KiteExchange
  public var tradingSymbol: String
  public var attribute: String
  public init(exchange: KiteExchange, tradingSymbol: String, attribute: String) {
    self.exchange = exchange
    self.tradingSymbol = tradingSymbol
    self.attribute = attribute
  }
}

public enum KiteAlertOperand: Sendable, Equatable {
  case constant(Decimal)
  case instrument(KiteAlertInstrument)
}

/// Shared comparison structure; does not own alert lifecycle or order basket details.
public struct KiteAlertCondition: Sendable, Equatable {
  public var lhs: KiteAlertInstrument
  public var comparison: KiteAlertOperator
  public var rhs: KiteAlertOperand
  public init(lhs: KiteAlertInstrument, comparison: KiteAlertOperator, rhs: KiteAlertOperand) {
    self.lhs = lhs
    self.comparison = comparison
    self.rhs = rhs
  }

  /// Module seam for adding ATO form parameters without duplicating comparison encoding.
  func parameters() throws -> [KiteParameter] {
    try alertInstrument(lhs, prefix: "lhs")
    try alertText(comparison.rawValue, field: "operator")
    switch rhs {
    case .constant(let value):
      guard !value.isNaN else {
        throw KiteError.validation(field: "rhs_constant", message: "Must be finite")
      }
    case .instrument(let value): try alertInstrument(value, prefix: "rhs")
    }
    var fields: [KiteParameter] = [
      .init("lhs_exchange", lhs.exchange.rawValue), .init("lhs_tradingsymbol", lhs.tradingSymbol),
      .init("lhs_attribute", lhs.attribute), .init("operator", comparison.rawValue),
    ]
    switch rhs {
    case .constant(let value):
      fields += [.init("rhs_type", "constant"), .init("rhs_constant", value.description)]
    case .instrument(let value):
      fields += [
        .init("rhs_type", "instrument"), .init("rhs_exchange", value.exchange.rawValue),
        .init("rhs_tradingsymbol", value.tradingSymbol), .init("rhs_attribute", value.attribute),
      ]
    }
    return fields
  }
}

/// Complete simple-alert definition, used for creation and replacement-style modification.
public struct KiteSimpleAlertRequest: Sendable, Equatable {
  public var name: String
  public var condition: KiteAlertCondition
  public init(name: String, condition: KiteAlertCondition) {
    self.name = name
    self.condition = condition
  }
}

extension KiteClient {
  /// Sends once. On uncertainty, inspect alerts before deciding whether to submit again.
  public func createAlert(_ alert: KiteSimpleAlertRequest) async throws -> KiteAlert {
    try alertText(alert.name, field: "name")
    return try await execute(
      KiteRequest(
        method: .post, path: "/alerts",
        body: .form(
          [.init("name", alert.name), .init("type", "simple")] + (try alert.condition.parameters())),
        isTradingMutation: true), as: KiteAlert.self)
  }

  /// Fetch current state first, then supply the complete desired simple-alert definition.
  public func modifyAlert(uuid: String, alert: KiteSimpleAlertRequest) async throws -> KiteAlert {
    try alertIdentifier(uuid)
    try alertText(alert.name, field: "name")
    return try await execute(
      KiteRequest(
        method: .put, path: "/alerts/\(uuid)",
        body: .form(
          [.init("name", alert.name), .init("type", "simple")] + (try alert.condition.parameters())),
        isTradingMutation: true), as: KiteAlert.self)
  }
}

extension KiteClient {
  public func deleteAlert(uuid: String) async throws {
    try await deleteAlerts(uuids: [uuid])
  }

  /// Soft-delete one or more alerts in a single request. No automatic resubmission.
  public func deleteAlerts(uuids: [String]) async throws {
    guard !uuids.isEmpty else {
      throw KiteError.validation(field: "uuid", message: "Expected at least one identifier")
    }
    for uuid in uuids { try alertIdentifier(uuid) }
    _ = try await execute(
      KiteRequest(
        method: .delete, path: "/alerts",
        query: uuids.map { .init("uuid", $0) }, isTradingMutation: true), as: KiteAlertDeletion.self
    )
  }
}

private struct KiteAlertDeletion: Decodable, Sendable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    guard container.decodeNil() else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Expected null deletion data")
    }
  }
}

/// Trigger-time market data, whose documented shape differs from a full quote.
public struct KiteAlertMarketData: Decodable, Sendable, Equatable {
  public let instrumentToken: UInt32
  public let tradingSymbol: String
  public let timestamp: Date
  public let lastTradeTime: Date
  public let exchange: KiteExchange
  public let lastPrice: Decimal
  public let ohlc: KiteOHLC
  public let netChange: Decimal
  public let lastQuantity: Int64
  public let buyQuantity: Int64
  public let sellQuantity: Int64
  public let volume: Int64
  public let volumeTick: Int64
  public let averagePrice: Decimal
  public let oi: Decimal
  public let oiDayHigh: Decimal
  public let oiDayLow: Decimal
  public let lowerCircuitLimit: Decimal
  public let upperCircuitLimit: Decimal
  enum CodingKeys: String, CodingKey {
    case instrumentToken = "instrument_token"
    case tradingSymbol = "tradingsymbol"
    case timestamp = "timestamp"
    case lastTradeTime = "last_trade_time"
    case exchange = "exchange"
    case lastPrice = "last_price"
    case ohlc = "ohlc"
    case netChange = "net_change"
    case lastQuantity = "last_quantity"
    case buyQuantity = "buy_quantity"
    case sellQuantity = "sell_quantity"
    case volume = "volume"
    case volumeTick = "volume_tick"
    case averagePrice = "average_price"
    case oi = "oi"
    case oiDayHigh = "oi_day_high"
    case oiDayLow = "oi_day_low"
    case lowerCircuitLimit = "lower_circuit_limit"
    case upperCircuitLimit = "upper_circuit_limit"
  }
}

/// Lifecycle history shared by alert types; order metadata remains raw pending ticket #14.
public struct KiteAlertHistoryEntry: Decodable, Sendable, Equatable {
  public let uuid: String
  public let type: KiteAlertType
  public let meta: [KiteAlertMarketData]
  public let condition: String
  public let createdAt: Date
  public let orderMeta: KiteOrderMutationJSONValue?
  enum CodingKeys: String, CodingKey {
    case uuid, type, meta, condition
    case createdAt = "created_at"
    case orderMeta = "order_meta"
  }
}

extension KiteClient {
  public func alertHistory(uuid: String) async throws -> [KiteAlertHistoryEntry] {
    try alertIdentifier(uuid)
    return try await execute(
      KiteRequest(path: "/alerts/\(uuid)/history"), as: [KiteAlertHistoryEntry].self)
  }
}

private func alertIdentifier(_ value: String) throws {
  let allowed = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
  guard !value.isEmpty, value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
    throw KiteError.validation(field: "uuid", message: "Expected a nonempty safe identifier")
  }
}

func alertText(_ value: String, field: String) throws {
  guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
    !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
  else {
    throw KiteError.validation(
      field: field, message: "Expected nonempty text without control characters")
  }
}

private func alertInstrument(_ value: KiteAlertInstrument, prefix: String) throws {
  try alertText(value.exchange.rawValue, field: "\(prefix)_exchange")
  try alertText(value.tradingSymbol, field: "\(prefix)_tradingsymbol")
  try alertText(value.attribute, field: "\(prefix)_attribute")
}
