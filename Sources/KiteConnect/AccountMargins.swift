//
//  AccountMargins.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// Documented request segments. Unsupported strings cannot become a request route.
public enum KiteMarginSegment: String, Sendable, CaseIterable {
    /// Equity segment or scheme classification reported by Kite.
    case equity
    /// Commodity account segment for funds and utilisation.
    case commodity
}

/// Funds for both documented account segments. Disabled segments remain present.
///
/// ## See Also
///
/// - <doc:Inspect-account-margins>
public struct KiteAccountMargins: Decodable, Sendable, Equatable {
    /// Funds and utilisation for the equity account segment, including its enabled state.
    public let equity: KiteSegmentMargins
    /// Funds and utilisation for the commodity account segment, including its enabled state.
    public let commodity: KiteSegmentMargins
}

/// Funds and margin utilisation for one account segment, as reported by Kite.
/// All documented fields are required; extra server fields are ignored.
///
/// ## See Also
///
/// - <doc:Financial-values-and-portfolio-views>
public struct KiteSegmentMargins: Decodable, Sendable, Equatable {
    /// Whether Kite enables trading in this account segment.
    public let enabled: Bool
    /// Net cash balance available for trading; preserved as returned, without recomputation.
    public let net: Decimal
    /// Available-funds components reported by Kite for this segment.
    public let available: Available
    /// Blocked and utilised funds reported by Kite for this segment.
    public let utilised: Utilised

    /// Available-funds components of a segment, all required in the response.
    public struct Available: Decodable, Sendable, Equatable {
        /// Raw cash balance, including intraday pay-in.
        public let cash: Decimal
        /// Balance at the start of the trading day.
        public let openingBalance: Decimal
        /// Current available balance reported by Kite for this segment.
        public let liveBalance: Decimal
        /// Amount deposited during the trading day, as reported by Kite.
        public let intradayPayin: Decimal
        /// Additional margin provided by the broker.
        public let adhocMargin: Decimal
        /// Margin derived from pledged stocks, as reported by Kite.
        public let collateral: Decimal
        enum CodingKeys: String, CodingKey {
            case cash, collateral
            case openingBalance = "opening_balance"
            case liveBalance = "live_balance"
            case intradayPayin = "intraday_payin"
            case adhocMargin = "adhoc_margin"
        }
    }

    /// Utilised-funds components of a segment, all required in the response.
    public struct Utilised: Decodable, Sendable, Equatable {
        /// Unbooked intraday profit or loss reported by Kite.
        public let m2mUnrealised: Decimal
        /// Booked intraday profit or loss reported by Kite.
        public let m2mRealised: Decimal
        /// Total utilised margins reported by Kite.
        public let debits: Decimal
        /// SPAN margin blocked for open futures and options positions.
        public let span: Decimal
        /// Premium received by shorting options, as reported by Kite.
        public let optionPremium: Decimal
        /// Value of holdings sold during the trading day, as reported by Kite.
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

public extension KiteClient {
    /// Retrieves account funds and utilisation for one segment with a single authenticated request.
    /// - Parameter segment: Equity or commodity account segment.
    /// - Returns: The server balance and enabled state, without local recomputation.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func margins(segment: KiteMarginSegment) async throws -> KiteSegmentMargins {
        try await execute(
            KiteRequest(path: "/user/margins/" + segment.rawValue), as: KiteSegmentMargins.self,
        )
    }

    /// Retrieves account funds for both equity and commodity, including disabled segments.
    /// - Returns: Both segment balances as reported by Kite.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func margins() async throws -> KiteAccountMargins {
        try await execute(KiteRequest(path: "/user/margins"), as: KiteAccountMargins.self)
    }
}
