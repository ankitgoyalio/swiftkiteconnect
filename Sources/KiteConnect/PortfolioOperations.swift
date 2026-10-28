//
//  PortfolioOperations.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Selects the day or overnight position for a margin-product conversion.
public enum KitePositionConversionType: String, Sendable {
    /// Position carried into the current trading day.
    case overnight
    /// Position activity during the current trading day.
    case day
}

/// Request to change a position product. Construction sends no request and does not validate eligibility.
///
/// ## See Also
///
/// - <doc:Inspect-and-convert-portfolio>
public struct KitePositionConversion: Sendable {
    /// Exchange and trading symbol for the request. No instrument token is required.
    public var instrument: KiteInstrumentIdentity
    /// Buy or sell direction, preserving unfamiliar response values.
    public var transactionType: KiteOrderMutationSide
    /// Whether the conversion applies to the day or overnight position.
    public var positionType: KitePositionConversionType
    /// Positive quantity for the request, validated when the request is submitted.
    public var quantity: Int64
    /// Existing margin product to convert, subject to server business rules.
    public var oldProduct: KiteProduct
    /// Requested margin product after conversion, subject to server approval.
    public var newProduct: KiteProduct
    /// Stores a product-conversion request. Server eligibility is checked only when submitted.
    ///
    /// - Parameters:
    ///   - instrument: Exchange and trading symbol of the position.
    ///   - transactionType: Side of the position to convert.
    ///   - positionType: Day or overnight position selection.
    ///   - quantity: Positive quantity to convert.
    ///   - oldProduct: Existing margin product.
    ///   - newProduct: Requested margin product.
    public init(
        instrument: KiteInstrumentIdentity, transactionType: KiteOrderMutationSide,
        positionType: KitePositionConversionType, quantity: Int64,
        oldProduct: KiteProduct, newProduct: KiteProduct,
    ) {
        self.instrument = instrument
        self.transactionType = transactionType
        self.positionType = positionType
        self.quantity = quantity
        self.oldProduct = oldProduct
        self.newProduct = newProduct
    }
}

public extension KiteClient {
    /// Changes a position's margin product once, without automatic retry or reconciliation.
    /// - Parameter conversion: Instrument, side, day or overnight selection, positive quantity, and old and new products.
    /// - Returns: The Boolean result supplied by Kite. This does not establish an exit or order fill.
    /// - Throws: `KiteError.validation` for invalid quantity or product text. Transport loss after submission may produce `KiteError.uncertainOutcome`. Cancellation remains recognizable.
    func convertPosition(_ conversion: KitePositionConversion) async throws -> Bool {
        try portfolioQuantity(conversion.quantity)
        try portfolioText(conversion.oldProduct.rawValue, field: "old_product")
        try portfolioText(conversion.newProduct.rawValue, field: "new_product")
        return try await execute(
            KiteRequest(
                method: .put, path: "/portfolio/positions",
                body: .form([
                    .init("tradingsymbol", conversion.instrument.tradingSymbol),
                    .init("exchange", conversion.instrument.exchange.rawValue),
                    .init("transaction_type", conversion.transactionType.rawValue),
                    .init("position_type", conversion.positionType.rawValue),
                    .init("quantity", String(conversion.quantity)),
                    .init("old_product", conversion.oldProduct.rawValue),
                    .init("new_product", conversion.newProduct.rawValue),
                ]), isTradingMutation: true,
            ), as: Bool.self,
        )
    }
}

private func portfolioText(_ value: String, field: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else {
        throw KiteError.validation(field: field, message: "Expected nonblank text without controls")
    }
}

private func portfolioQuantity(_ value: Int64) throws {
    guard value > 0 else {
        throw KiteError.validation(field: "quantity", message: "Must be positive")
    }
}

/// ISIN and positive quantity to include in a depository authorisation request.
public struct KiteHoldingsAuthorisationItem: Sendable {
    /// International securities identification number used for depository authorisation.
    public var isin: String
    /// Positive quantity for the request, validated when the request is submitted.
    public var quantity: Int64
    /// Stores an ISIN and quantity for a later authorisation request.
    ///
    /// - Parameters:
    ///   - isin: Nonblank ISIN without control characters.
    ///   - quantity: Positive quantity to authorise. Neither field is validated until submission.
    public init(isin: String, quantity: Int64) {
        self.isin = isin
        self.quantity = quantity
    }
}

/// Initiation receipt only: the user must finish authorisation in their browser.
public struct KiteHoldingsAuthorisationReceipt: Decodable, Sendable, Equatable {
    /// Nonblank initiation identifier used to construct the browser authorisation flow.
    public let requestID: String
    enum CodingKeys: String, CodingKey { case requestID = "request_id" }
    /// Decodes the required fields and retains optional metadata when present.
    /// - Parameter decoder: Decoder configured with the SDK timestamp strategy for instant fields.
    /// - Throws: A decoding or validation error if a required value is missing or malformed.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestID = try c.decode(String.self, forKey: .requestID)
        try portfolioText(requestID, field: "request_id")
    }
}

