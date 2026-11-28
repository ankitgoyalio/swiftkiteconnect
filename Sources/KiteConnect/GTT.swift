import Foundation

/// An order to place when its matching GTT trigger value is reached.
public struct GTTLeg: Equatable, Sendable {
    public enum TransactionType: String, Encodable, Sendable {
        case buy = "BUY"
        case sell = "SELL"
    }

    public enum Product: String, Encodable, Sendable {
        case cnc = "CNC"
        case mis = "MIS"
        case nrml = "NRML"
    }

    public let triggerValue: Double
    public let limitPrice: Double
    public let quantity: Int
    public let transactionType: TransactionType
    public let product: Product

    public init(
        triggerValue: Double,
        limitPrice: Double,
        quantity: Int,
        transactionType: TransactionType,
        product: Product
    ) {
        self.triggerValue = triggerValue
        self.limitPrice = limitPrice
        self.quantity = quantity
        self.transactionType = transactionType
        self.product = product
    }
}

/// The instrument, last traded price, and legs of a GTT to create or modify.
public struct GTTRequest: Equatable, Sendable {
    public enum Legs: Equatable, Sendable {
        case single(GTTLeg)
        /// The lower and upper price conditions and their corresponding orders.
        case twoLeg(lower: GTTLeg, upper: GTTLeg)
    }

    public let exchange: String
    public let tradingSymbol: String
    public let lastPrice: Double
    public let legs: Legs

    public init(exchange: String, tradingSymbol: String, lastPrice: Double, legs: Legs) {
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
        self.lastPrice = lastPrice
        self.legs = legs
    }

    fileprivate func formBody() throws -> RESTRequest.Body {
        let type: String
        let orderedLegs: [GTTLeg]
        switch legs {
        case .single(let leg):
            type = "single"
            orderedLegs = [leg]
        case .twoLeg(let lower, let upper):
            type = "two-leg"
            orderedLegs = [lower, upper]
        }

        let condition = Condition(
            exchange: exchange, tradingSymbol: tradingSymbol, lastPrice: lastPrice,
            triggerValues: orderedLegs.map(\.triggerValue)
        )
        let orders = orderedLegs.map { leg in
            Order(
                exchange: exchange, tradingSymbol: tradingSymbol, transactionType: leg.transactionType,
                quantity: leg.quantity, product: leg.product, price: leg.limitPrice
            )
        }

        return .form([
            .init(name: "type", value: type),
            .init(name: "condition", value: String(decoding: try RESTRequest.encodeJSON(condition), as: UTF8.self)),
            .init(name: "orders", value: String(decoding: try RESTRequest.encodeJSON(orders), as: UTF8.self)),
        ])
    }

    private struct Condition: Encodable {
        let exchange: String
        let tradingSymbol: String
        let lastPrice: Double
        let triggerValues: [Double]

        enum CodingKeys: String, CodingKey {
            case exchange
            case tradingSymbol = "tradingsymbol"
            case lastPrice = "last_price"
            case triggerValues = "trigger_values"
        }
    }

    private struct Order: Encodable {
        let exchange: String
        let tradingSymbol: String
        let transactionType: GTTLeg.TransactionType
        let quantity: Int
        let product: GTTLeg.Product
        let price: Double
        let orderType = "LIMIT"

        enum CodingKeys: String, CodingKey {
            case exchange, quantity, product, price
            case tradingSymbol = "tradingsymbol"
            case transactionType = "transaction_type"
            case orderType = "order_type"
        }
    }
}

/// The trigger ID returned by a successful GTT write.
public struct GTTAcknowledgement: Decodable, Equatable, Sendable {
    public let triggerID: Int

    private enum CodingKeys: String, CodingKey {
        case triggerID = "trigger_id"
    }
}

/// The condition, order legs, and status of a GTT as returned by Kite.
public struct GTTTrigger: Decodable, Equatable, Sendable {
    public struct Condition: Decodable, Equatable, Sendable {
        public let exchange: String
        public let tradingSymbol: String
        public let lastPrice: Double
        public let triggerValues: [Double]
        public let instrumentToken: UInt32?

