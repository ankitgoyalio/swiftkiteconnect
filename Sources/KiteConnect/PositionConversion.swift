import Foundation

/// The instrument, quantity and products for a position conversion.
public struct PositionConversion: Equatable, Sendable {
    public enum TransactionType: String, Sendable {
        case buy = "BUY"
        case sell = "SELL"
    }

    public enum PositionType: String, Sendable {
        case day
        case overnight
    }

    public let tradingSymbol: String
    public let exchange: String
    public let transactionType: TransactionType
    public let positionType: PositionType
    public let quantity: Int64
    public let oldProduct: String
    public let newProduct: String

    public init(
        tradingSymbol: String,
        exchange: String,
        transactionType: TransactionType,
        positionType: PositionType,
        quantity: Int64,
        oldProduct: String,
        newProduct: String
    ) {
        self.tradingSymbol = tradingSymbol
        self.exchange = exchange
        self.transactionType = transactionType
        self.positionType = positionType
        self.quantity = quantity
        self.oldProduct = oldProduct
        self.newProduct = newProduct
    }

    public init(
        position: Position,
        transactionType: TransactionType,
        positionType: PositionType,
        quantity: Int64,
        newProduct: String
    ) {
        self.init(
            tradingSymbol: position.tradingSymbol,
            exchange: position.exchange,
            transactionType: transactionType,
            positionType: positionType,
            quantity: quantity,
            oldProduct: position.product,
            newProduct: newProduct
        )
    }
}

extension KiteConnectClient {
    /// Converts the margin product of an open position and returns Kite's boolean result.
    public func convertPosition(_ conversion: PositionConversion) async throws -> Bool {
        let form = [
            URLQueryItem(name: "tradingsymbol", value: conversion.tradingSymbol),
            URLQueryItem(name: "exchange", value: conversion.exchange),
            URLQueryItem(name: "transaction_type", value: conversion.transactionType.rawValue),
            URLQueryItem(name: "position_type", value: conversion.positionType.rawValue),
            URLQueryItem(name: "quantity", value: String(conversion.quantity)),
            URLQueryItem(name: "old_product", value: conversion.oldProduct),
            URLQueryItem(name: "new_product", value: conversion.newProduct),
        ]
        return try await rest.send(.init(.put, path: ["portfolio", "positions"], body: .form(form)))
    }
}
