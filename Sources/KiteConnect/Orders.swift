//
//  Orders.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

public extension KiteClient {
    /// Retrieves the current trading day's order book, including open and executed orders.
    ///
    /// - Returns: The server-ordered order records. Persist longer-lived history in your application.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func orders() async throws -> [KiteOrder] {
        try await orderRead(path: "/orders", as: [KiteOrder].self)
    }

    /// Retrieves the current trading day's state history for an externally supplied order ID.
    ///
    /// - Parameters:
    ///   - orderID: A nonempty opaque path component without whitespace, traversal, or URL delimiters.
    /// - Returns: The state records in server order. An empty history does not disprove an uncertain submission.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func orderHistory(orderID: String) async throws -> [KiteOrder] {
        try validateOrderID(orderID)
        return try await orderRead(path: "/orders/" + orderID, as: [KiteOrder].self)
    }

    /// Retrieves individual exchange executions for the current trading day.
    ///
    /// - Returns: The trade records, retaining separate partial fills for the same order.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func trades() async throws -> [KiteTrade] {
        try await orderRead(path: "/trades", as: [KiteTrade].self)
    }

    /// Retrieves individual executions associated with a supplied order ID.
    ///
    /// - Parameters:
    ///   - orderID: A nonempty opaque path component without whitespace, traversal, or URL delimiters.
    /// - Returns: The executions for the order. A cancelled order can have earlier fills.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func orderTrades(orderID: String) async throws -> [KiteTrade] {
        try validateOrderID(orderID)
        return try await orderRead(path: "/orders/" + orderID + "/trades", as: [KiteTrade].self)
    }

    private func validateOrderID(_ value: String) throws {
        guard !value.isEmpty, !value.contains(".."),
              !value.contains(where: { $0.isWhitespace || $0.isNewline || "/\\?#".contains($0) }),
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else {
            throw KiteError.validation(
                field: "orderID",
                message:
                "Expected a nonempty order ID path component without whitespace, traversal, or URL delimiters",
            )
        }
    }

    private func orderRead<Value: Decodable & Sendable>(path: String, as _: Value.Type)
        async throws -> Value
    {
        let response = try await response(for: KiteRequest(path: path))
        do {
            let result = try KiteTimestamp.decoder(timeZone: configuration.tradingTimeZone)
                .decode(OrderReadEnvelope<Value>.self, from: response.body)
            guard result.status == "success" else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Expected success envelope"),
                )
            }
            return result.data
        } catch {
            throw KiteError.decoding(
                statusCode: response.statusCode, message: "Malformed order response: \(error)",
            )
        }
    }
}

private struct OrderReadEnvelope<Value: Decodable>: Decodable {
    let status: String
    let data: Value
}
