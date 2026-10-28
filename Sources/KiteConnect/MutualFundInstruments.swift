//
//  MutualFundInstruments.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// A mutual fund catalogue entry, independent of equity instrument tokens.
///
/// ## See Also
///
/// - <doc:Read-mutual-fund-information>
public struct KiteMutualFundInstrument: Sendable, Equatable {
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Name of the asset management company reported in the fund catalogue.
    public let amc: String
    /// Display name of the mutual-fund scheme in the catalogue.
    public let name: String
    /// Whether the catalogue currently permits purchases in this scheme.
    public let purchaseAllowed: Bool
    /// Whether the catalogue currently permits redemptions in this scheme.
    public let redemptionAllowed: Bool
    /// Minimum monetary amount for an initial purchase reported by Kite.
    public let minimumPurchaseAmount: Decimal
    /// Permitted increment for purchase amounts reported by Kite.
    public let purchaseAmountMultiplier: Decimal
    /// Minimum monetary amount for an additional purchase reported by Kite.
    public let minimumAdditionalPurchaseAmount: Decimal
    /// Minimum fractional unit quantity for redemption reported by Kite.
    public let minimumRedemptionQuantity: Decimal
    /// Permitted increment in fractional units for redemptions.
    public let redemptionQuantityMultiplier: Decimal
    /// Dividend treatment reported by Kite, preserving unfamiliar values.
    public let dividendType: KiteMutualFundDividendType
    /// Scheme classification reported by Kite, preserving unfamiliar values.
    public let schemeType: KiteMutualFundSchemeType
    /// Direct or regular plan classification reported by Kite.
    public let plan: KiteMutualFundPlan
    /// Raw settlement classification reported by Kite, without restricting future values.
    public let settlementType: String
    /// Latest price or net asset value reported by Kite, not a live-price subscription.
    public let lastPrice: Decimal
    /// Calendar date of the reported price or net asset value.
    public let lastPriceDate: KiteDateOnly
}

/// Mutual-fund scheme classification, preserving unfamiliar server strings.
public enum KiteMutualFundSchemeType: KiteStringValue {
    /// Equity segment or scheme classification reported by Kite.
    case equity
    /// Debt mutual-fund scheme classification reported by Kite.
    case debt
    /// Equity-linked savings scheme classification reported by Kite.
    case elss
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "equity": self = .equity
        case "debt": self = .debt
        case "elss": self = .elss
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .equity: "equity"
        case .debt: "debt"
        case .elss: "elss"
        case let .unknown(value): value
        }
    }
}

/// Direct or regular mutual-fund plan, preserving unfamiliar server strings.
public enum KiteMutualFundPlan: KiteStringValue {
    /// Direct mutual-fund plan classification reported by Kite.
    case direct
    /// Regular order or fund plan classification reported by Kite.
    case regular
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "direct": self = .direct
        case "regular": self = .regular
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .direct: "direct"
        case .regular: "regular"
        case let .unknown(value): value
        }
    }
}

public extension KiteClient {
    /// Downloads the authenticated mutual-fund CSV catalogue using configured API routing.
    /// The sandbox route includes `/oms`. Transports supply decompressed bytes. URLSession handles gzip content encoding.
    /// - Returns: Catalogue rows with decimal amounts, fractional quantity limits, and date-only NAV dates.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func mutualFundInstruments() async throws -> [KiteMutualFundInstrument] {
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
            lastPriceDate: KiteDateOnly(row.value("last_price_date")),
        )
    }
}
