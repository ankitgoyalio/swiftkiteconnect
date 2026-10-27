import Foundation

public struct KiteMutualFundOrder: Decodable, Sendable, Equatable {
  public let orderID: String
  public let exchangeOrderID: String?
  public let tradingSymbol: String
  public let status: KiteOrderStatus?
  public let statusMessage: String?
  public let folio: String?
  public let fund: String
  public let orderTimestamp: Date
  public let exchangeTimestamp: KiteDateOnly?
  public let settlementID: String?
  public let transactionType: KiteTransactionType
  public let amount: Decimal
  public let variety: KiteMutualFundVariety
  public let purchaseType: KiteMutualFundPurchaseType?
  public let quantity: Decimal
  public let price: Decimal?
  public let lastPrice: Decimal
  public let averagePrice: Decimal
  public let placedBy: String
  public let lastPriceDate: KiteDateOnly
  public let tag: String?
  enum CodingKeys: String, CodingKey {
    case orderID = "order_id"
    case exchangeOrderID = "exchange_order_id"
    case tradingSymbol = "tradingsymbol"
    case status = "status"
    case statusMessage = "status_message"
    case folio = "folio"
    case fund = "fund"
    case orderTimestamp = "order_timestamp"
    case exchangeTimestamp = "exchange_timestamp"
    case settlementID = "settlement_id"
    case transactionType = "transaction_type"
    case amount = "amount"
    case variety = "variety"
    case purchaseType = "purchase_type"
    case quantity = "quantity"
    case price = "price"
    case lastPrice = "last_price"
    case averagePrice = "average_price"
    case placedBy = "placed_by"
    case lastPriceDate = "last_price_date"
    case tag = "tag"
  }
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    orderID = try c.decode(String.self, forKey: .orderID)
    exchangeOrderID = try c.decodeIfPresent(String.self, forKey: .exchangeOrderID)
    tradingSymbol = try c.decode(String.self, forKey: .tradingSymbol)
    status = try c.decodeIfPresent(KiteOrderStatus.self, forKey: .status)
    statusMessage = try c.decodeIfPresent(String.self, forKey: .statusMessage)
    folio = try c.decodeIfPresent(String.self, forKey: .folio)
    fund = try c.decode(String.self, forKey: .fund)
    orderTimestamp = try c.decode(Date.self, forKey: .orderTimestamp)
    exchangeTimestamp = try c.decodeIfPresent(String.self, forKey: .exchangeTimestamp).map {
      try KiteDateOnly($0)
    }
    settlementID = try c.decodeIfPresent(String.self, forKey: .settlementID)
    transactionType = try c.decode(KiteTransactionType.self, forKey: .transactionType)
    amount = try c.decode(Decimal.self, forKey: .amount)
    variety = try c.decode(KiteMutualFundVariety.self, forKey: .variety)
    purchaseType = try c.decodeIfPresent(KiteMutualFundPurchaseType.self, forKey: .purchaseType)
    quantity = try c.decode(Decimal.self, forKey: .quantity)
    price = try c.decodeIfPresent(Decimal.self, forKey: .price)
    lastPrice = try c.decode(Decimal.self, forKey: .lastPrice)
    averagePrice = try c.decode(Decimal.self, forKey: .averagePrice)
    placedBy = try c.decode(String.self, forKey: .placedBy)
    lastPriceDate = try KiteDateOnly(try c.decode(String.self, forKey: .lastPriceDate))
    tag = try c.decodeIfPresent(String.self, forKey: .tag)
  }
}

extension KiteClient {
  /// Orders placed within the last seven days.
  public func mutualFundOrders() async throws -> [KiteMutualFundOrder] {
    try await execute(KiteRequest(path: "/mf/orders"), as: [KiteMutualFundOrder].self)
  }
}

public enum KiteMutualFundVariety: KiteStringValue {
  case regular, sip, amcSIP
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "regular": self = .regular
    case "sip": self = .sip
    case "amc_sip": self = .amcSIP
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .regular: "regular"
    case .sip: "sip"
    case .amcSIP: "amc_sip"
    case .unknown(let value): value
    }
  }
}

