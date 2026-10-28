import Foundation

/// Open server enums keep known cases convenient without rejecting new server values.
public protocol KiteStringValue: Codable, Hashable, Sendable {
  init(rawValue: String)
  var rawValue: String { get }
}
extension KiteStringValue {
  public init(from decoder: any Decoder) throws {
    self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
  }
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
public enum KiteProduct: KiteStringValue {
  case cnc, nrml, mis, bo, co
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "CNC": self = .cnc
    case "NRML": self = .nrml
    case "MIS": self = .mis
    case "BO": self = .bo
    case "CO": self = .co
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .cnc: "CNC"
    case .nrml: "NRML"
    case .mis: "MIS"
    case .bo: "BO"
    case .co: "CO"
    case .unknown(let value): value
    }
  }
}
public enum KiteOrderType: KiteStringValue {
  case market, limit, stopLoss, stopLossMarket
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "MARKET": self = .market
    case "LIMIT": self = .limit
    case "SL": self = .stopLoss
    case "SL-M": self = .stopLossMarket
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .market: "MARKET"
    case .limit: "LIMIT"
    case .stopLoss: "SL"
    case .stopLossMarket: "SL-M"
    case .unknown(let value): value
    }
  }
}
public enum KiteExchange: KiteStringValue {
  case nse, nfo, bse, bfo, cds, bcd, mcx, mf
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "NSE": self = .nse
    case "NFO": self = .nfo
    case "BSE": self = .bse
    case "BFO": self = .bfo
    case "CDS": self = .cds
    case "BCD": self = .bcd
    case "MCX": self = .mcx
    case "MF": self = .mf
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .nse: "NSE"
    case .nfo: "NFO"
    case .bse: "BSE"
    case .bfo: "BFO"
    case .cds: "CDS"
    case .bcd: "BCD"
    case .mcx: "MCX"
    case .mf: "MF"
    case .unknown(let value): value
    }
  }
}
