//
//  HTTP.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// HTTP verbs used by Kite REST routes; a verb alone does not classify mutation safety.
public enum KiteHTTPMethod: String, Sendable {
    /// Reads a resource with the GET wire verb.
    case get = "GET"
    /// Submits a body with POST; callers must classify trading mutations separately.
    case post = "POST"
    /// Updates a resource with the PUT wire verb.
    case put = "PUT"
    /// Removes or invalidates a resource with the DELETE wire verb.
    case delete = "DELETE"
}

/// One request attempt. Implementations must honor cancellation and must not retry.
public protocol KiteHTTPTransport: Sendable {
    /// Performs exactly one HTTP attempt without retries or automatic redirects.
    ///
    /// - Parameter request: Fully constructed URL, headers, body, method, and timeout.
    /// - Returns: Status, headers, and body, including non-success HTTP responses.
    /// - Throws: A transport error when no response completes. Honor task cancellation
    ///   promptly. KiteClient maps cancellation and classifies uncertain mutations.
    func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse
}

/// A fully encoded HTTP request passed to a replaceable single-attempt transport.
public struct KiteHTTPRequest: Sendable {
    /// The complete request URL, including its encoded query string.
    public let url: URL
    /// The HTTP wire verb for this attempt; it does not authorize retries.
    public let method: KiteHTTPMethod
    /// Request headers, potentially including sensitive session credentials.
    public let headers: [String: String]
    /// Encoded body bytes, or nil when the request has no body.
    public let body: Data?
    /// The requested positive timeout in seconds; custom transports must apply it.
    public let timeout: TimeInterval
    /// Stores an encoded request without validating its URL or timeout.
    ///
    /// - Parameters:
    ///   - url: Complete URL with an encoded query.
    ///   - method: HTTP verb to send once.
    ///   - headers: Header fields; the transport must not forward credentials on redirects.
    ///   - body: Optional encoded bytes.
    ///   - timeout: Request timeout in seconds; KiteConfiguration validates client timeouts.
    public init(
        url: URL, method: KiteHTTPMethod, headers: [String: String] = [:], body: Data? = nil,
        timeout: TimeInterval = 30,
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// An HTTP response before Kite envelope interpretation or endpoint decoding.
public struct KiteHTTPResponse: Sendable {
    /// The received HTTP status, including non-success statuses.
    public let statusCode: Int
    /// Response headers in the transport's original spelling; names are case-insensitive in HTTP.
    public let headers: [String: String]
    /// Response bytes supplied by the transport for subsequent envelope or CSV decoding.
    public let body: Data
    /// Stores an HTTP result without interpreting status or validating body content.
    ///
    /// - Parameters:
    ///   - statusCode: The received HTTP status.
    ///   - headers: Response header fields without normalization.
    ///   - body: Response bytes, including error bodies.
    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

/// An ephemeral URLSession transport that surfaces redirects instead of following them.
///
/// Each send creates a session without persistent cookies or caches. HTTP content
/// decoding follows URLSession behavior. No application-level retry occurs.
public final class URLSessionKiteTransport: NSObject, KiteHTTPTransport, URLSessionTaskDelegate {
    /// Creates an HTTP transport without persistent cookie or credential storage.
    override public init() {
        super.init()
    }

    /// Sends one HTTP request with an ephemeral session and the supplied timeout.
    ///
    /// - Parameter request: Fully encoded request to dispatch.
    /// - Returns: HTTP status, headers, and body; redirects remain visible to the caller.
    /// - Throws: URLSession errors, including cancellation, or KiteError.transport for a
    ///   non-HTTP response. KiteClient normalizes cancellation to CancellationError.
    public func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = request.timeout
        configuration.timeoutIntervalForResource = request.timeout
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var wire = URLRequest(url: request.url, timeoutInterval: request.timeout)
        wire.httpMethod = request.method.rawValue
        wire.allHTTPHeaderFields = request.headers
        wire.httpBody = request.body
        let (data, response) = try await session.data(for: wire)
        guard let http = response as? HTTPURLResponse else {
            throw KiteError.transport(code: nil, message: "Non-HTTP response")
        }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) {
            $0[String(describing: $1.key)] = String(describing: $1.value)
        }
        return KiteHTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
    }

    /// Declines redirects so credentials are not forwarded and mutations are not resubmitted.
    ///
    /// - Parameters:
    ///   - session: The session proposing the redirect.
    ///   - task: The task receiving the redirect response.
    ///   - response: The original HTTP redirect response.
    ///   - request: The proposed follow-up request; this transport never sends it.
    ///   - completionHandler: Called once with nil to retain the original response.
    public func urlSession(
        _: URLSession, task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse, newRequest _: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void,
    ) {
        completionHandler(nil)
    }
}
