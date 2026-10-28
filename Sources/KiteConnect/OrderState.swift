//
//  OrderState.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Common state payload for REST, WebSocket order updates and postbacks.
/// Status may be null in postbacks; modified is absent in their documented payload.
/// REST reads enforce both fields through KiteOrder. Event envelope metadata and checksum
/// validation belong to the streaming/postback adapters, not this state model.
public struct KiteOrderUpdate: Decodable, Sendable, Equatable {
    /// The opaque Kite order identifier used for history, trades, and reconciliation.
    public let orderID: String
    /// The reported order state; postbacks may omit it or supply null.
    public let status: KiteOrderStatus?
    /// The exchange-assigned order identifier, when reported by Kite.
    public let exchangeOrderID: String?
    /// The parent order identifier for a child leg, when reported.
    public let parentOrderID: String?
    /// The identifier of the user who placed the order.
    public let placedBy: String
    /// Whether Kite reports a modification to this order.
    public let modified: Bool?
    /// The exchange on which the instrument is identified.
    public let exchange: KiteExchange
    /// The trading symbol within the specified exchange.
    public let tradingSymbol: String
    /// The numeric instrument token supplied by Kite; tokens may be reused after expiry.
    public let instrumentToken: UInt32
    /// The order routing variety, such as regular, after-market, or cover.
    public let variety: KiteOrderVariety
    /// The reported buy or sell direction, retaining unfamiliar server values.
    public let transactionType: KiteTransactionType
    /// The pricing instruction, such as LIMIT, MARKET, or stop-loss.
    public let orderType: KiteOrderType
    /// The broker product used for the order or execution.
    public let product: KiteProduct
    /// The reported order lifetime instruction, retaining unfamiliar server values.
    public let validity: KiteOrderValidity
    /// The nonnegative order quantity reported by Kite, without recomputing it from fills.
    public let quantity: Int64
    /// The quantity disclosed to the market; supplied values must be nonnegative.
    public let disclosedQuantity: Int64
    /// The quantity already executed; cancellation does not reverse these fills.
    public let filledQuantity: Int64
    /// The quantity awaiting execution as reported by Kite.
    public let pendingQuantity: Int64
    /// The quantity cancelled without execution as reported by Kite.
    public let cancelledQuantity: Int64
    /// The order price as a decimal value, distinct from its execution price.
    public let price: Decimal
    /// The stop-loss trigger price, separate from the order limit price.
    public let triggerPrice: Decimal
    /// The average execution price reported by Kite, without local recalculation.
    public let averagePrice: Decimal
    /// The order timestamp supplied by Kite, interpreted with the configured trading timezone when offsetless.
    public let orderTimestamp: Date
    /// The exchange timestamp, when the response reports one.
    public let exchangeTimestamp: Date?
    /// The timestamp of the latest exchange update, when reported.
    public let exchangeUpdateTimestamp: Date?
    /// The human-readable status or rejection explanation supplied by Kite.
    public let statusMessage: String?
    /// The unmodified underlying status message supplied by Kite.
    public let statusMessageRaw: String?
    /// The optional market-protection value reported by Kite without recomputing protection.
    public let marketProtection: Decimal?
    /// Remaining unfilled quantity in order updates and postbacks; absent in REST examples.
    public let unfilledQuantity: Int64?
    /// The optional order time-to-live in minutes, validated as nonnegative in REST state.
    public let validityTTL: Int64?
    /// The auction session identifier reported by Kite, or nil when absent or null.
    public let auctionNumber: String?
    /// The application tag returned by Kite, when present; it is not an idempotency key.
    public let tag: String?
    /// The application tags preserved as supplied by the server or basket definition.
    public let tags: [String]?
    /// The server-supplied request identifier, when reported.
    public let guid: String?
    /// The account identifier associated with this order or execution attempt.
    public let accountID: String?
    /// The terminal identifier reported by Kite, when available.
    public let terminalID: String?
    /// The server metadata preserved without assuming a fixed JSON schema.
    public let meta: KiteOrderMetadata?
    /// Original text, retained for postback checksum verification before any date formatting.
    public let orderTimestampRaw: String
    enum CodingKeys: String, CodingKey {
        case validityTTL = "validity_ttl"
        case auctionNumber = "auction_number"
        case tag
        case tags
        case guid
        case accountID = "account_id"
        case terminalID = "terminal_id"
        case meta
        case orderID = "order_id"
        case status
        case exchangeOrderID = "exchange_order_id"
        case parentOrderID = "parent_order_id"
        case placedBy = "placed_by"
        case modified
        case exchange
        case tradingSymbol = "tradingsymbol"
        case instrumentToken = "instrument_token"
        case variety
        case transactionType = "transaction_type"
        case orderType = "order_type"
        case product
        case validity
        case quantity
        case disclosedQuantity = "disclosed_quantity"
        case filledQuantity = "filled_quantity"
        case pendingQuantity = "pending_quantity"
        case cancelledQuantity = "cancelled_quantity"
        case price
        case triggerPrice = "trigger_price"
        case averagePrice = "average_price"
        case orderTimestamp = "order_timestamp"
        case exchangeTimestamp = "exchange_timestamp"
        case exchangeUpdateTimestamp = "exchange_update_timestamp"
        case statusMessage = "status_message"
        case statusMessageRaw = "status_message_raw"
        case marketProtection = "market_protection"
        case unfilledQuantity = "unfilled_quantity"
    }