public enum KiteMutualFundPurchaseType: KiteStringValue {
  case fresh, additional
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "FRESH": self = .fresh
    case "ADDITIONAL": self = .additional
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .fresh: "FRESH"
    case .additional: "ADDITIONAL"
    case .unknown(let value): value
    }
  }
}

extension KiteClient {
  /// Retrieve an order by ID irrespective of its age.
  public func mutualFundOrder(orderID: String) async throws -> KiteMutualFundOrder {
    guard !orderID.isEmpty, !orderID.contains(".."),
      !orderID.contains(where: { $0.isWhitespace || "/\\?#".contains($0) }),
      !orderID.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else {
      throw KiteError.validation(
        field: "orderID", message: "Expected a single nonempty order ID path component")
    }
    return try await execute(
      KiteRequest(path: "/mf/orders/" + orderID), as: KiteMutualFundOrder.self)
  }
}
public struct KiteMutualFundSIP: Decodable, Sendable, Equatable {
  public let sipID: String
  public let tradingSymbol: String
  public let fund: String
  public let dividendType: KiteMutualFundDividendType
  public let transactionType: KiteTransactionType
  public let status: KiteMutualFundSIPStatus
  public let created: Date
  public let frequency: KiteMutualFundFrequency
  public let nextInstalment: KiteDateOnly
  public let instalmentAmount: Decimal
  public let instalments: Int64
  public let lastInstalment: Date?
  public let pendingInstalments: Int64
  public let instalmentDay: Int
  public let completedInstalments: Int64
  public let tag: String?
  public let registrationNumber: String?
  public let triggerPrice: Decimal?
  public let stepUp: [String: Decimal]?
  public let sipType: KiteMutualFundVariety?
  enum CodingKeys: String, CodingKey {
    case sipID = "sip_id"
    case tradingSymbol = "tradingsymbol"
    case fund = "fund"
    case dividendType = "dividend_type"
    case transactionType = "transaction_type"
    case status = "status"
    case created = "created"
    case frequency = "frequency"
    case nextInstalment = "next_instalment"
    case instalmentAmount = "instalment_amount"
    case instalments = "instalments"
    case lastInstalment = "last_instalment"
    case pendingInstalments = "pending_instalments"
    case instalmentDay = "instalment_day"
    case completedInstalments = "completed_instalments"
    case tag = "tag"
    case registrationNumber = "sip_reg_num"
    case triggerPrice = "trigger_price"
    case stepUp = "step_up"
    case sipType = "sip_type"
  }
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    sipID = try c.decode(String.self, forKey: .sipID)
    tradingSymbol = try c.decode(String.self, forKey: .tradingSymbol)
    fund = try c.decode(String.self, forKey: .fund)
    dividendType = try c.decode(KiteMutualFundDividendType.self, forKey: .dividendType)
    transactionType = try c.decode(KiteTransactionType.self, forKey: .transactionType)
    status = try c.decode(KiteMutualFundSIPStatus.self, forKey: .status)
    created = try c.decode(Date.self, forKey: .created)
    frequency = try c.decode(KiteMutualFundFrequency.self, forKey: .frequency)
    nextInstalment = try KiteDateOnly(try c.decode(String.self, forKey: .nextInstalment))
    instalmentAmount = try c.decode(Decimal.self, forKey: .instalmentAmount)
    instalments = try c.decode(Int64.self, forKey: .instalments)
    lastInstalment = try c.decodeIfPresent(Date.self, forKey: .lastInstalment)
    pendingInstalments = try c.decode(Int64.self, forKey: .pendingInstalments)
    instalmentDay = try c.decode(Int.self, forKey: .instalmentDay)
    completedInstalments = try c.decode(Int64.self, forKey: .completedInstalments)
    tag = try c.decodeIfPresent(String.self, forKey: .tag)
    registrationNumber = try c.decodeIfPresent(String.self, forKey: .registrationNumber)
    triggerPrice = try c.decodeIfPresent(Decimal.self, forKey: .triggerPrice)
    stepUp = try c.decodeIfPresent([String: Decimal].self, forKey: .stepUp)
    sipType = try c.decodeIfPresent(KiteMutualFundVariety.self, forKey: .sipType)
  }
}

