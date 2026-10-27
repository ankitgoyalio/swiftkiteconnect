import Foundation

/// Long-term equity holding; metadata absent from a response remains nil.
public struct KiteHolding: Decodable, Sendable, Equatable {
  public let identity: KiteInstrumentIdentity
  public let tradingSymbol: String
  public let exchange: KiteExchange
  public let instrumentToken: UInt32
  public let isin: String
  public let product: KiteProduct
  public let quantity: Int64
  public let t1Quantity: Int64
  public let realisedQuantity: Int64
  public let authorisedQuantity: Int64
  public let openingQuantity: Int64
  public let collateralQuantity: Int64
  public let usedQuantity: Int64?
  public let shortQuantity: Int64?
  public let authorisedDate: Date?
  public let authorisation: [String: KiteOrderMutationJSONValue]?
  public let collateralType: String?
  public let discrepancy: Bool
  public let price: Decimal
  public let averagePrice: Decimal
  public let lastPrice: Decimal
  public let closePrice: Decimal
  public let pnl: Decimal
  public let dayChange: Decimal
  public let dayChangePercentage: Decimal
  public let mtf: KiteHoldingMTF?
  enum CodingKeys: String, CodingKey {
    case tradingSymbol = "tradingsymbol"
    case exchange
    case instrumentToken = "instrument_token"
    case isin
    case product
    case quantity
    case t1Quantity = "t1_quantity"
    case realisedQuantity = "realised_quantity"
    case authorisedQuantity = "authorised_quantity"
    case openingQuantity = "opening_quantity"
    case collateralQuantity = "collateral_quantity"
    case usedQuantity = "used_quantity"
    case shortQuantity = "short_quantity"
    case authorisedDate = "authorised_date"
    case authorisation
    case collateralType = "collateral_type"
    case discrepancy
    case price
    case averagePrice = "average_price"
    case lastPrice = "last_price"
    case closePrice = "close_price"
    case pnl
    case dayChange = "day_change"
    case dayChangePercentage = "day_change_percentage"
    case mtf
  }
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    tradingSymbol = try c.decode(String.self, forKey: .tradingSymbol)
    exchange = try c.decode(KiteExchange.self, forKey: .exchange)
    instrumentToken = try c.decode(UInt32.self, forKey: .instrumentToken)
    isin = try c.decode(String.self, forKey: .isin)
    product = try c.decode(KiteProduct.self, forKey: .product)
    quantity = try c.decode(Int64.self, forKey: .quantity)
    t1Quantity = try c.decode(Int64.self, forKey: .t1Quantity)
    realisedQuantity = try c.decode(Int64.self, forKey: .realisedQuantity)
    authorisedQuantity = try c.decode(Int64.self, forKey: .authorisedQuantity)
    openingQuantity = try c.decode(Int64.self, forKey: .openingQuantity)
    collateralQuantity = try c.decode(Int64.self, forKey: .collateralQuantity)
    usedQuantity = try c.decodeIfPresent(Int64.self, forKey: .usedQuantity)
    shortQuantity = try c.decodeIfPresent(Int64.self, forKey: .shortQuantity)
    authorisedDate = try c.decodeIfPresent(Date.self, forKey: .authorisedDate)
    authorisation = try c.decodeIfPresent(
      [String: KiteOrderMutationJSONValue].self, forKey: .authorisation)
    collateralType = try c.decodeIfPresent(String.self, forKey: .collateralType)
    discrepancy = try c.decode(Bool.self, forKey: .discrepancy)
    price = try c.decode(Decimal.self, forKey: .price)
    averagePrice = try c.decode(Decimal.self, forKey: .averagePrice)
    lastPrice = try c.decode(Decimal.self, forKey: .lastPrice)
    closePrice = try c.decode(Decimal.self, forKey: .closePrice)
    pnl = try c.decode(Decimal.self, forKey: .pnl)
    dayChange = try c.decode(Decimal.self, forKey: .dayChange)
    dayChangePercentage = try c.decode(Decimal.self, forKey: .dayChangePercentage)
    mtf = try c.decodeIfPresent(KiteHoldingMTF.self, forKey: .mtf)
    identity = try KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
  }
}

