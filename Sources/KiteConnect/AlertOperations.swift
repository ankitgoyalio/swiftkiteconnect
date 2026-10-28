//
//  AlertOperations.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

public extension KiteClient {
    /// Retrieves one simple or order-triggering alert definition.
    ///
    /// - Parameters:
    ///   - uuid: A nonempty identifier containing only ASCII letters, digits, hyphens, or underscores.
    /// - Returns: The stored alert, with its basket when supplied by Kite.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func alert(uuid: String) async throws -> KiteAlert {
        try alertIdentifier(uuid)
        return try await execute(KiteRequest(path: "/alerts/\(uuid)"), as: KiteAlert.self)
    }
}

public extension KiteClient {
    /// Retrieves alerts with optional server-side status and page filters.
    ///
    /// - Parameters:
    ///   - status: An optional lifecycle filter. Omission leaves server defaults in effect.
    ///   - page: An optional positive page number.
    ///   - pageSize: An optional positive number of records per page.
    /// - Returns: The selected page of alerts. No automatic pagination is performed.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func alerts(status: KiteAlertStatus? = nil, page: Int? = nil, pageSize: Int? = nil)
        async throws -> [KiteAlert]
    {
        if let status {
            try alertText(status.rawValue, field: "status")
        }
        if let page, page <= 0 {
            throw KiteError.validation(field: "page", message: "Must be positive")
        }
        if let pageSize, pageSize <= 0 {
            throw KiteError.validation(field: "page_size", message: "Must be positive")
        }
        var query: [KiteParameter] = []
        if let status {
            query.append(.init("status", status.rawValue))
        }
        if let page {
            query.append(.init("page", String(page)))
        }
        if let pageSize {
            query.append(.init("page_size", String(pageSize)))
        }
        return try await execute(KiteRequest(path: "/alerts", query: query), as: [KiteAlert].self)
    }
}

/// Instrument/attribute operand shared by simple and ATO requests.
/// Attributes are server-owned strings; the docs give LastTradedPrice as an example.
public struct KiteAlertInstrument: Sendable, Equatable {
    /// The exchange on which the instrument is identified.
    public var exchange: KiteExchange
    /// The trading symbol within the specified exchange.
    public var tradingSymbol: String
    /// The server-owned attribute name, such as LastTradedPrice.
    public var attribute: String
    /// Creates an instrument attribute operand. Nonempty exchange, symbol, and attribute are checked on submission.
    ///
    /// - Parameters:
    ///   - exchange: The exchange identifying the instrument.
    ///   - tradingSymbol: The trading symbol within that exchange.
    ///   - attribute: A nonempty server-owned attribute, such as LastTradedPrice.
    public init(exchange: KiteExchange, tradingSymbol: String, attribute: String) {
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
        self.attribute = attribute
    }
}

/// A constant or instrument attribute used as the right-hand side of an alert comparison.
public enum KiteAlertOperand: Sendable, Equatable {
    /// A decimal constant used as the right-hand comparison operand.
    case constant(Decimal)
    /// An instrument attribute used as the right-hand comparison operand.
    case instrument(KiteAlertInstrument)
}

/// Shared comparison structure; does not own alert lifecycle or order basket details.
public struct KiteAlertCondition: Sendable, Equatable {
    /// The instrument attribute on the left side of the comparison.
    public var lhs: KiteAlertInstrument
    /// The comparison operator applied to the left and right operands.
    public var comparison: KiteAlertOperator
    /// The constant or instrument attribute on the right side of the comparison.
    public var rhs: KiteAlertOperand
    /// Creates a comparison of an instrument attribute against a constant or another instrument attribute.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand instrument attribute.
    ///   - comparison: The comparison operator sent to Kite.
    ///   - rhs: A finite decimal constant or another instrument attribute.
    public init(lhs: KiteAlertInstrument, comparison: KiteAlertOperator, rhs: KiteAlertOperand) {
        self.lhs = lhs
        self.comparison = comparison
        self.rhs = rhs
    }

