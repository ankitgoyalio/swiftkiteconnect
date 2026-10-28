//
//  MutualFundPlansAndHoldings.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Systematic investment plan record, including indefinite-count sentinels and optional step-up data.
///
/// ## See Also
///
/// - <doc:Read-mutual-fund-information>
public struct KiteMutualFundSIP: Decodable, Sendable, Equatable {
    /// Identifier of the systematic investment plan reported by Kite.
    public let sipID: String
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Display name of the mutual-fund scheme reported by Kite.
    public let fund: String
    /// Dividend treatment reported by Kite, preserving unfamiliar values.
    public let dividendType: KiteMutualFundDividendType
    /// Buy or sell direction, preserving unfamiliar response values.
    public let transactionType: KiteTransactionType
    /// Plan lifecycle status reported by Kite, preserving unfamiliar values.
    public let status: KiteMutualFundSIPStatus
    /// Plan creation timestamp, using the configured trading timezone when offsetless.
    public let created: Date
    /// Instalment frequency reported by Kite, preserving unfamiliar values.
    public let frequency: KiteMutualFundFrequency
    /// Calendar date scheduled for the next instalment.
    public let nextInstalment: KiteDateOnly
    /// Monetary amount of each instalment, retained as a decimal.
    public let instalmentAmount: Decimal
    /// Planned instalment count. The documented -1 sentinel means an indefinite plan.
    public let instalments: Int64
    /// Timestamp of the last instalment when supplied by Kite. Nil means the field was absent or null.
    public let lastInstalment: Date?
    /// Remaining instalment count, including the documented -1 sentinel for an indefinite plan.
    public let pendingInstalments: Int64
    /// Calendar day for monthly instalments. Other frequencies use the documented zero sentinel.
    public let instalmentDay: Int
    /// Number of completed instalments reported by Kite.
    public let completedInstalments: Int64
    /// Application tag returned by Kite when present. Nil means the field was absent or null.
    public let tag: String?
    /// SIP registration number when supplied by Kite. Nil means the field was absent or null.
    public let registrationNumber: String?
    /// Trigger price for the request or plan, retained as a decimal. Nil means the field was absent or null.
    public let triggerPrice: Decimal?
    /// Server-supplied step-up amounts keyed by their original field names. Nil means the field was absent or null.
    public let stepUp: [String: Decimal]?
    /// SIP variety when supplied by Kite, preserving unfamiliar values. Nil means the field was absent or null.
    public let sipType: KiteMutualFundVariety?
    enum CodingKeys: String, CodingKey {
        case sipID = "sip_id"
        case tradingSymbol = "tradingsymbol"
        case fund
        case dividendType = "dividend_type"
        case transactionType = "transaction_type"
        case status
        case created
        case frequency
        case nextInstalment = "next_instalment"
        case instalmentAmount = "instalment_amount"
        case instalments
        case lastInstalment = "last_instalment"
        case pendingInstalments = "pending_instalments"
        case instalmentDay = "instalment_day"
        case completedInstalments = "completed_instalments"
        case tag
        case registrationNumber = "sip_reg_num"
        case triggerPrice = "trigger_price"
        case stepUp = "step_up"
        case sipType = "sip_type"
    }

    /// Decodes the required fields and retains optional metadata when present.
    /// - Parameter decoder: Decoder configured with the SDK timestamp strategy for instant fields.
    /// - Throws: A decoding or validation error if a required value is missing or malformed.
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
        nextInstalment = try KiteDateOnly(c.decode(String.self, forKey: .nextInstalment))
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

/// Scheme dividend treatment. Unfamiliar values remain available through the raw string.
public enum KiteMutualFundDividendType: KiteStringValue {
    /// Growth scheme with income reflected in its net asset value.
    case growth
    /// Dividend payout classification reported by Kite.
    case payout
    /// Income distribution and capital withdrawal classification reported by Kite.
    case idcw
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "growth": self = .growth
        case "payout": self = .payout
        case "idcw": self = .idcw
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .growth: "growth"
        case .payout: "payout"
        case .idcw: "idcw"
        case let .unknown(value): value
        }
    }
}

/// SIP instalment frequency, preserving unfamiliar server strings.
public enum KiteMutualFundFrequency: KiteStringValue {
    /// Instalment scheduled at a monthly frequency.
    case monthly
    /// Instalment scheduled at a weekly frequency.
    case weekly
    /// Instalment scheduled at a quarterly frequency.
    case quarterly
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "monthly": self = .monthly
        case "weekly": self = .weekly
        case "quarterly": self = .quarterly
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .monthly: "monthly"
        case .weekly: "weekly"
        case .quarterly: "quarterly"
        case let .unknown(value): value
        }
    }
}