public struct KiteHoldingMTF: Decodable, Sendable, Equatable {
  public let quantity: Int64
  public let usedQuantity: Int64
  public let averagePrice: Decimal
  public let value: Decimal
  public let initialMargin: Decimal
  enum CodingKeys: String, CodingKey {
    case quantity
    case usedQuantity = "used_quantity"
    case averagePrice = "average_price"
    case value
    case initialMargin = "initial_margin"
  }
}

extension KiteClient {
  public func holdings() async throws -> [KiteHolding] {
    try await execute(KiteRequest(path: "/portfolio/holdings"), as: [KiteHolding].self)
  }
}

/// Auction rows use the holding wire layout, adding a required auction number.
public struct KiteAuctionHolding: Decodable, Sendable, Equatable {
  public let holding: KiteHolding
  public let auctionNumber: String
  enum CodingKeys: String, CodingKey { case auctionNumber = "auction_number" }
  public init(from decoder: any Decoder) throws {
    holding = try KiteHolding(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    auctionNumber = try c.decode(String.self, forKey: .auctionNumber)
    guard !auctionNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .auctionNumber, in: c, debugDescription: "Empty auction number")
    }
  }
}
extension KiteClient {
  public func auctionHoldings() async throws -> [KiteAuctionHolding] {
    try await execute(
      KiteRequest(path: "/portfolio/holdings/auctions"), as: [KiteAuctionHolding].self)
  }
}

public struct KitePosition: Decodable, Sendable, Equatable {
  public let identity: KiteInstrumentIdentity
  public let tradingSymbol: String
  public let exchange: KiteExchange
  public let instrumentToken: UInt32
  public let product: KiteProduct
  public let quantity: Int64
  public let overnightQuantity: Int64
  public let multiplier: Int64
  public let buyQuantity: Int64
  public let sellQuantity: Int64
  public let dayBuyQuantity: Int64
  public let daySellQuantity: Int64
  public let averagePrice: Decimal
  public let closePrice: Decimal
  public let lastPrice: Decimal
  public let value: Decimal
  public let pnl: Decimal
  public let m2m: Decimal
  public let unrealised: Decimal
  public let realised: Decimal
  public let buyPrice: Decimal
  public let buyValue: Decimal
  public let buyM2M: Decimal
  public let sellPrice: Decimal
  public let sellValue: Decimal
  public let sellM2M: Decimal
  public let dayBuyPrice: Decimal
  public let dayBuyValue: Decimal
  public let daySellPrice: Decimal
  public let daySellValue: Decimal
  enum CodingKeys: String, CodingKey {
    case tradingSymbol = "tradingsymbol"
    case exchange
    case instrumentToken = "instrument_token"
    case product
    case quantity
    case overnightQuantity = "overnight_quantity"
    case multiplier
    case buyQuantity = "buy_quantity"
    case sellQuantity = "sell_quantity"
    case dayBuyQuantity = "day_buy_quantity"
    case daySellQuantity = "day_sell_quantity"
    case averagePrice = "average_price"
    case closePrice = "close_price"
    case lastPrice = "last_price"
    case value
    case pnl
    case m2m
    case unrealised
    case realised
    case buyPrice = "buy_price"
    case buyValue = "buy_value"
    case buyM2M = "buy_m2m"
    case sellPrice = "sell_price"
    case sellValue = "sell_value"
    case sellM2M = "sell_m2m"
    case dayBuyPrice = "day_buy_price"
    case dayBuyValue = "day_buy_value"
    case daySellPrice = "day_sell_price"
    case daySellValue = "day_sell_value"
  }
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    tradingSymbol = try c.decode(String.self, forKey: .tradingSymbol)
    exchange = try c.decode(KiteExchange.self, forKey: .exchange)
    instrumentToken = try c.decode(UInt32.self, forKey: .instrumentToken)
    product = try c.decode(KiteProduct.self, forKey: .product)
    quantity = try c.decode(Int64.self, forKey: .quantity)
    overnightQuantity = try c.decode(Int64.self, forKey: .overnightQuantity)
    multiplier = try c.decode(Int64.self, forKey: .multiplier)
    buyQuantity = try c.decode(Int64.self, forKey: .buyQuantity)
    sellQuantity = try c.decode(Int64.self, forKey: .sellQuantity)
    dayBuyQuantity = try c.decode(Int64.self, forKey: .dayBuyQuantity)
    daySellQuantity = try c.decode(Int64.self, forKey: .daySellQuantity)
    averagePrice = try c.decode(Decimal.self, forKey: .averagePrice)
    closePrice = try c.decode(Decimal.self, forKey: .closePrice)
    lastPrice = try c.decode(Decimal.self, forKey: .lastPrice)
    value = try c.decode(Decimal.self, forKey: .value)
    pnl = try c.decode(Decimal.self, forKey: .pnl)
    m2m = try c.decode(Decimal.self, forKey: .m2m)
    unrealised = try c.decode(Decimal.self, forKey: .unrealised)
    realised = try c.decode(Decimal.self, forKey: .realised)
    buyPrice = try c.decode(Decimal.self, forKey: .buyPrice)
    buyValue = try c.decode(Decimal.self, forKey: .buyValue)
    buyM2M = try c.decode(Decimal.self, forKey: .buyM2M)
    sellPrice = try c.decode(Decimal.self, forKey: .sellPrice)
    sellValue = try c.decode(Decimal.self, forKey: .sellValue)
    sellM2M = try c.decode(Decimal.self, forKey: .sellM2M)
    dayBuyPrice = try c.decode(Decimal.self, forKey: .dayBuyPrice)
    dayBuyValue = try c.decode(Decimal.self, forKey: .dayBuyValue)
    daySellPrice = try c.decode(Decimal.self, forKey: .daySellPrice)
    daySellValue = try c.decode(Decimal.self, forKey: .daySellValue)
    identity = try KiteInstrumentIdentity(exchange: exchange, tradingSymbol: tradingSymbol)
  }
}

