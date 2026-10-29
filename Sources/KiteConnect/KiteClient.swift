//
//  KiteClient.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// An HTTP or Kite error response, retaining server diagnostics for caller policy.
public struct KiteAPIError: Error, Sendable, Equatable {
    /// The HTTP status received, even when a success status contains a Kite error envelope.
    public let statusCode: Int
    /// The server error type, including unfamiliar values, or nil without a decoded error type.
    public let errorType: String?
    /// The server message, or an HTTP status description when no message decodes.
    public let message: String
    /// Response header fields as supplied by the transport, without case normalization.
    public let headers: [String: String]
}

/// Local validation, transport, API, and decoding failures from REST operations.
///
/// Cancellation remains CancellationError. For trading mutations, inspect uncertainOutcome
/// and reconcile server state before resubmission. See <doc:Trading-mutation-outcomes>.
public indirect enum KiteError: Error, Sendable {
    /// A local structural check failed before dispatch; field identifies the input and message explains the constraint.
    case validation(field: String, message: String)
    /// The transport failed; code is the underlying NSError code when available and message describes the failure.
    case transport(code: Int?, message: String)
    /// An HTTP or Kite rejection with status, message, headers, and any decoded server error type.
    ///
    /// A non-Kite gateway response for a trading mutation is wrapped in uncertainOutcome.
    case api(KiteAPIError)
    /// A response could not satisfy its required schema; statusCode is the received HTTP status and message describes the failure.
    case decoding(statusCode: Int, message: String)
    /// A mutation may have reached Kite. Reconcile before submitting another action.
    case uncertainOutcome(KiteError)
}

/// Immutable routing, timeout, and trading-time settings for a client.
///
/// Defaults select production. Use ``sandbox`` for sandbox routing.
/// Construction validates settings locally without contacting Kite.
public struct KiteConfiguration: Sendable {
    /// HTTP origin and optional base path used to construct request URLs.
    public let baseURL: URL
    /// API path prefix without surrounding slashes. Instrument dumps omit this prefix.
    public let routePrefix: String
    /// Maximum duration in seconds passed to the HTTP transport for each request.
    public let timeout: TimeInterval
    /// Time zone used to interpret trading timestamps without an explicit offset.
    public let tradingTimeZone: TimeZone
    /// Creates validated settings for request routing and trading timestamps.
    ///
    /// - Parameters:
    ///   - baseURL: An HTTP or HTTPS URL with a host, without credentials, a query, or a fragment.
    ///   - routePrefix: An empty string or an absolute path without traversal, a query, or a fragment.
    ///     Surrounding slashes are removed from the stored value.
    ///   - timeout: A finite, positive request timeout in seconds.
    ///   - tradingTimeZone: The time zone for trading timestamps. Defaults to Asia/Kolkata.
    /// - Throws: ``KiteError/validation(field:message:)`` if the URL, prefix, or timeout is invalid.
    public init(
        baseURL: URL = URL(string: "https://api.kite.trade")!, routePrefix: String = "",
        timeout: TimeInterval = 30, tradingTimeZone: TimeZone = TimeZone(identifier: "Asia/Kolkata")!,
    ) throws {
        guard ["https", "http"].contains(baseURL.scheme), baseURL.host != nil, baseURL.user == nil,
              baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil
        else {
            throw KiteError.validation(
                field: "baseURL", message: "Expected an HTTP origin without credentials, query, or fragment",
            )
        }
        guard timeout.isFinite, timeout > 0 else {
            throw KiteError.validation(field: "timeout", message: "Must be finite and positive")
        }
        guard
            routePrefix.isEmpty
            || (routePrefix.hasPrefix("/") && !routePrefix.contains("?") && !routePrefix.contains("#")
                && !routePrefix.contains(".."))
        else {
            throw KiteError.validation(field: "routePrefix", message: "Expected an absolute path prefix")
        }
        self.baseURL = baseURL
        self.routePrefix = routePrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.timeout = timeout
        self.tradingTimeZone = tradingTimeZone
    }