/// SIP lifecycle status, preserving unfamiliar server strings.
public enum KiteMutualFundSIPStatus: KiteStringValue {
    /// Systematic investment plan currently marked active by Kite.
    case active
    /// Systematic investment plan currently marked paused by Kite.
    case paused
    /// Systematic investment plan currently marked cancelled by Kite.
    case cancelled
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "ACTIVE": self = .active
        case "PAUSED": self = .paused
        case "CANCELLED": self = .cancelled
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .active: "ACTIVE"
        case .paused: "PAUSED"
        case .cancelled: "CANCELLED"
        case let .unknown(value): value
        }
    }
}

public extension KiteClient {
    /// Retrieves active and paused systematic investment plans.
    /// The documented success envelope may omit status. No individual-SIP route is exposed.
    /// - Returns: Plans retaining -1 indefinite-count sentinels and optional step-up fields.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func mutualFundSIPs() async throws -> [KiteMutualFundSIP] {
        let response = try await response(for: KiteRequest(path: "/mf/sips"))
        do {
            let result = try KiteTimestamp.decoder(timeZone: configuration.tradingTimeZone)
                .decode(MutualFundSIPEnvelope.self, from: response.body)
            guard result.status == nil || result.status == "success" else {
                throw KiteError.decoding(
                    statusCode: response.statusCode, message: "Expected success envelope",
                )
            }
            return result.data
        } catch {
            throw KiteError.decoding(
                statusCode: response.statusCode, message: "Malformed SIP response: \(error)",
            )
        }
    }
}

/// The documented SIP example omits status, unlike the other MF examples.
private struct MutualFundSIPEnvelope: Decodable {
    let status: String?
    let data: [KiteMutualFundSIP]
}

/// Allotted mutual-fund units in the user's demat account, with fractional quantities and optional folio metadata.
///
/// ## See Also
///
/// - <doc:Financial-values-and-portfolio-views>
public struct KiteMutualFundHolding: Decodable, Sendable, Equatable {
    /// Folio number when supplied by Kite. An absent value remains nil.
    public let folio: String?
    /// Display name of the mutual-fund scheme reported by Kite.
    public let fund: String
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Average acquisition or execution price reported by Kite as a decimal.
    public let averagePrice: Decimal
    /// Latest price or net asset value reported by Kite, not a live-price subscription.
    public let lastPrice: Decimal
    /// Profit or loss reported by Kite, without local recalculation.
    public let pnl: Decimal
    /// Calendar date of the reported price or net asset value. Nil means the field was absent or null.
    public let lastPriceDate: KiteDateOnly?
    /// Quantity reported by Kite, retained without rounding or recomputation.
    public let quantity: Decimal
    /// Pledged fractional fund units when supplied by Kite. Nil means the field was absent or null.
    public let pledgedQuantity: Decimal?
    enum CodingKeys: String, CodingKey {
        case folio
        case fund
        case tradingSymbol = "tradingsymbol"
        case averagePrice = "average_price"
        case lastPrice = "last_price"
        case pnl
        case lastPriceDate = "last_price_date"
        case quantity
        case pledgedQuantity = "pledged_quantity"
    }

    /// Decodes the required fields and retains optional metadata when present.
    /// - Parameter decoder: Decoder configured with the SDK timestamp strategy for instant fields.
    /// - Throws: A decoding or validation error if a required value is missing or malformed.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        folio = try c.decodeIfPresent(String.self, forKey: .folio)
        fund = try c.decode(String.self, forKey: .fund)
        tradingSymbol = try c.decode(String.self, forKey: .tradingSymbol)
        averagePrice = try c.decode(Decimal.self, forKey: .averagePrice)
        lastPrice = try c.decode(Decimal.self, forKey: .lastPrice)
        pnl = try c.decode(Decimal.self, forKey: .pnl)
        lastPriceDate = try (c.decodeIfPresent(String.self, forKey: .lastPriceDate)).flatMap {
            $0.isEmpty ? nil : try KiteDateOnly($0)
        }
        quantity = try c.decode(Decimal.self, forKey: .quantity)
        pledgedQuantity = try c.decodeIfPresent(Decimal.self, forKey: .pledgedQuantity)
    }
}

public extension KiteClient {
    /// Retrieves allotted mutual-fund units in the user's demat account.
    /// - Returns: Fractional holdings with date-only NAV dates and optional folio and pledge data.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func mutualFundHoldings() async throws -> [KiteMutualFundHolding] {
        try await execute(KiteRequest(path: "/mf/holdings"), as: [KiteMutualFundHolding].self)
    }
}
