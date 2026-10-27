import Foundation

public struct KiteLTPSnapshot: Decodable, Sendable, Equatable {
  public let instrumentToken: UInt32
  public let lastPrice: Decimal
  enum CodingKeys: String, CodingKey {
    case instrumentToken = "instrument_token"
    case lastPrice = "last_price"
  }
}

/// Opening, high, low and previous trading day's closing prices.
public struct KiteOHLC: Decodable, Sendable, Equatable {
  public let open: Decimal
  public let high: Decimal
  public let low: Decimal
  public let close: Decimal
}

public struct KiteOHLCSnapshot: Decodable, Sendable, Equatable {
  public let instrumentToken: UInt32
  public let lastPrice: Decimal
  public let ohlc: KiteOHLC
  enum CodingKeys: String, CodingKey {
    case instrumentToken = "instrument_token"
    case lastPrice = "last_price"
    case ohlc
  }
}

/// One price level on either side of the order book.
public struct KiteDepthLevel: Decodable, Sendable, Equatable {
  public let price: Decimal
  public let quantity: Int64
  public let orders: Int64
}

public struct KiteMarketDepth: Decodable, Sendable, Equatable {
  public let buy: [KiteDepthLevel]
  public let sell: [KiteDepthLevel]
}

public struct KiteQuoteSnapshot: Decodable, Sendable, Equatable {
  public let instrumentToken: UInt32
  public let timestamp: Date
  public let lastTradeTime: Date?
  public let lastPrice: Decimal
  public let lastQuantity: Int64
  public let buyQuantity: Int64
  public let sellQuantity: Int64
  public let volume: Int64
  public let averagePrice: Decimal
  public let oi: Decimal
  public let oiDayHigh: Decimal
  public let oiDayLow: Decimal
  /// An additional derivatives-only attribute listed separately from `oi` in the docs.
  public let openInterest: Decimal?
  public let netChange: Decimal
  public let lowerCircuitLimit: Decimal
  public let upperCircuitLimit: Decimal
  public let ohlc: KiteOHLC
  public let depth: KiteMarketDepth
  enum CodingKeys: String, CodingKey {
    case instrumentToken = "instrument_token"
    case timestamp
    case lastTradeTime = "last_trade_time"
    case lastPrice = "last_price"
    case lastQuantity = "last_quantity"
    case buyQuantity = "buy_quantity"
    case sellQuantity = "sell_quantity"
    case volume
    case averagePrice = "average_price"
    case oi
    case oiDayHigh = "oi_day_high"
    case oiDayLow = "oi_day_low"
    case openInterest = "open_interest"
    case netChange = "net_change"
    case lowerCircuitLimit = "lower_circuit_limit"
    case upperCircuitLimit = "upper_circuit_limit"
    case ohlc, depth
  }
}

extension KiteClient {
  /// Retrieve full snapshots, including market depth. Unavailable keys remain absent.
  public func quotes(instruments: [KiteInstrumentIdentity]) async throws
    -> [KiteInstrumentIdentity: KiteQuoteSnapshot]
  {
    try await snapshots(path: "/quote", instruments: instruments, as: KiteQuoteSnapshot.self)
  }

  /// Retrieve OHLC and LTP. Unavailable instruments are absent from the map.
  public func ohlc(instruments: [KiteInstrumentIdentity]) async throws
    -> [KiteInstrumentIdentity: KiteOHLCSnapshot]
  {
    try await snapshots(path: "/quote/ohlc", instruments: instruments, as: KiteOHLCSnapshot.self)
  }

  /// Retrieve LTP for supplied identities. Unavailable instruments are absent from the map.
  public func ltp(instruments: [KiteInstrumentIdentity]) async throws
    -> [KiteInstrumentIdentity: KiteLTPSnapshot]
  {
    try await snapshots(path: "/quote/ltp", instruments: instruments, as: KiteLTPSnapshot.self)
  }

  private func snapshots<Value: Decodable & Sendable>(
    path: String, instruments: [KiteInstrumentIdentity], as type: Value.Type
  ) async throws -> [KiteInstrumentIdentity: Value] {
    let limit = path == "/quote" ? 500 : 1000
    guard (1...limit).contains(instruments.count) else {
      throw KiteError.validation(field: "instruments", message: "Expected 1...\(limit) identities")
    }
    return try await execute(
      KiteRequest(path: path, query: instruments.map { KiteParameter("i", $0.description) }),
      as: KiteSnapshotMap<Value>.self
    ).values
  }
}

private struct KiteSnapshotMap<Value: Decodable & Sendable>: Decodable, Sendable {
  let values: [KiteInstrumentIdentity: Value]
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let wire = try container.decode([String: Value].self)
    var result: [KiteInstrumentIdentity: Value] = [:]
    for (key, value) in wire {
      let parts = key.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2,
        let identity = try? KiteInstrumentIdentity(
          exchange: KiteExchange(rawValue: String(parts[0])), tradingSymbol: String(parts[1]))
      else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "Invalid quote identity: \(key)")
      }
      result[identity] = value
    }
    values = result
  }
}