        private enum CodingKeys: String, CodingKey {
            case exchange
            case tradingSymbol = "tradingsymbol"
            case lastPrice = "last_price"
            case triggerValues = "trigger_values"
            case instrumentToken = "instrument_token"
        }
    }

    public struct Order: Decodable, Equatable, Sendable {
        public struct Result: Decodable, Equatable, Sendable {
            public struct OrderResult: Decodable, Equatable, Sendable {
                public let status: String
                public let orderID: String?
                public let rejectionReason: String?

                private enum CodingKeys: String, CodingKey {
                    case status
                    case orderID = "order_id"
                    case rejectionReason = "rejection_reason"
                }
            }

            public let accountID: String
            public let exchange: String
            public let tradingSymbol: String
            public let validity: String
            public let product: String
            public let orderType: String
            public let transactionType: String
            public let quantity: Double
            public let price: Double
            /// The order metadata as a JSON string supplied by Kite.
            public let meta: String?
            /// The local timestamp supplied by Kite.
            public let timestamp: String?
            public let triggeredAt: Double
            public let orderResult: OrderResult?

            private enum CodingKeys: String, CodingKey {
                case exchange, validity, product, quantity, price, meta, timestamp
                case accountID = "account_id"
                case tradingSymbol = "tradingsymbol"
                case orderType = "order_type"
                case transactionType = "transaction_type"
                case triggeredAt = "triggered_at"
                case orderResult = "order_result"
            }
        }

        public let exchange: String
        public let tradingSymbol: String
        public let product: String
        public let orderType: String
        public let transactionType: String
        public let quantity: Double
        public let price: Double
        public let result: Result?

        private enum CodingKeys: String, CodingKey {
            case exchange, product, quantity, price, result
            case tradingSymbol = "tradingsymbol"
            case orderType = "order_type"
            case transactionType = "transaction_type"
        }
    }

    public struct Metadata: Decodable, Equatable, Sendable {
        public let rejectionReason: String?

        private enum CodingKeys: String, CodingKey {
            case rejectionReason = "rejection_reason"
        }
    }

    public let id: Int
    public let userID: String
    public let parentTriggerID: Int?
    /// The trigger type supplied by Kite, such as `single` or `two-leg`.
    public let type: String
    /// The local creation, update, and expiry timestamps supplied by Kite.
    public let createdAt: String?
    public let updatedAt: String?
    public let expiresAt: String?
    public let status: String
    public let condition: Condition
    public let orders: [Order]
    public let meta: Metadata?

    private enum CodingKeys: String, CodingKey {
        case id, type, status, condition, orders, meta
        case userID = "user_id"
        case parentTriggerID = "parent_trigger"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }
}

extension KiteConnectClient {
    /// Creates a GTT and returns its trigger ID.
    public func createGTT(_ request: GTTRequest) async throws -> GTTAcknowledgement {
        try await rest.send(.init(.post, path: ["gtt", "triggers"], body: request.formBody()))
    }

    /// Lists triggers visible in the GTT order book.
    public func gttTriggers() async throws -> [GTTTrigger] {
        try await rest.send(.init(.get, path: ["gtt", "triggers"]))
    }

    /// Retrieves a GTT by its trigger ID.
    public func gtt(triggerID: Int) async throws -> GTTTrigger {
        try await rest.send(.init(.get, path: ["gtt", "triggers", String(triggerID)]))
    }

    /// Replaces the condition and orders of an active GTT.
    public func modifyGTT(triggerID: Int, request: GTTRequest) async throws -> GTTAcknowledgement {
        try await rest.send(.init(.put, path: ["gtt", "triggers", String(triggerID)], body: request.formBody()))
    }

    /// Deletes an active GTT and returns its trigger ID.
    public func deleteGTT(triggerID: Int) async throws -> GTTAcknowledgement {
        try await rest.send(.init(.delete, path: ["gtt", "triggers", String(triggerID)]))
    }
}
