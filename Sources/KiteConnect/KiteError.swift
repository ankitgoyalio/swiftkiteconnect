/// Failures surfaced by a Kite Connect REST operation.
public enum KiteError: Error {
    case invalidBaseURL
    case invalidPath
    case missingAccessToken
    case invalidResponse
    case service(KiteServiceError)
    case http(statusCode: Int)
    case transport(domain: String, code: Int)
    case encoding(any Error)
    case decoding(any Error)
}

/// The error Kite reported in its REST response envelope.
public struct KiteServiceError: Error, Equatable {
    public let statusCode: Int
    public let errorType: String
    public let message: String

    public var kind: Kind? { Kind(rawValue: errorType) }
    public var isSessionExpired: Bool { kind == .token }

    public enum Kind: String, Sendable {
        case token = "TokenException"
        case user = "UserException"
        case order = "OrderException"
        case input = "InputException"
        case margin = "MarginException"
        case holding = "HoldingException"
        case network = "NetworkException"
        case data = "DataException"
        case general = "GeneralException"
    }
}