    /// Module seam for adding ATO form parameters without duplicating comparison encoding.
    func parameters() throws -> [KiteParameter] {
        try alertInstrument(lhs, prefix: "lhs")
        try alertText(comparison.rawValue, field: "operator")
        switch rhs {
        case let .constant(value):
            guard !value.isNaN else {
                throw KiteError.validation(field: "rhs_constant", message: "Must be finite")
            }
        case let .instrument(value): try alertInstrument(value, prefix: "rhs")
        }
        var fields: [KiteParameter] = [
            .init("lhs_exchange", lhs.exchange.rawValue), .init("lhs_tradingsymbol", lhs.tradingSymbol),
            .init("lhs_attribute", lhs.attribute), .init("operator", comparison.rawValue),
        ]
        switch rhs {
        case let .constant(value):
            fields += [.init("rhs_type", "constant"), .init("rhs_constant", value.description)]
        case let .instrument(value):
            fields += [
                .init("rhs_type", "instrument"), .init("rhs_exchange", value.exchange.rawValue),
                .init("rhs_tradingsymbol", value.tradingSymbol), .init("rhs_attribute", value.attribute),
            ]
        }
        return fields
    }
}

/// Complete simple-alert definition, used for creation and replacement-style modification.
public struct KiteSimpleAlertRequest: Sendable, Equatable {
    /// The application-supplied display name for this alert or basket.
    public var name: String
    /// The comparison or trigger condition associated with this definition.
    public var condition: KiteAlertCondition
    /// Creates a complete simple-alert definition for creation or replacement-style modification.
    ///
    /// - Parameters:
    ///   - name: The nonempty alert display name.
    ///   - condition: The complete comparison for this simple alert.
    public init(name: String, condition: KiteAlertCondition) {
        self.name = name
        self.condition = condition
    }
}

public extension KiteClient {
    /// Creates an alert once from its complete definition. See <doc:Manage-alerts>.
    ///
    /// - Parameters:
    ///   - alert: A complete simple comparison or order-triggering comparison and basket.
    /// - Returns: The server alert acknowledgement; an ATO receipt can omit its basket and does not prove execution.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func createAlert(_ alert: KiteSimpleAlertRequest) async throws -> KiteAlert {
        try alertText(alert.name, field: "name")
        return try await execute(
            KiteRequest(
                method: .post, path: "/alerts",
                body: .form(
                    [.init("name", alert.name), .init("type", "simple")] + (alert.condition.parameters()),
                ),
                isTradingMutation: true,
            ), as: KiteAlert.self,
        )
    }

    /// Replaces an alert definition once. Fetch current state before constructing the complete desired definition.
    ///
    /// - Parameters:
    ///   - uuid: A nonempty safe alert identifier.
    ///   - alert: The complete simple or order-triggering replacement definition.
    /// - Returns: The updated server alert record, not a confirmation of basket order fills.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func modifyAlert(uuid: String, alert: KiteSimpleAlertRequest) async throws -> KiteAlert {
        try alertIdentifier(uuid)
        try alertText(alert.name, field: "name")
        return try await execute(
            KiteRequest(
                method: .put, path: "/alerts/\(uuid)",
                body: .form(
                    [.init("name", alert.name), .init("type", "simple")] + (alert.condition.parameters()),
                ),
                isTradingMutation: true,
            ), as: KiteAlert.self,
        )
    }
}

public extension KiteClient {
    /// Soft-deletes one alert in a single request without automatic retries.
    ///
    /// - Parameters:
    ///   - uuid: A nonempty safe alert identifier.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func deleteAlert(uuid: String) async throws {
        try await deleteAlerts(uuids: [uuid])
    }

    /// Soft-deletes one or more alerts in a single request using repeated uuid query fields.
    ///
    /// - Parameters:
    ///   - uuids: A nonempty list of safe alert identifiers. Input order and repetitions are preserved.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func deleteAlerts(uuids: [String]) async throws {
        guard !uuids.isEmpty else {
            throw KiteError.validation(field: "uuid", message: "Expected at least one identifier")
        }
        for uuid in uuids {
            try alertIdentifier(uuid)
        }
        _ = try await execute(
            KiteRequest(
                method: .delete, path: "/alerts",
                query: uuids.map { .init("uuid", $0) }, isTradingMutation: true,
            ), as: KiteAlertDeletion.self,
        )
    }
}

