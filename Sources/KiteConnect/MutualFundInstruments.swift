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
  let rows = try KiteCSV.records(data)
  guard let rawHeader = rows.first else { throw KiteCSV.Failure("Missing MF CSV header") }
  let header = rawHeader.map { $0.trimmingCharacters(in: .whitespaces) }
  guard Set(header).count == header.count, !header.contains("") else {
    throw KiteCSV.Failure("Duplicate or empty MF CSV column")
  }
  let required = [
    "tradingsymbol", "amc", "name", "purchase_allowed", "redemption_allowed",
    "minimum_purchase_amount", "purchase_amount_multiplier", "minimum_additional_purchase_amount",
    "minimum_redemption_quantity", "redemption_quantity_multiplier", "dividend_type", "scheme_type",
    "plan", "settlement_type", "last_price", "last_price_date",
  ]
  for key in required where !header.contains(key) { throw KiteCSV.Failure("Missing column \(key)") }
  let indices = Dictionary(
    uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })
  return try rows.dropFirst().enumerated().map { offset, row in
    try Task.checkCancellation()
    guard row.count == header.count else {
      throw KiteCSV.Failure("Wrong MF field count in record \(offset + 2)")
    }
    func value(_ key: String) -> String { row[indices[key]!] }
    func failure(_ key: String) -> KiteCSV.Failure {
      KiteCSV.Failure("Invalid \(key) in MF record \(offset + 2)")
    }
    func nonempty(_ key: String) throws -> String {
      let raw = value(key)
      guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw failure(key) }
      return raw
    }
    func boolean(_ key: String) throws -> Bool {
      guard ["0", "1"].contains(value(key)) else { throw failure(key) }
      return value(key) == "1"
    }
    func decimal(_ key: String) throws -> Decimal {
      let raw = value(key)
      let mantissa = raw.split(whereSeparator: { $0 == "e" || $0 == "E" }).first ?? ""
      let significant = mantissa.utf8.filter { (48...57).contains($0) }
        .drop(while: { $0 == 48 }).reversed().drop(while: { $0 == 48 })
      guard significant.count <= 38,
        raw.range(
          of: #"^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression)
          != nil,
        let result = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), !result.isNaN
      else { throw failure(key) }
      return result
    }
    return try KiteMutualFundInstrument(
      tradingSymbol: nonempty("tradingsymbol"),
      amc: nonempty("amc"),
      name: nonempty("name"),
      purchaseAllowed: boolean("purchase_allowed"),
      redemptionAllowed: boolean("redemption_allowed"),
      minimumPurchaseAmount: decimal("minimum_purchase_amount"),
      purchaseAmountMultiplier: decimal("purchase_amount_multiplier"),
      minimumAdditionalPurchaseAmount: decimal("minimum_additional_purchase_amount"),
      minimumRedemptionQuantity: decimal("minimum_redemption_quantity"),
      redemptionQuantityMultiplier: decimal("redemption_quantity_multiplier"),
      dividendType: KiteMutualFundDividendType(rawValue: nonempty("dividend_type")),
      schemeType: KiteMutualFundSchemeType(rawValue: nonempty("scheme_type")),
      plan: KiteMutualFundPlan(rawValue: nonempty("plan")),
      settlementType: nonempty("settlement_type"),
      lastPrice: decimal("last_price"),
      lastPriceDate: KiteDateOnly(value("last_price_date")))
  }
}
