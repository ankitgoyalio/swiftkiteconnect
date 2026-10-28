//
//  Portfolio.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// Long-term equity holding; metadata absent from a response remains nil.
///
/// ## See Also
///
/// - <doc:Inspect-and-convert-portfolio>
public struct KiteHolding: Decodable, Sendable, Equatable {
    /// Exchange and trading symbol used together as the persistent instrument identity.
    public let identity: KiteInstrumentIdentity
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Exchange reported by Kite, preserving unfamiliar raw values.
    public let exchange: KiteExchange
    /// Numeric instrument token reported by Kite. Tokens can be reused after derivative expiry.
    public let instrumentToken: UInt32
    /// International securities identification number used for depository authorisation.
    public let isin: String
    /// Margin product associated with this holding, position, or calculation.
    public let product: KiteProduct
    /// Quantity reported by Kite, retained without rounding or recomputation.
    public let quantity: Int64
    /// Quantity awaiting settlement, as reported by Kite.
    public let t1Quantity: Int64
    /// Settled holding quantity reported by Kite.
    public let realisedQuantity: Int64
    /// Quantity authorised for depository debit, as reported by Kite.
    public let authorisedQuantity: Int64
    /// Holding quantity at the start of the trading day.
    public let openingQuantity: Int64
    /// Holding quantity pledged as collateral, as reported by Kite.
    public let collateralQuantity: Int64
    /// Quantity sold from the net holding quantity, as reported by Kite. Nil means the field was absent or null.
    public let usedQuantity: Int64?
    /// Short-delivery quantity when supplied by Kite. Nil means the field was absent or null.
    public let shortQuantity: Int64?
    /// Authorisation timestamp when supplied, using the configured timezone for offsetless text. Nil means the field was absent or null.
    public let authorisedDate: Date?
    /// Server-supplied authorisation metadata, retaining arbitrary JSON values. Nil means the field was absent or null.
    public let authorisation: [String: KiteOrderMutationJSONValue]?
    /// Raw collateral classification when supplied by Kite. Nil means the field was absent or null.
    public let collateralType: String?
    /// Whether Kite reports a discrepancy for this holding.
    public let discrepancy: Bool
    /// Price reported by Kite in decimal form, without recomputation.
    public let price: Decimal
    /// Average acquisition or execution price reported by Kite as a decimal.
    public let averagePrice: Decimal
    /// Latest price or net asset value reported by Kite, not a live-price subscription.
    public let lastPrice: Decimal
    /// Previous closing price reported by Kite for this instrument.
    public let closePrice: Decimal
    /// Profit or loss reported by Kite, without local recalculation.
    public let pnl: Decimal
    /// Absolute price change for the day reported by Kite.
    public let dayChange: Decimal
    /// Percentage price change for the day reported by Kite.
    public let dayChangePercentage: Decimal
    /// Margin trading facility details when supplied by Kite. Nil means the field was absent or null.
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

    /// Decodes the required fields and retains optional metadata when present.
    /// - Parameter decoder: Decoder configured with the SDK timestamp strategy for instant fields.
    /// - Throws: A decoding or validation error if a required value is missing or malformed.
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
            [String: KiteOrderMutationJSONValue].self, forKey: .authorisation,
        )
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

/// Margin trading facility quantities and financial amounts for a holding.
public struct KiteHoldingMTF: Decodable, Sendable, Equatable {
    /// Quantity reported by Kite, retained without rounding or recomputation.
    public let quantity: Int64
    /// Quantity sold from the net holding quantity, as reported by Kite.
    public let usedQuantity: Int64
    /// Average acquisition or execution price reported by Kite as a decimal.
    public let averagePrice: Decimal
    /// Monetary value reported by Kite without local recomputation.
    public let value: Decimal
    /// Initial margin amount reported by Kite for the financed holding.
    public let initialMargin: Decimal
    enum CodingKeys: String, CodingKey {
        case quantity
        case usedQuantity = "used_quantity"
        case averagePrice = "average_price"
        case value
        case initialMargin = "initial_margin"
    }
}

public extension KiteClient {
    /// Retrieves long-term equity holdings with optional authorisation and financing metadata.
    /// - Returns: Holdings reported by Kite, distinct from current-day positions.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func holdings() async throws -> [KiteHolding] {
        try await execute(KiteRequest(path: "/portfolio/holdings"), as: [KiteHolding].self)
    }
}

