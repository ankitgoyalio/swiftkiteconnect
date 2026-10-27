import Foundation

/// Documented request segments. Unsupported strings cannot become a request route.
public enum KiteMarginSegment: String, Sendable, CaseIterable {
  case equity, commodity
}

/// Funds for both documented account segments. Disabled segments remain present.
public struct KiteAccountMargins: Decodable, Sendable, Equatable {
  public let equity: KiteSegmentMargins
  public let commodity: KiteSegmentMargins
}

/// Funds and margin utilisation for one account segment, as reported by Kite.
/// All documented fields are required; extra server fields are ignored.
public struct KiteSegmentMargins: Decodable, Sendable, Equatable {
  public let enabled: Bool
  /// Net cash balance available for trading; preserved as returned, without recomputation.
  public let net: Decimal
  public let available: Available
  public let utilised: Utilised

  public struct Available: Decodable, Sendable, Equatable {
    /// Raw cash balance, including intraday pay-in.
    public let cash: Decimal
    /// Balance at the start of the trading day.
    public let openingBalance: Decimal
    /// Current available balance.
    public let liveBalance: Decimal
    /// Amount deposited during the day.
    public let intradayPayin: Decimal
    /// Additional margin provided by the broker.
    public let adhocMargin: Decimal
    /// Margin derived from pledged stocks.
    public let collateral: Decimal
    enum CodingKeys: String, CodingKey {
      case cash, collateral
      case openingBalance = "opening_balance"
      case liveBalance = "live_balance"
      case intradayPayin = "intraday_payin"
      case adhocMargin = "adhoc_margin"
    }
  }

  public struct Utilised: Decodable, Sendable, Equatable {
    /// Unbooked intraday profit/loss.
    public let m2mUnrealised: Decimal
    /// Booked intraday profit/loss.
    public let m2mRealised: Decimal
    /// Total utilised margins reported by Kite.
    public let debits: Decimal
    /// SPAN margin blocked for open futures and options positions.
    public let span: Decimal
    /// Premium received by shorting options.
    public let optionPremium: Decimal
    /// Value of holdings sold during the day.
    public let holdingSales: Decimal
    /// Exposure margin blocked for open futures and options positions.
    public let exposure: Decimal
    /// Margin utilised against pledged liquid ETFs and mutual funds.
    public let liquidCollateral: Decimal
    /// Margin blocked for sales from demat or T1 holdings.
    public let delivery: Decimal
    /// Margin utilised against pledged stocks and ETFs.
    public let stockCollateral: Decimal
    /// Utilised portion of the maximum turnover limit, applicable to certain clients.
    public let turnover: Decimal
    /// Funds withdrawn to the bank during the day.
    public let payout: Decimal
    enum CodingKeys: String, CodingKey {
      case debits, span, exposure, delivery, turnover, payout
      case m2mUnrealised = "m2m_unrealised"
      case m2mRealised = "m2m_realised"
      case optionPremium = "option_premium"
      case holdingSales = "holding_sales"
      case liquidCollateral = "liquid_collateral"
      case stockCollateral = "stock_collateral"
    }
  }
}

extension KiteClient {
  /// Retrieve funds for one documented segment with one authenticated request.
  public func margins(segment: KiteMarginSegment) async throws -> KiteSegmentMargins {
    try await execute(
      KiteRequest(path: "/user/margins/" + segment.rawValue), as: KiteSegmentMargins.self)
  }

  /// Retrieve funds for equity and commodity with one authenticated request.
  public func margins() async throws -> KiteAccountMargins {
    try await execute(KiteRequest(path: "/user/margins"), as: KiteAccountMargins.self)
  }
}