public enum KiteMutualFundDividendType: KiteStringValue {
  case growth, payout, idcw
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "growth": self = .growth
    case "payout": self = .payout
    case "idcw": self = .idcw
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .growth: "growth"
    case .payout: "payout"
    case .idcw: "idcw"
    case .unknown(let value): value
    }
  }
}

public enum KiteMutualFundFrequency: KiteStringValue {
  case monthly, weekly, quarterly
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "monthly": self = .monthly
    case "weekly": self = .weekly
    case "quarterly": self = .quarterly
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .monthly: "monthly"
    case .weekly: "weekly"
    case .quarterly: "quarterly"
    case .unknown(let value): value
    }
  }
}

public enum KiteMutualFundSIPStatus: KiteStringValue {
  case active, paused, cancelled
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "ACTIVE": self = .active
    case "PAUSED": self = .paused
    case "CANCELLED": self = .cancelled
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .active: "ACTIVE"
    case .paused: "PAUSED"
    case .cancelled: "CANCELLED"
    case .unknown(let value): value
    }
  }
}

extension KiteClient {
  /// All active and paused SIPs. No individual-SIP route is documented in this snapshot.
  public func mutualFundSIPs() async throws -> [KiteMutualFundSIP] {
    let response = try await response(for: KiteRequest(path: "/mf/sips"))
    do {
      let result = try KiteTimestamp.decoder(timeZone: configuration.tradingTimeZone)
        .decode(MutualFundSIPEnvelope.self, from: response.body)
      guard result.status == nil || result.status == "success" else {
        throw KiteError.decoding(
          statusCode: response.statusCode, message: "Expected success envelope")
      }
      return result.data
    } catch {
      throw KiteError.decoding(
        statusCode: response.statusCode, message: "Malformed SIP response: \(error)")
    }
  }
}
// The documented SIP example omits status, unlike the other MF examples.
private struct MutualFundSIPEnvelope: Decodable {
  let status: String?
  let data: [KiteMutualFundSIP]
}
public struct KiteMutualFundHolding: Decodable, Sendable, Equatable {
  public let folio: String?
  public let fund: String
  public let tradingSymbol: String
  public let averagePrice: Decimal
  public let lastPrice: Decimal
  public let pnl: Decimal
  public let lastPriceDate: KiteDateOnly?
  public let quantity: Decimal
  public let pledgedQuantity: Decimal?
  enum CodingKeys: String, CodingKey {
    case folio = "folio"
    case fund = "fund"
    case tradingSymbol = "tradingsymbol"
    case averagePrice = "average_price"
    case lastPrice = "last_price"
    case pnl = "pnl"
    case lastPriceDate = "last_price_date"
    case quantity = "quantity"
    case pledgedQuantity = "pledged_quantity"
  }
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    folio = try c.decodeIfPresent(String.self, forKey: .folio)
    fund = try c.decode(String.self, forKey: .fund)
    tradingSymbol = try c.decode(String.self, forKey: .tradingSymbol)
    averagePrice = try c.decode(Decimal.self, forKey: .averagePrice)
    lastPrice = try c.decode(Decimal.self, forKey: .lastPrice)
    pnl = try c.decode(Decimal.self, forKey: .pnl)
    lastPriceDate = try (try c.decodeIfPresent(String.self, forKey: .lastPriceDate)).flatMap {
      $0.isEmpty ? nil : try KiteDateOnly($0)
    }
    quantity = try c.decode(Decimal.self, forKey: .quantity)
    pledgedQuantity = try c.decodeIfPresent(Decimal.self, forKey: .pledgedQuantity)
  }
}

extension KiteClient {
  /// Allotted mutual fund units in the user's DEMAT account.
  public func mutualFundHoldings() async throws -> [KiteMutualFundHolding] {
    try await execute(KiteRequest(path: "/mf/holdings"), as: [KiteMutualFundHolding].self)
  }
}
