import CryptoKit
import Darwin
import Foundation

/// An order notification delivered to the integrating app's registered HTTP Postback receiver.
///
/// Pass the raw HTTP request body to `decode(_:)`, then check `verifyChecksum(apiSecret:)`
/// using the Kite API secret held in your trusted backend.
public struct Postback: Decodable, Equatable, Sendable {
    /// The exact order ID string received from Kite, as used in checksum verification.
    public let orderID: String
    /// The exact order timestamp string received from Kite, as used in checksum verification.
    public let orderTimestamp: String
    public let checksum: String

    public let userID: String
    public let appID: Int64
    public let placedBy: String
    public let exchangeOrderID: String?
    public let parentOrderID: String?
    public let status: String?
    public let statusMessage: String?
    public let statusMessageRaw: String?
    public let exchangeUpdateTimestamp: String?
    public let exchangeTimestamp: String?
    public let variety: String
    public let exchange: String
    public let tradingSymbol: String
    public let instrumentToken: UInt32
    public let orderType: String
    public let transactionType: String
    public let validity: String
    public let product: String
    public let quantity: Int64
    public let disclosedQuantity: Int64
    public let price: Double
    public let triggerPrice: Double
    public let averagePrice: Double
    public let filledQuantity: Int64
    public let unfilledQuantity: Int64
    public let pendingQuantity: Int64
    public let cancelledQuantity: Int64
    public let marketProtection: Double?
    public let meta: Metadata?
    public let tag: String?
    public let guid: String?

    /// JSON metadata attached to a Postback, typically an object or string.
    public enum Metadata: Decodable, Equatable, Sendable {
        case object([String: Metadata])
        case array([Metadata])
        case string(String)
        case integer(Int64)
        case number(Double)
        case boolean(Bool)
        case null

        public init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()
            if value.decodeNil() {
                self = .null
            } else if let string = try? value.decode(String.self) {
                self = .string(string)
            } else if let boolean = try? value.decode(Bool.self) {
                self = .boolean(boolean)
            } else if let integer = try? value.decode(Int64.self) {
                self = .integer(integer)
            } else if let number = try? value.decode(Double.self) {
                self = .number(number)
            } else if let array = try? value.decode([Metadata].self) {
                self = .array(array)
            } else {
                self = .object(try value.decode([String: Metadata].self))
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case orderTimestamp = "order_timestamp"
        case checksum
        case userID = "user_id"
        case appID = "app_id"
        case placedBy = "placed_by"
        case exchangeOrderID = "exchange_order_id"
        case parentOrderID = "parent_order_id"
        case status
        case statusMessage = "status_message"
        case statusMessageRaw = "status_message_raw"
        case exchangeUpdateTimestamp = "exchange_update_timestamp"
        case exchangeTimestamp = "exchange_timestamp"
        case variety, exchange
        case tradingSymbol = "tradingsymbol"
        case instrumentToken = "instrument_token"
        case orderType = "order_type"
        case transactionType = "transaction_type"
        case validity, product, quantity
        case disclosedQuantity = "disclosed_quantity"
        case price
        case triggerPrice = "trigger_price"
        case averagePrice = "average_price"
        case filledQuantity = "filled_quantity"
        case unfilledQuantity = "unfilled_quantity"
        case pendingQuantity = "pending_quantity"
        case cancelledQuantity = "cancelled_quantity"
        case marketProtection = "market_protection"
        case meta, tag, guid
    }

    /// Decodes the raw JSON body of an HTTP Postback. Verify its checksum before using the payload.
    public static func decode(_ body: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: body)
    }

    /// Checks the received hexadecimal SHA-256 digest using the trusted Kite API secret.
    ///
    /// Kite hashes the UTF-8 bytes of `order_id`, `order_timestamp`, and the API secret,
    /// in that order with no separators. Only the order ID and order timestamp are covered.
    /// Treat all other payload fields, including status, prices, and quantities, as unsigned.
    /// See [Kite Connect Postbacks](https://kite.trade/docs/connect/v3/postbacks/#checksum).
    public func verifyChecksum(apiSecret: String) -> Bool {
        let byteCount = SHA256.Digest.byteCount
        let hex = Array(checksum.utf8.prefix(byteCount * 2 + 1))
        guard hex.count == byteCount * 2 else { return false }

        var received = [UInt8]()
        received.reserveCapacity(byteCount)
        for index in stride(from: 0, to: hex.count, by: 2) {
            guard let high = Self.hexValue(hex[index]),
                  let low = Self.hexValue(hex[index + 1]) else { return false }
            received.append(high << 4 | low)
        }

        var hash = SHA256()
        hash.update(data: Data(orderID.utf8))
        hash.update(data: Data(orderTimestamp.utf8))
        hash.update(data: Data(apiSecret.utf8))
        return hash.finalize().withUnsafeBytes { expectedBytes in
            received.withUnsafeBytes { receivedBytes in
                timingsafe_bcmp(expectedBytes.baseAddress, receivedBytes.baseAddress, byteCount) == 0
            }
        }
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: byte - 48
        case 65...70: byte - 65 + 10
        case 97...102: byte - 97 + 10
        default: nil
        }
    }
}