private struct KiteAlertDeletion: Decodable, Sendable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard container.decodeNil() else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Expected null deletion data",
            )
        }
    }
}

public extension KiteClient {
    /// Retrieves alert lifecycle history with trigger-time market data and preserved order metadata.
    ///
    /// - Parameters:
    ///   - uuid: A nonempty safe alert identifier.
    /// - Returns: The history entries. Non-null undocumented order metadata is not proof of execution.
    /// - Throws: `CancellationError`, or `KiteError` for validation, transport, API rejection, or malformed response data.
    func alertHistory(uuid: String) async throws -> [KiteAlertHistoryEntry] {
        try alertIdentifier(uuid)
        return try await execute(
            KiteRequest(path: "/alerts/\(uuid)/history"), as: [KiteAlertHistoryEntry].self,
        )
    }
}

private func alertIdentifier(_ value: String) throws {
    let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_",
    )
    guard !value.isEmpty, value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
        throw KiteError.validation(field: "uuid", message: "Expected a nonempty safe identifier")
    }
}

func alertText(_ value: String, field: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else {
        throw KiteError.validation(
            field: field, message: "Expected nonempty text without control characters",
        )
    }
}

private func alertInstrument(_ value: KiteAlertInstrument, prefix: String) throws {
    try alertText(value.exchange.rawValue, field: "\(prefix)_exchange")
    try alertText(value.tradingSymbol, field: "\(prefix)_tradingsymbol")
    try alertText(value.attribute, field: "\(prefix)_attribute")
}

/// Complete ATO definition; creating the alert does not prove any order was executed.
public struct KiteATOAlertRequest: Sendable, Equatable {
    /// The application-supplied display name for this alert or basket.
    public var name: String
    /// The comparison or trigger condition associated with this definition.
    public var condition: KiteAlertCondition
    /// The order-triggering basket; its acknowledgement does not establish any fill.
    public var basket: KiteAlertBasket
    /// Creates a complete order-triggering alert definition with its comparison and basket.
    ///
    /// - Parameters:
    ///   - name: The nonempty alert display name.
    ///   - condition: The comparison that triggers the basket.
    ///   - basket: The complete basket definition with at least one order item.
    public init(name: String, condition: KiteAlertCondition, basket: KiteAlertBasket) {
        self.name = name
        self.condition = condition
        self.basket = basket
    }

    func parameters() throws -> [KiteParameter] {
        try alertText(name, field: "name")
        let conditionFields = try condition.parameters()
        try basket.validate()
        let basketJSON = try JSONEncoder().encode(basket)
        return [.init("name", name), .init("type", "ato")]
            + conditionFields + [.init("basket", String(decoding: basketJSON, as: UTF8.self))]
    }
}

public extension KiteClient {
    /// Creates an alert once from its complete definition. See <doc:Manage-alerts>.
    ///
    /// - Parameters:
    ///   - alert: A complete simple comparison or order-triggering comparison and basket.
    /// - Returns: The server alert acknowledgement; an ATO receipt can omit its basket and does not prove execution.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func createAlert(_ alert: KiteATOAlertRequest) async throws -> KiteAlert {
        try await execute(
            KiteRequest(
                method: .post, path: "/alerts", body: .form(alert.parameters()),
                isTradingMutation: true,
            ), as: KiteAlert.self,
        )
    }
}

public extension KiteClient {
    /// Replaces an alert definition once. Fetch current state before constructing the complete desired definition.
    ///
    /// - Parameters:
    ///   - uuid: A nonempty safe alert identifier.
    ///   - alert: The complete simple or order-triggering replacement definition.
    /// - Returns: The updated server alert record, not a confirmation of basket order fills.
    /// - Throws: `CancellationError`, or `KiteError` for validation, API rejection, or an uncertain mutation outcome. Cancellation after dispatch does not prove nonacceptance.
    func modifyAlert(uuid: String, alert: KiteATOAlertRequest) async throws -> KiteAlert {
        try alertIdentifier(uuid)
        return try await execute(
            KiteRequest(
                method: .put, path: "/alerts/\(uuid)", body: .form(alert.parameters()),
                isTradingMutation: true,
            ), as: KiteAlert.self,
        )
    }
}