/// Auction rows use the holding wire layout, adding a required auction number.
public struct KiteAuctionHolding: Decodable, Sendable, Equatable {
    /// Holding fields decoded from the auction row itself.
    public let holding: KiteHolding
    /// Required nonblank auction identifier reported by Kite.
    public let auctionNumber: String
    enum CodingKeys: String, CodingKey { case auctionNumber = "auction_number" }
    /// Decodes the required fields and retains optional metadata when present.
    /// - Parameter decoder: Decoder configured with the SDK timestamp strategy for instant fields.
    /// - Throws: A decoding or validation error if a required value is missing or malformed.
    public init(from decoder: any Decoder) throws {
        holding = try KiteHolding(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        auctionNumber = try c.decode(String.self, forKey: .auctionNumber)
        guard !auctionNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .auctionNumber, in: c, debugDescription: "Empty auction number",
            )
        }
    }
}

public extension KiteClient {
    /// Retrieves holdings available in auctions using the holding layout and a required auction number.
    /// - Returns: Auction rows with their associated holding fields.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func auctionHoldings() async throws -> [KiteAuctionHolding] {
        try await execute(
            KiteRequest(path: "/portfolio/holdings/auctions"), as: [KiteAuctionHolding].self,
        )
    }
}

/// Position in one instrument and product. Signed quantity distinguishes long and short exposure.
public struct KitePosition: Decodable, Sendable, Equatable {
    /// Exchange and trading symbol used together as the persistent instrument identity.
    public let identity: KiteInstrumentIdentity
    /// Trading symbol reported by Kite within the associated exchange or fund catalogue.
    public let tradingSymbol: String
    /// Exchange reported by Kite, preserving unfamiliar raw values.
    public let exchange: KiteExchange
    /// Numeric instrument token reported by Kite. Tokens can be reused after derivative expiry.
    public let instrumentToken: UInt32
    /// Margin product associated with this holding, position, or calculation.
    public let product: KiteProduct
    /// Signed net quantity. Positive values are long, negative values are short, and zero is flat.
    public let quantity: Int64
    /// Position quantity carried from the previous trading day.
    public let overnightQuantity: Int64
    /// Contract multiplier reported by Kite for position valuation.
    public let multiplier: Int64
    /// Cumulative bought quantity reported by Kite.
    public let buyQuantity: Int64
    /// Cumulative sold quantity reported by Kite.
    public let sellQuantity: Int64
    /// Quantity bought during the current trading day.
    public let dayBuyQuantity: Int64
    /// Quantity sold during the current trading day.
    public let daySellQuantity: Int64
    /// Average acquisition or execution price reported by Kite as a decimal.
    public let averagePrice: Decimal
    /// Previous closing price reported by Kite for this instrument.
    public let closePrice: Decimal
    /// Latest price or net asset value reported by Kite, not a live-price subscription.
    public let lastPrice: Decimal
    /// Monetary value reported by Kite without local recomputation.
    public let value: Decimal
    /// Profit or loss reported by Kite, without local recalculation.
    public let pnl: Decimal

    /// Profit or loss valued at current market prices, as reported by Kite.
    public let m2m: Decimal
    /// Unrealised profit or loss reported by Kite as a decimal.
    public let unrealised: Decimal
    /// Realised profit or loss reported by Kite as a decimal.
    public let realised: Decimal
    /// Average buy price reported by Kite for the position.
    public let buyPrice: Decimal
    /// Cumulative buy value reported by Kite for the position.
    public let buyValue: Decimal
    /// Buy-side mark-to-market value reported by Kite.
    public let buyM2M: Decimal
    /// Average sell price reported by Kite for the position.
    public let sellPrice: Decimal
    /// Cumulative sell value reported by Kite for the position.
    public let sellValue: Decimal
    /// Sell-side mark-to-market value reported by Kite.
    public let sellM2M: Decimal
    /// Average buy price for the current trading day.
    public let dayBuyPrice: Decimal
    /// Total buy value for the current trading day.
    public let dayBuyValue: Decimal
    /// Average sell price for the current trading day.
    public let daySellPrice: Decimal
    /// Total sell value for the current trading day.
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

    /// Decodes the required fields and retains optional metadata when present.
    /// - Parameter decoder: Decoder configured with the SDK timestamp strategy for instant fields.
    /// - Throws: A decoding or validation error if a required value is missing or malformed.
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

/// Separate net and current-day position views. These arrays are not additive portfolios.
///
/// ## See Also
///
/// - <doc:Financial-values-and-portfolio-views>
public struct KitePositions: Decodable, Sendable, Equatable {
    /// Net position records across carried and current-day activity.
    public let net: [KitePosition]
    /// Position records for activity during the current trading day.
    public let day: [KitePosition]
}

public extension KiteClient {
    /// Retrieves net and current-day position views in one request.
    /// - Returns: Separate net and day arrays. Signed quantities retain long and short exposure.
    /// - Throws: Authentication, API, transport, cancellation, or decoding errors. Requests attempt once without automatic retry.
    func positions() async throws -> KitePositions {
        try await execute(KiteRequest(path: "/portfolio/positions"), as: KitePositions.self)
    }
}
