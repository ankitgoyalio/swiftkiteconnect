import Foundation

public enum AlertType: String, Decodable, Sendable {
    case simple
    case ato
}

public enum AlertStatus: String, Decodable, Sendable {
    case enabled
    case disabled
    case deleted
}

public enum AlertComparison: String, Decodable, Sendable {
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    case equal = "=="
}

/// An instrument and the market data attribute used to evaluate it.
public struct AlertInstrument: Sendable {
    public let exchange: String
    public let tradingSymbol: String
    public let attribute: String

    public init(exchange: String, tradingSymbol: String, attribute: String = "LastTradedPrice") {
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
        self.attribute = attribute
    }
}

/// The condition evaluated by either type of alert.
public struct AlertCondition: Sendable {
    public enum RightHandSide: Sendable {
        case constant(Double)
        case instrument(AlertInstrument)
    }

    public let name: String
    public let lhs: AlertInstrument
    public let comparison: AlertComparison
    public let rhs: RightHandSide

    public init(name: String, lhs: AlertInstrument, comparison: AlertComparison, rhs: RightHandSide) {
        self.name = name
        self.lhs = lhs
        self.comparison = comparison
        self.rhs = rhs
    }

    fileprivate func form(type: AlertType) -> [URLQueryItem] {
        var fields = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "lhs_exchange", value: lhs.exchange),
            URLQueryItem(name: "lhs_tradingsymbol", value: lhs.tradingSymbol),
            URLQueryItem(name: "lhs_attribute", value: lhs.attribute),
            URLQueryItem(name: "operator", value: comparison.rawValue),
        ]
        switch rhs {
        case .constant(let value):
            let decimal = String(value)
            fields += [
                .init(name: "rhs_type", value: "constant"),
                .init(name: "rhs_constant", value: decimal.hasSuffix(".0") ? String(decimal.dropLast(2)) : decimal),
            ]
        case .instrument(let instrument):
            fields += [
                .init(name: "rhs_type", value: "instrument"),
                .init(name: "rhs_exchange", value: instrument.exchange),
                .init(name: "rhs_tradingsymbol", value: instrument.tradingSymbol),
                .init(name: "rhs_attribute", value: instrument.attribute),
            ]
        }
        return fields
    }
}

/// Alert details returned by Kite. Timestamps use Kite's exchange-local format.
public struct Alert: Decodable, Equatable, Sendable {
    public enum RightHandSideType: String, Decodable, Sendable {
        case constant
        case instrument
    }

    public let type: AlertType
    public let userID: String
    public let uuid: String
    public let name: String
    public let status: AlertStatus
    public let disabledReason: String?
    public let lhsAttribute: String
    public let lhsExchange: String
    public let lhsTradingSymbol: String
    public let comparison: AlertComparison
    public let rhsType: RightHandSideType
    public let rhsAttribute: String?
    public let rhsExchange: String?
    public let rhsTradingSymbol: String?
    public let rhsConstant: Double
    public let alertCount: Int?
    public let createdAt: String
    public let updatedAt: String
    public let basket: AlertBasket?

    private enum CodingKeys: String, CodingKey {
        case type, uuid, name, status, basket
        case userID = "user_id"
        case disabledReason = "disabled_reason"
        case lhsAttribute = "lhs_attribute"
        case lhsExchange = "lhs_exchange"
        case lhsTradingSymbol = "lhs_tradingsymbol"
        case comparison = "operator"
        case rhsType = "rhs_type"
        case rhsAttribute = "rhs_attribute"
        case rhsExchange = "rhs_exchange"
        case rhsTradingSymbol = "rhs_tradingsymbol"
        case rhsConstant = "rhs_constant"
        case alertCount = "alert_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Which type of alert to modify and how to change its basket.
public enum AlertModification: Sendable {
    case simple

    /// Pass nil to keep the existing basket while modifying the condition.
    case ato(basketOperations: [AlertBasketOperation]? = nil)
}

/// An invalid list of alert UUIDs supplied for deletion.
public enum AlertDeletionError: Error {
    case missingUUID
}

extension KiteConnectClient {
    /// Creates a simple alert, or an Alert Triggers Order when a basket is supplied.
    public func createAlert(_ condition: AlertCondition, basket: AlertBasketCreate? = nil) async throws -> Alert {
        var fields = condition.form(type: basket == nil ? .simple : .ato)
        if let basket {
            let json = try JSONEncoder().encode(basket)
            fields.append(.init(name: "basket", value: String(decoding: json, as: UTF8.self)))
        }
        return try await rest.send(.init(.post, path: ["alerts"], body: .form(fields)))
    }

    /// Lists alerts with optional status and pagination filters.
    public func alerts(
        status: AlertStatus? = nil, page: Int? = nil, pageSize: Int? = nil
    ) async throws -> [Alert] {
        let filters: [(String, String?)] = [
            ("status", status?.rawValue),
            ("page", page.map(String.init)),
            ("page_size", pageSize.map(String.init)),
        ]
        let query = filters.compactMap { name, value in
            value.map { URLQueryItem(name: name, value: $0) }
        }
        return try await rest.send(.init(.get, path: ["alerts"], query: query))
    }

    /// Retrieves the alert identified by its UUID.
    public func alert(uuid: String) async throws -> Alert {
        try await rest.send(.init(.get, path: ["alerts", uuid]))
    }

    /// Replaces an alert's condition and optionally applies updates to its ATO basket.
    ///
    /// Supply the current status to preserve it. Kite may re-enable a disabled alert when status is omitted.
    public func modifyAlert(
        uuid: String,
        condition: AlertCondition,
        kind: AlertModification = .simple,
        status: AlertStatus? = nil
    ) async throws -> Alert {
        struct BasketUpdate: Encodable {
            let items: [AlertBasketOperation]
        }

        var fields: [URLQueryItem]
        switch kind {
        case .simple:
            fields = condition.form(type: .simple)
        case .ato(let operations):
            fields = condition.form(type: .ato)
            if let operations {
                let json = try JSONEncoder().encode(BasketUpdate(items: operations))
                fields.append(.init(name: "basket", value: String(decoding: json, as: UTF8.self)))
            }
        }
        if let status {
            fields.append(.init(name: "status", value: status.rawValue))
        }
        return try await rest.send(.init(.put, path: ["alerts", uuid], body: .form(fields)))
    }

    /// Deletes one alert by UUID.
    public func deleteAlert(uuid: String) async throws {
        try await deleteAlerts(uuids: [uuid])
    }

    /// Deletes one or more alerts in a single request.
    public func deleteAlerts(uuids: [String]) async throws {
        guard !uuids.isEmpty, uuids.allSatisfy({ !$0.isEmpty }) else {
            throw AlertDeletionError.missingUUID
        }
        let query = uuids.map { URLQueryItem(name: "uuid", value: $0) }
        _ = try await rest.send(.init(.delete, path: ["alerts"], query: query), as: AlertDeletion.self)
    }
}

private struct AlertDeletion: Decodable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard container.decodeNil() else {
            throw DecodingError.typeMismatch(
                Self.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected null alert deletion data")
            )
        }
    }
}