public struct KitePositions: Decodable, Sendable, Equatable {
  public let net: [KitePosition]
  public let day: [KitePosition]
}
extension KiteClient {
  public func positions() async throws -> KitePositions {
    try await execute(KiteRequest(path: "/portfolio/positions"), as: KitePositions.self)
  }
}

public enum KitePositionConversionType: String, Sendable {
  case overnight, day
}

public struct KitePositionConversion: Sendable {
  public var instrument: KiteInstrumentIdentity
  public var transactionType: KiteOrderMutationSide
  public var positionType: KitePositionConversionType
  public var quantity: Int64
  public var oldProduct: KiteProduct
  public var newProduct: KiteProduct
  public init(
    instrument: KiteInstrumentIdentity, transactionType: KiteOrderMutationSide,
    positionType: KitePositionConversionType, quantity: Int64,
    oldProduct: KiteProduct, newProduct: KiteProduct
  ) {
    self.instrument = instrument
    self.transactionType = transactionType
    self.positionType = positionType
    self.quantity = quantity
    self.oldProduct = oldProduct
    self.newProduct = newProduct
  }
}

extension KiteClient {
  /// Changes a position's margin product, with no automatic retry or reconciliation.
  public func convertPosition(_ conversion: KitePositionConversion) async throws -> Bool {
    try portfolioQuantity(conversion.quantity)
    try portfolioText(conversion.oldProduct.rawValue, field: "old_product")
    try portfolioText(conversion.newProduct.rawValue, field: "new_product")
    return try await execute(
      KiteRequest(
        method: .put, path: "/portfolio/positions",
        body: .form([
          .init("tradingsymbol", conversion.instrument.tradingSymbol),
          .init("exchange", conversion.instrument.exchange.rawValue),
          .init("transaction_type", conversion.transactionType.rawValue),
          .init("position_type", conversion.positionType.rawValue),
          .init("quantity", String(conversion.quantity)),
          .init("old_product", conversion.oldProduct.rawValue),
          .init("new_product", conversion.newProduct.rawValue),
        ]), isTradingMutation: true), as: Bool.self)
  }
}
private func portfolioText(_ value: String, field: String) throws {
  guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
    !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
  else {
    throw KiteError.validation(field: field, message: "Expected nonblank text without controls")
  }
}
private func portfolioQuantity(_ value: Int64) throws {
  guard value > 0 else {
    throw KiteError.validation(field: "quantity", message: "Must be positive")
  }
}

