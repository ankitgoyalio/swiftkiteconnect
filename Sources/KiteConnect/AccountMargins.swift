/// A segment supported by the user margins API.
public enum MarginSegment: String, Sendable {
    case equity
    case commodity
}

/// The user's funds and margins across trading segments.
public struct AccountMargins: Decodable, Equatable, Sendable {
    public let equity: SegmentMargins
    public let commodity: SegmentMargins?
}

/// The available and utilised funds for a trading segment.
public struct SegmentMargins: Decodable, Equatable, Sendable {
    public let enabled: Bool
    public let net: Double
    public let available: Available
    public let utilised: Utilised

    public struct Available: Decodable, Equatable, Sendable {
        public let adhocMargin: Double
        public let cash: Double
        public let openingBalance: Double
        public let liveBalance: Double?
        public let collateral: Double
        public let intradayPayin: Double

        private enum CodingKeys: String, CodingKey {
            case adhocMargin = "adhoc_margin"
            case cash
            case openingBalance = "opening_balance"
            case liveBalance = "live_balance"
            case collateral
            case intradayPayin = "intraday_payin"
        }
    }

    public struct Utilised: Decodable, Equatable, Sendable {
        public let debits: Double
        public let exposure: Double
        public let m2mRealised: Double
        public let m2mUnrealised: Double
        public let optionPremium: Double
        public let payout: Double
        public let span: Double
        public let holdingSales: Double
        public let turnover: Double
        public let liquidCollateral: Double
        public let stockCollateral: Double
        public let delivery: Double

        private enum CodingKeys: String, CodingKey {
            case debits
            case exposure
            case m2mRealised = "m2m_realised"
            case m2mUnrealised = "m2m_unrealised"
            case optionPremium = "option_premium"
            case payout
            case span
            case holdingSales = "holding_sales"
            case turnover
            case liquidCollateral = "liquid_collateral"
            case stockCollateral = "stock_collateral"
            case delivery
        }
    }
}

extension KiteConnectClient {
    /// Retrieves funds and margins across the user's trading segments.
    public func margins() async throws -> AccountMargins {
        try await rest.send(.init(.get, path: ["user", "margins"]))
    }

    /// Retrieves funds and margins for one trading segment.
    public func margins(segment: MarginSegment) async throws -> SegmentMargins {
        try await rest.send(.init(.get, path: ["user", "margins", segment.rawValue]))
    }
}