    /// Sandbox settings with the `https://sandbox.kite.trade` origin and `/oms` API prefix.
    ///
    /// Instrument dumps use the origin without the API prefix. This setting supplies no credentials.
    public static var sandbox: KiteConfiguration {
        try! KiteConfiguration(baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms")
    }
}

/// Application-provided credentials for one API key and user session.
///
/// The value stores credentials in memory without validation or persistence.
/// Client construction validates both values. See <doc:Authenticate-a-session>.
public struct KiteSessionCredentials: Sendable {
    /// The API key for the application that owns this user session.
    public let apiKey: String
    /// The sensitive access token supplied by the application's authentication flow.
    public let accessToken: String
    /// Stores credentials for subsequent validation by a client initializer.
    ///
    /// - Parameters:
    ///   - apiKey: The application API key. This initializer stores it unchanged.
    ///   - accessToken: The user's access token. This initializer stores it unchanged.
    public init(apiKey: String, accessToken: String) {
        self.apiKey = apiKey
        self.accessToken = accessToken
    }
}

/// An actor that sends REST requests for one API key and user session.
///
/// Share a client between Swift tasks for the same session. Create separate clients
/// for separate users. Applications own authentication and credential storage.
/// Requests attempt once without a queue or automatic retry. Construction sends no request.
///
/// See <doc:Create-a-client> for a sandbox configuration example.
public actor KiteClient {
    /// Immutable routing and timeout settings used by this client.
    public nonisolated let configuration: KiteConfiguration
    /// The API key identifying the application for this client.
    public nonisolated let apiKey: String
    // Actor-isolated access for typed authentication endpoint extensions in this module.
    var accessToken: String?
    var sessionRevision: UInt64 = 0
    private let transport: any KiteHTTPTransport

    /// Creates an isolated client with explicit credentials and a transport.
    ///
    /// - Parameters:
    ///   - apiKey: A nonempty application API key without whitespace, control characters, or colons.
    ///   - accessToken: A token with the same character constraints, or `nil` before authentication.
    ///   - configuration: Request settings. Defaults to production.
    ///   - transport: The HTTP transport. Defaults to an ephemeral URLSession transport.
    /// - Throws: ``KiteError/validation(field:message:)`` if either credential is invalid.
    public init(
        apiKey: String, accessToken: String? = nil,
        configuration: KiteConfiguration = try! KiteConfiguration(),
        transport: any KiteHTTPTransport = URLSessionKiteTransport(),
    ) throws {
        try Self.validateCredential(apiKey, field: "apiKey")
        if let accessToken {
            try Self.validateCredential(accessToken, field: "accessToken")
        }
        self.apiKey = apiKey
        self.accessToken = accessToken
        self.configuration = configuration
        self.transport = transport
    }

    /// Creates an isolated client from application-provided session credentials.
    ///
    /// - Parameters:
    ///   - session: The API key and access token. Each must be nonempty and contain no
    ///     whitespace, control characters, or colons.
    ///   - configuration: Request settings. Defaults to production.
    ///   - transport: The HTTP transport used for a single attempt per request.
    /// - Throws: ``KiteError/validation(field:message:)`` if the session credentials are invalid.
    public init(
        session: KiteSessionCredentials,
        configuration: KiteConfiguration = try! KiteConfiguration(),
        transport: any KiteHTTPTransport = URLSessionKiteTransport(),
    ) throws {
        try self.init(
            apiKey: session.apiKey, accessToken: session.accessToken,
            configuration: configuration, transport: transport,
        )
    }

    /// Replaces the access token in memory or clears it locally without remote revocation.
    ///
    /// Requests admitted after this method returns use the replacement. Requests already
    /// handed to the transport may complete with their original session. In-flight
    /// exchange or renewal responses cannot overwrite this replacement. Ticker credentials
    /// and application credential storage remain separate.
    ///
    /// - Parameter token: A nonempty token without whitespace, control characters, or
    ///   colons. Pass `nil` to clear local credentials. The API key remains unchanged.
    /// - Throws: `KiteError.validation` if the replacement is invalid. Invalid input
    ///   preserves the current token. This synchronous actor method sends no request.
    public func replaceAccessToken(_ token: String?) throws {
        if let token {
            try Self.validateCredential(token, field: "accessToken")
        }
        accessToken = token
        sessionRevision &+= 1
    }

    static func validateCredential(_ value: String, field: String) throws {
        guard !value.isEmpty,
              !value.contains(where: {
                  $0.isWhitespace || $0.isNewline || $0 == ":"
                      || $0.asciiValue.map { $0 < 32 || $0 == 127 } == true
              })
        else {
            throw KiteError.validation(
                field: field,
                message: "Must be a nonempty credential without whitespace, control characters, or colons",
            )
        }
    }

    /// Fetches the authenticated user's account profile in one read-only request.
    ///
    /// No retry or session renewal occurs. See <doc:First-request> for a guided example.
    ///
    /// - Returns: The user's identity, account metadata, and enabled trading capabilities.
    /// - Throws: `KiteError` for missing local credentials, transport failure, API
    ///   rejection, or malformed response. Cancellation throws `CancellationError`.
    ///   The installed credentials remain unchanged on success, failure, or cancellation.
    public func profile() async throws -> KiteUserProfile {
        try await execute(KiteRequest(path: "/user/profile"), as: KiteUserProfile.self)
    }

    /// Sends one request and decodes the data field of a Kite success envelope.
    ///
    /// - Parameters:
    ///   - request: The route, encoding, authentication, and mutation classification.
    ///   - as: The Decodable and Sendable type expected inside data.
    /// - Returns: The decoded data value, using the configured trading time zone for dates.
    /// - Throws: KiteError for validation, transport, API, or decoding failure. Trading
    ///   mutation transport and malformed response failures carry uncertainOutcome.
    ///   Cancellation throws CancellationError and does not prove server rejection.
    public func execute<Value: Decodable & Sendable>(_ request: KiteRequest, as _: Value.Type)
        async throws -> Value
    {
        try await execute(request, as: Value.self, transform: { $0 })
    }

    /// Keep endpoint-specific response validation inside the HTTP decoding boundary.
    func execute<Value: Decodable & Sendable, Result>(
        _ request: KiteRequest, as _: Value.Type, transform: (Value) throws -> Result,
    ) async throws -> Result {
        let response = try await response(for: request)
        do {
            let envelope = try KiteTimestamp.decoder(timeZone: configuration.tradingTimeZone).decode(
                Envelope<Value>.self, from: response.body,
            )
            guard envelope.status == "success" else {
                throw KiteError.decoding(
                    statusCode: response.statusCode, message: "Expected success envelope",
                )
            }
            return try transform(envelope.data)
        } catch {
            let failure = KiteError.decoding(
                statusCode: response.statusCode,
                message: "Malformed or missing required response data: \(error)",
            )
            throw request.isTradingMutation ? KiteError.uncertainOutcome(failure) : failure
        }
    }

    /// Sends one request and validates its HTTP status and any Kite error envelope.
    ///
    /// - Parameter request: The route and encoding; typed endpoints set mutation and dump flags.
    /// - Returns: The successful HTTP response, with body bytes unchanged for CSV or custom decoding.
    /// - Throws: KiteError for invalid paths, missing credentials, transport failures, or
    ///   API rejection. Non-Kite mutation failures carry uncertainOutcome. Cancellation
    ///   throws CancellationError; cancellation after dispatch does not prove rejection.
    ///
    /// No retry, redirect following, rate-limit queue, or automatic refresh occurs with
    /// the default transport. Custom transports must honor the single-attempt contract.
    public func response(for request: KiteRequest) async throws -> KiteHTTPResponse {
        try Task.checkCancellation()
        guard request.path.hasPrefix("/"), !request.path.contains(".."), !request.path.contains("?"),
              !request.path.contains("#"), !request.path.contains("://")
        else {
            throw KiteError.validation(
                field: "path", message: "Expected a relative API path without query or traversal",
            )
        }
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)!
        let prefix = request.isInstrumentDump ? "" : configuration.routePrefix
        components.path =
            components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).withLeadingSlash
                + (prefix.isEmpty ? "" : "/" + prefix) + request.path
        components.percentEncodedQuery = request.query.isEmpty ? nil : Self.encode(request.query)
        guard let url = components.url else {
            throw KiteError.validation(field: "path", message: "Invalid URL")
        }
        var headers = ["X-Kite-Version": "3", "Accept": "application/json"]
        if request.authenticated {
            guard let accessToken else {
                throw KiteError.validation(
                    field: "accessToken", message: "An authenticated session is required",
                )
            }
            headers["Authorization"] = "token \(apiKey):\(accessToken)"
        }
        var body: Data?
        switch request.body {
        case let .form(fields):
            body = Data(Self.encode(fields).utf8)
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        case let .json(data):
            body = data
            headers["Content-Type"] = "application/json"
        case nil: break
        }
        let wire = KiteHTTPRequest(
            url: url, method: request.method, headers: headers, body: body, timeout: configuration.timeout,
        )
        let response: KiteHTTPResponse
        do { response = try await transport.send(wire) } catch {
            let ns = error as NSError
            if error is CancellationError
                || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled)
                || Task.isCancelled
            {
                throw CancellationError()
            }
            let failure = KiteError.transport(code: ns.code, message: ns.localizedDescription)
            throw request.isTradingMutation ? KiteError.uncertainOutcome(failure) : failure
        }
        try Task.checkCancellation()
        let apiFailure = try? JSONDecoder().decode(ErrorEnvelope.self, from: response.body)
        if !(200 ..< 300).contains(response.statusCode) || apiFailure?.status == "error" {
            // A valid Kite error envelope confirms rejection. Gateway/non-JSON mutation failures remain uncertain.
            let failure = KiteError.api(
                KiteAPIError(
                    statusCode: response.statusCode, errorType: apiFailure?.errorType,
                    message: apiFailure?.message ?? "HTTP \(response.statusCode)", headers: response.headers,
                ),
            )
            if request.isTradingMutation, apiFailure?.status != "error" {
                throw KiteError.uncertainOutcome(failure)
            }
            throw failure
        }
        return response
    }

    static func encode(_ parameters: [KiteParameter]) -> String {
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~",
        )
        return parameters.map {
            $0.name.addingPercentEncoding(withAllowedCharacters: allowed)! + "=" + $0.value
                .addingPercentEncoding(withAllowedCharacters: allowed)!
        }.joined(separator: "&")
    }
}

private struct Envelope<Value: Decodable>: Decodable {
    let status: String
    let data: Value
}

private struct ErrorEnvelope: Decodable {
    let status: String
    let message: String?
    let errorType: String?
    enum CodingKeys: String, CodingKey {
        case status, message
        case errorType = "error_type"
    }
}

private extension String { var withLeadingSlash: String {
    isEmpty ? "" : "/" + self
} }