    /// Decodes shared order state while allowing notification-specific omissions of status and modified.
    ///
    /// - Parameter decoder: The decoder positioned at the response value, outside any Kite envelope.
    /// - Throws: A decoding error for missing or malformed required values. Optional
    ///   fields allow absence or null, but malformed present values fail.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderID = try container.decode(String.self, forKey: .orderID)
        guard !orderID.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .orderID, in: container,
                debugDescription: "Expected a nonempty order ID",
            )
        }
        status = try container.decodeIfPresent(KiteOrderStatus.self, forKey: .status)
        exchangeOrderID = try container.decodeIfPresent(String.self, forKey: .exchangeOrderID)
        parentOrderID = try container.decodeIfPresent(String.self, forKey: .parentOrderID)
        placedBy = try container.decode(String.self, forKey: .placedBy)
        modified = try container.decodeIfPresent(Bool.self, forKey: .modified)
        exchange = try container.decode(KiteExchange.self, forKey: .exchange)
        tradingSymbol = try container.decode(String.self, forKey: .tradingSymbol)
        instrumentToken = try decodeOrderInstrumentToken(container, forKey: .instrumentToken)
        variety = try container.decode(KiteOrderVariety.self, forKey: .variety)
        transactionType = try container.decode(KiteTransactionType.self, forKey: .transactionType)
        orderType = try container.decode(KiteOrderType.self, forKey: .orderType)
        product = try container.decode(KiteProduct.self, forKey: .product)
        validity = try container.decode(KiteOrderValidity.self, forKey: .validity)
        quantity = try container.decode(Int64.self, forKey: .quantity)
        disclosedQuantity = try container.decode(Int64.self, forKey: .disclosedQuantity)
        filledQuantity = try container.decode(Int64.self, forKey: .filledQuantity)
        pendingQuantity = try container.decode(Int64.self, forKey: .pendingQuantity)
        cancelledQuantity = try container.decode(Int64.self, forKey: .cancelledQuantity)
        price = try container.decode(Decimal.self, forKey: .price)
        triggerPrice = try container.decode(Decimal.self, forKey: .triggerPrice)
        averagePrice = try container.decode(Decimal.self, forKey: .averagePrice)
        orderTimestamp = try container.decode(Date.self, forKey: .orderTimestamp)
        exchangeTimestamp = try container.decodeIfPresent(Date.self, forKey: .exchangeTimestamp)
        exchangeUpdateTimestamp = try container.decodeIfPresent(
            Date.self, forKey: .exchangeUpdateTimestamp,
        )
        statusMessage = try container.decodeIfPresent(String.self, forKey: .statusMessage)
        statusMessageRaw = try container.decodeIfPresent(String.self, forKey: .statusMessageRaw)
        marketProtection = try container.decodeIfPresent(Decimal.self, forKey: .marketProtection)
        unfilledQuantity = try container.decodeIfPresent(Int64.self, forKey: .unfilledQuantity)
        validityTTL = try container.decodeIfPresent(Int64.self, forKey: .validityTTL)
        auctionNumber = try container.decodeIfPresent(String.self, forKey: .auctionNumber)
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        guid = try container.decodeIfPresent(String.self, forKey: .guid)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
        terminalID = try container.decodeIfPresent(String.self, forKey: .terminalID)
        meta = try container.decodeIfPresent(KiteOrderMetadata.self, forKey: .meta)
        guard
            [quantity, disclosedQuantity, filledQuantity, pendingQuantity, cancelledQuantity].allSatisfy({
                $0 >= 0
            }),
            validityTTL.map({ $0 >= 0 }) ?? true, unfilledQuantity.map({ $0 >= 0 }) ?? true
        else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected nonnegative order quantities and validity TTL",
                ),
            )
        }
        orderTimestampRaw = try container.decode(String.self, forKey: .orderTimestamp)
    }
}

/// The orders response tables say string while their JSON examples use numeric tokens.
func decodeOrderInstrumentToken<Key: CodingKey>(
    _ container: KeyedDecodingContainer<Key>, forKey key: Key,
) throws -> UInt32 {
    if let raw = try? container.decode(String.self, forKey: key) {
        guard !raw.isEmpty, raw.utf8.allSatisfy({ (48 ... 57).contains($0) }), let token = UInt32(raw)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: container,
                debugDescription: "Expected a uint32 instrument token",
            )
        }
        return token
    }
    return try container.decode(UInt32.self, forKey: key)
}