public extension KiteClient {
    /// Initiates depository authorisation without opening a browser or placing a sell order.
    /// - Parameter instruments: ISIN and positive quantity pairs. An empty array asks Kite to present the entire holding portfolio.
    /// - Returns: An initiation receipt. The user must complete the browser workflow.
    /// - Throws: `KiteError.validation` for blank ISINs, controls, or nonpositive quantities. Submission failures can have an uncertain mutation outcome. Cancellation remains recognizable.
    func authoriseHoldings(instruments: [KiteHoldingsAuthorisationItem] = []) async throws
        -> KiteHoldingsAuthorisationReceipt
    {
        var fields: [KiteParameter] = []
        for item in instruments {
            try portfolioText(item.isin, field: "isin")
            try portfolioQuantity(item.quantity)
            fields.append(.init("isin", item.isin))
            fields.append(.init("quantity", String(item.quantity)))
        }
        return try await execute(
            KiteRequest(
                method: .post, path: "/portfolio/holdings/authorise",
                body: .form(fields), isTradingMutation: true,
            ), as: KiteHoldingsAuthorisationReceipt.self,
        )
    }
}

/// Browser finish status. Even success is a navigation hint, not proof of a completed sell order.
public enum KiteHoldingsAuthorisationStatus: KiteStringValue {
    /// Browser reports success. Confirm account state before subsequent trading actions.
    case success
    /// Browser reports an error in the authorisation flow.
    case error
    /// Unfamiliar server value retained verbatim for forward compatibility.
    case unknown(String)
    /// Maps a server string to a known case or preserves it as an unknown value.
    /// - Parameter rawValue: Exact server string, with case preserved.
    public init(rawValue: String) {
        switch rawValue {
        case "success": self = .success
        case "error": self = .error
        default: self = .unknown(rawValue)
        }
    }

    /// Original wire string for this value, including unfamiliar server values.
    public var rawValue: String {
        switch self {
        case .success: "success"
        case .error: "error"
        case let .unknown(value): value
        }
    }
}

/// A browser navigation description; this value never opens a browser or sends a request.
///
/// ## See Also
///
/// - <doc:Authorise-holding-sales>
public struct KiteHoldingsAuthorisationFlow: Sendable {
    /// Official HTTPS authorisation URL for the application to present in its browser.
    public let url: URL
    fileprivate init(apiKey: String, requestID: String) {
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~",
        )
        let key = apiKey.addingPercentEncoding(withAllowedCharacters: allowed)!
        let request = requestID.addingPercentEncoding(withAllowedCharacters: allowed)!
        url = URL(
            string: "https://kite.zerodha.com/connect/portfolio/authorise/holdings/\(key)/\(request)",
        )!
    }

    /// Recognises only this flow's exact HTTPS origin, key, request, and finish path.
    /// - Parameter redirect: Browser navigation URL to inspect.
    /// - Returns: The single nonempty status value, preserving unfamiliar strings, or nil for an unrelated or malformed URL. Success is not proof of depository authorisation or execution.
    public func completionStatus(for redirect: URL) -> KiteHoldingsAuthorisationStatus? {
        guard let c = URLComponents(url: redirect, resolvingAgainstBaseURL: false),
              c.scheme == url.scheme, c.host == url.host, c.port == nil,
              c.user == nil, c.password == nil, c.fragment == nil,
              c.path == url.path + "/finish"
        else { return nil }
        let statuses = (c.queryItems ?? []).filter { $0.name == "status" }
        guard statuses.count == 1, let value = statuses[0].value, !value.isEmpty else { return nil }
        return KiteHoldingsAuthorisationStatus(rawValue: value)
    }
}

public extension KiteClient {
    /// Constructs a browser flow using the official origin independently of the REST base URL.
    /// Sandbox browser support is unverified. The caller owns browser presentation and PIN entry remains with the depository.
    /// - Parameter requestID: Nonblank initiation identifier without controls or dot path segments.
    /// - Returns: A navigation description. No browser opens and no request is sent.
    /// - Throws: `KiteError.validation` for invalid request text or a dot-segment API key.
    nonisolated func holdingsAuthorisationFlow(requestID: String) throws
        -> KiteHoldingsAuthorisationFlow
    {
        try portfolioText(requestID, field: "request_id")
        for (field, value) in [("apiKey", apiKey), ("request_id", requestID)] {
            guard value != ".", value != ".." else {
                throw KiteError.validation(
                    field: field, message: "A browser path component cannot be a dot segment",
                )
            }
        }
        return KiteHoldingsAuthorisationFlow(apiKey: apiKey, requestID: requestID)
    }
}
