import Foundation

/// A mutual fund catalogue entry, independent of equity instrument tokens.
public struct KiteMutualFundInstrument: Sendable, Equatable {
  public let tradingSymbol: String
  public let amc: String
  public let name: String
  public let purchaseAllowed: Bool
  public let redemptionAllowed: Bool
  public let minimumPurchaseAmount: Decimal
  public let purchaseAmountMultiplier: Decimal
  public let minimumAdditionalPurchaseAmount: Decimal
  public let minimumRedemptionQuantity: Decimal
  public let redemptionQuantityMultiplier: Decimal
  public let dividendType: KiteMutualFundDividendType
  public let schemeType: KiteMutualFundSchemeType
  public let plan: KiteMutualFundPlan
  public let settlementType: String
  public let lastPrice: Decimal
  public let lastPriceDate: KiteDateOnly
}

public enum KiteMutualFundSchemeType: KiteStringValue {
  case equity, debt, elss
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "equity": self = .equity
    case "debt": self = .debt
    case "elss": self = .elss
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .equity: "equity"
    case .debt: "debt"
    case .elss: "elss"
    case .unknown(let value): value
    }
  }
}

public enum KiteMutualFundPlan: KiteStringValue {
  case direct, regular
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "direct": self = .direct
    case "regular": self = .regular
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .direct: "direct"
    case .regular: "regular"
    case .unknown(let value): value
    }
  }
}

extension KiteClient {
  /// Download MF CSV using authenticated API routing, including the sandbox /oms prefix.
  /// Transports supply decompressed bytes; URLSession handles Content-Encoding gzip.
  public func mutualFundInstruments() async throws -> [KiteMutualFundInstrument] {
    let response = try await response(for: KiteRequest(path: "/mf/instruments"))
    do { return try parseMutualFundInstruments(response.body) } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw KiteError.decoding(statusCode: response.statusCode, message: String(describing: error))
    }
  }
}

private func parseMutualFundInstruments(_ data: Data) throws -> [KiteMutualFundInstrument] {
  let required = [
    "tradingsymbol", "amc", "name", "purchase_allowed", "redemption_allowed",
    "minimum_purchase_amount", "purchase_amount_multiplier", "minimum_additional_purchase_amount",
    "minimum_redemption_quantity", "redemption_quantity_multiplier", "dividend_type", "scheme_type",
    "plan", "settlement_type", "last_price", "last_price_date",
  ]
  let table = try KiteCSV.Table(data, required: required)
  return try table.rows.enumerated().map { offset, values in
    let row = try table.row(values, record: offset + 2)
    return try KiteMutualFundInstrument(
      tradingSymbol: row.nonempty("tradingsymbol"),
      amc: row.nonempty("amc"),
      name: row.nonempty("name"),
      purchaseAllowed: row.boolean("purchase_allowed"),
      redemptionAllowed: row.boolean("redemption_allowed"),
      minimumPurchaseAmount: row.decimal("minimum_purchase_amount"),
      purchaseAmountMultiplier: row.decimal("purchase_amount_multiplier"),
      minimumAdditionalPurchaseAmount: row.decimal("minimum_additional_purchase_amount"),
      minimumRedemptionQuantity: row.decimal("minimum_redemption_quantity"),
      redemptionQuantityMultiplier: row.decimal("redemption_quantity_multiplier"),
      dividendType: KiteMutualFundDividendType(rawValue: row.nonempty("dividend_type")),
      schemeType: KiteMutualFundSchemeType(rawValue: row.nonempty("scheme_type")),
      plan: KiteMutualFundPlan(rawValue: row.nonempty("plan")),
      settlementType: row.nonempty("settlement_type"),
      lastPrice: row.decimal("last_price"),
      lastPriceDate: KiteDateOnly(row.value("last_price_date")))
  }
}