public struct KiteHoldingsAuthorisationItem: Sendable {
  public var isin: String
  public var quantity: Int64
  public init(isin: String, quantity: Int64) {
    self.isin = isin
    self.quantity = quantity
  }
}

/// Initiation receipt only: the user must finish authorisation in their browser.
public struct KiteHoldingsAuthorisationReceipt: Decodable, Sendable, Equatable {
  public let requestID: String
  enum CodingKeys: String, CodingKey { case requestID = "request_id" }
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    requestID = try c.decode(String.self, forKey: .requestID)
    try portfolioText(requestID, field: "request_id")
  }
}

extension KiteClient {
  /// Empty items asks Kite to present the entire holding portfolio for authorisation.
  /// The app owns browser presentation, completion, and any subsequent sell order.
  public func authoriseHoldings(instruments: [KiteHoldingsAuthorisationItem] = []) async throws
    -> KiteHoldingsAuthorisationReceipt
  {
    var fields: [KiteParameter] = []
    for item in instruments {
      try portfolioText(item.isin, field: "isin")
      try portfolioQuantity(item.quantity)
      fields.append(.init("isin", item.isin))
      fields.append(.init("quantity", String(item.quantity)))
    }
    return try await execute(
      KiteRequest(
        method: .post, path: "/portfolio/holdings/authorise",
        body: .form(fields), isTradingMutation: true), as: KiteHoldingsAuthorisationReceipt.self)
  }
}

public enum KiteHoldingsAuthorisationStatus: KiteStringValue {
  case success, error
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "success": self = .success
    case "error": self = .error
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .success: "success"
    case .error: "error"
    case .unknown(let value): value
    }
  }
}

/// A browser navigation description; this value never opens a browser or sends a request.
public struct KiteHoldingsAuthorisationFlow: Sendable {
  public let url: URL
  fileprivate init(apiKey: String, requestID: String) {
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    let key = apiKey.addingPercentEncoding(withAllowedCharacters: allowed)!
    let request = requestID.addingPercentEncoding(withAllowedCharacters: allowed)!
    url = URL(
      string: "https://kite.zerodha.com/connect/portfolio/authorise/holdings/\(key)/\(request)")!
  }
  /// A navigation hint, not independent proof of depository authorisation or order execution.
  /// Only this flow's HTTPS origin, key, request and exact finish path are recognised.
  public func completionStatus(for redirect: URL) -> KiteHoldingsAuthorisationStatus? {
    guard let c = URLComponents(url: redirect, resolvingAgainstBaseURL: false),
      c.scheme == url.scheme, c.host == url.host, c.port == nil,
      c.user == nil, c.password == nil, c.fragment == nil,
      c.path == url.path + "/finish"
    else { return nil }
    let statuses = (c.queryItems ?? []).filter { $0.name == "status" }
    guard statuses.count == 1, let value = statuses[0].value, !value.isEmpty else { return nil }
    return KiteHoldingsAuthorisationStatus(rawValue: value)
  }
}
extension KiteClient {
  /// Uses the official documented browser origin, independently of the REST base URL.
  /// Sandbox browser support is unverified. The caller decides whether to present this URL.
  public nonisolated func holdingsAuthorisationFlow(requestID: String) throws
    -> KiteHoldingsAuthorisationFlow
  {
    try portfolioText(requestID, field: "request_id")
    for (field, value) in [("apiKey", apiKey), ("request_id", requestID)] {
      guard value != ".", value != ".." else {
        throw KiteError.validation(
          field: field, message: "A browser path component cannot be a dot segment")
      }
    }
    return KiteHoldingsAuthorisationFlow(apiKey: apiKey, requestID: requestID)
  }
}
