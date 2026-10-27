import Foundation

/// Outgoing request options; incoming layouts are identified by packet length.
public enum KiteTickerMode: String, Sendable, CaseIterable {
  case ltp, quote, full
}

public struct KiteTickOHLC: Sendable, Equatable {
  public let open: Decimal
  public let high: Decimal
  public let low: Decimal
  public let close: Decimal
}

public struct KiteQuoteFields: Sendable, Equatable {
  public let lastTradedQuantity: UInt32
  public let averageTradedPrice: Decimal
  public let volumeTraded: UInt32
  public let totalBuyQuantity: UInt32
  public let totalSellQuantity: UInt32
  public let ohlc: KiteTickOHLC
}

/// Binary market data, including layouts arriving while a mode change is in flight.
public struct KiteMarketTick: Sendable, Equatable {
  public enum Details: Sendable, Equatable {
    case ltp
    case quote(KiteQuoteFields)
    case full(KiteFullFields)
    case indexQuote(KiteIndexFields)
    case indexFull(KiteIndexFields, exchangeTimestamp: Date)
  }
  public let instrumentToken: UInt32
  public let lastPrice: Decimal
  public let details: Details
}

public struct KiteDepthEntry: Sendable, Equatable {
  public let quantity: UInt32
  public let price: Decimal
  public let orders: UInt16
}

public struct KiteMarketDepth: Sendable, Equatable {
  /// Five bid levels, in server order. Zero/empty levels are preserved.
  public let buy: [KiteDepthEntry]
  /// Five offer levels, in server order.
  public let sell: [KiteDepthEntry]
}

public struct KiteFullFields: Sendable, Equatable {
  public let quote: KiteQuoteFields
  /// Wire timestamps are Unix seconds, independent of the trading time zone.
  public let lastTradeTime: Date
  public let openInterest: UInt32
  public let openInterestDayHigh: UInt32
  public let openInterestDayLow: UInt32
  public let exchangeTimestamp: Date
  public let depth: KiteMarketDepth
}

public struct KiteIndexFields: Sendable, Equatable {
  public let ohlc: KiteTickOHLC
  /// Signed wire price change in price units, not a calculated percentage.
  public let priceChange: Decimal
}
