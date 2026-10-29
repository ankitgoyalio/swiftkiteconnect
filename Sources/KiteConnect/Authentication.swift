//
//  Authentication.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

public extension KiteClient {
    /// Builds the login URL without presenting a browser or sending a request.
    ///
    /// Applications own browser presentation and validation of the registered redirect.
    /// REST sandbox configuration does not change this login endpoint.
    /// See <doc:Authenticate-a-session> for the application-owned flow.
    ///
    /// - Parameters:
    ///   - redirectParameters: An optional opaque string encoded as `redirect_params`.
    ///     The application validates any returned state. The SDK does not interpret it.
    ///   - endpoint: An HTTPS login URL with a host and no credentials, query, or fragment.
    ///     Defaults to production. Pass the sandbox login endpoint explicitly for sandbox use.
    /// - Returns: The endpoint with the API version, API key, and optional redirect parameters.
    /// - Throws: `KiteError.validation` if the endpoint is invalid.
    nonisolated func loginURL(
        redirectParameters: String? = nil,
        endpoint: URL = URL(string: "https://kite.zerodha.com/connect/login")!,
    ) throws -> URL {
        guard endpoint.scheme == "https", endpoint.host != nil, endpoint.user == nil,
              endpoint.password == nil, endpoint.query == nil, endpoint.fragment == nil,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        else {
            throw KiteError.validation(
                field: "endpoint",
                message: "Expected an HTTPS login URL without credentials, query or fragment",
            )
        }
        var parameters = [KiteParameter("v", "3"), KiteParameter("api_key", apiKey)]
        if let redirectParameters {
            parameters.append(KiteParameter("redirect_params", redirectParameters))
        }
        components.percentEncodedQuery = Self.encode(parameters)
        guard let url = components.url else {
            throw KiteError.validation(field: "endpoint", message: "Invalid login URL")
        }
        return url
    }
}

/// A validated token-exchange response with the authenticated user's profile.
///
/// Treat every token as sensitive. The SDK installs the access token in memory
/// but does not persist credentials. See <doc:Authentication-ownership>.
public struct KiteSession: Sendable {
    /// The user's account details returned with the token exchange.
    public let profile: KiteUserProfile
    /// The application API key, checked against the exchanging client.
    public let apiKey: String
    /// The access token installed in the client after response validation.
    public let accessToken: String
    /// The public token returned by Kite. Treat this value as sensitive.
    public let publicToken: String
    /// Usually empty. Long-standing read permissions require platform approval from Kite.
    public let refreshToken: String
    /// The login timestamp, interpreted in the configured trading time zone when no offset is present.
    public let loginTime: Date
}

public extension KiteClient {
    /// Exchanges a one-time request token and installs the validated access token.
    ///
    /// Publicly distributed applications perform this operation on a backend that owns
    /// the API secret. The request uses a SHA-256 checksum, not the secret itself.
    /// A concurrent credential replacement prevents this response from replacing the newer session.
    /// The request attempts once without automatic retry.
    ///
    /// - Parameters:
    ///   - requestToken: The short-lived token from the application's validated login redirect.
    ///     Must contain a non-whitespace character. The exact UTF-8 bytes enter the checksum.
    ///   - apiSecret: The backend-held API secret. Must contain a non-whitespace character.
    ///     The SDK does not trim or persist this value.
    /// - Returns: The profile, tokens, API key, and parsed login time from the validated response.
    /// - Throws: `KiteError` for invalid input, a changed session, transport failure,
    ///   API rejection, or malformed response. Cancellation throws `CancellationError`
    ///   without installing the response token. A canceled request may have reached Kite.
    ///   Decoding failures retain the received HTTP status and omit credential values.
    func exchangeRequestToken(_ requestToken: String, apiSecret: String) async throws
        -> KiteSession
    {
        try Self.validateAuthenticationValue(requestToken, field: "requestToken")
        try Self.validateAuthenticationValue(apiSecret, field: "apiSecret")
        let revision = sessionRevision
        let session = try await execute(
            KiteRequest(
                method: .post, path: "/session/token",
                body: .form([
                    .init("api_key", apiKey), .init("request_token", requestToken),
                    .init("checksum", KiteChecksum.sha256(apiKey + requestToken + apiSecret)),
                ]), authenticated: false,
            ), as: SessionWire.self,
            transform: { wire in
                guard wire.apiKey == apiKey else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: [], debugDescription: "Session api_key does not match client",
                    ))
                }
                guard let loginTime = KiteTimestamp.parse(
                    wire.loginTime, timeZone: configuration.tradingTimeZone,
                ) else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: [], debugDescription: "Invalid session login_time",
                    ))
                }
                try Self.validateResponseAccessToken(wire.accessToken)
                return KiteSession(
                    profile: wire.profile, apiKey: wire.apiKey, accessToken: wire.accessToken,
                    publicToken: wire.publicToken, refreshToken: wire.refreshToken, loginTime: loginTime,
                )
            },
        )
        guard sessionRevision == revision else {
            throw KiteError.validation(
                field: "session", message: "Session changed while authentication was in flight",
            )
        }
        try replaceAccessToken(session.accessToken)
        return session
    }
}

private struct SessionWire: Decodable, Sendable {
    let profile: KiteUserProfile
    let apiKey: String
    let accessToken: String
    let publicToken: String
    let refreshToken: String
    let loginTime: String
    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case accessToken = "access_token"
        case publicToken = "public_token"
        case refreshToken = "refresh_token"
        case loginTime = "login_time"
    }

    init(from decoder: any Decoder) throws {
        profile = try KiteUserProfile(from: decoder)
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try fields.decode(String.self, forKey: .apiKey)
        accessToken = try fields.decode(String.self, forKey: .accessToken)
        publicToken = try fields.decode(String.self, forKey: .publicToken)
        refreshToken = try fields.decode(String.self, forKey: .refreshToken)
        loginTime = try fields.decode(String.self, forKey: .loginTime)
    }
}

/// The token fields returned by a session renewal for a Kite-approved platform.
///
/// The contract follows the official SDK reference. Renewal is not available
/// as general perpetual login and never runs automatically.
public struct KiteSessionRenewal: Decodable, Sendable {
    /// The new access token installed after response validation.
    public let accessToken: String
    /// An optional refresh token supplied by Kite. Absence does not synthesize a replacement.
    public let refreshToken: String?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

public extension KiteClient {
    /// Renews and installs an access token for a Kite-approved refresh-token platform.
    ///
    /// This backend-only operation follows the official Python SDK route and checksum;
    /// the pinned user documentation does not fully describe it. It attempts once.
    /// A concurrent credential replacement prevents installation of the stale response.
    ///
    /// - Parameters:
    ///   - refreshToken: A Kite-issued refresh token with a non-whitespace character.
    ///   - apiSecret: The backend-held secret with a non-whitespace character.
    ///     The checksum uses the exact token and secret bytes without trimming.
    /// - Returns: The new access token and optional refresh token. The SDK does not persist either.
    /// - Throws: `KiteError` for invalid input, a changed session, transport failure,
    ///   API rejection, or invalid response. Cancellation throws `CancellationError`
    ///   without installing the response token. Remote processing may still have occurred.
    ///   Decoding failures retain the received HTTP status and omit credential values.
    func renewSession(refreshToken: String, apiSecret: String) async throws
        -> KiteSessionRenewal
    {
        try Self.validateAuthenticationValue(refreshToken, field: "refreshToken")
        try Self.validateAuthenticationValue(apiSecret, field: "apiSecret")
        let revision = sessionRevision
        let session = try await execute(
            KiteRequest(
                method: .post, path: "/session/refresh_token",
                body: .form([
                    .init("api_key", apiKey), .init("refresh_token", refreshToken),
                    .init("checksum", KiteChecksum.sha256(apiKey + refreshToken + apiSecret)),
                ]), authenticated: false,
            ), as: KiteSessionRenewal.self,
            transform: { session in
                try Self.validateResponseAccessToken(session.accessToken)
                return session
            },
        )
        guard sessionRevision == revision else {
            throw KiteError.validation(
                field: "session", message: "Session changed while authentication was in flight",
            )
        }
        try replaceAccessToken(session.accessToken)
        return session
    }
}

public extension KiteClient {
    /// Requests revocation of the installed session and clears matching local credentials on success.
    ///
    /// Only a `true` response clears the local token, and only if credentials have not
    /// changed during the request. A `false` response preserves the token.
    /// This operation does not log the user out of official Kite apps. Requests already
    /// handed to the transport may still complete with their original credentials.
    ///
    /// - Returns: Kite's confirmation that the access token was invalidated.
    /// - Throws: `KiteError` if no token is installed, or for transport failure,
    ///   API rejection, or invalid response. Cancellation throws `CancellationError`
    ///   and preserves local credentials. Remote revocation may still have occurred.
    ///   The SDK does not retry. Applications clear their own credential store separately.
    @discardableResult func invalidateSession() async throws -> Bool {
        guard let token = accessToken else {
            throw KiteError.validation(
                field: "accessToken", message: "An authenticated session is required",
            )
        }
        let revision = sessionRevision
        let invalidated = try await execute(
            KiteRequest(
                method: .delete, path: "/session/token",
                query: [
                    .init("api_key", apiKey), .init("access_token", token),
                ],
            ), as: Bool.self,
        )
        if invalidated, sessionRevision == revision {
            try replaceAccessToken(nil)
        }
        return invalidated
    }
}

public extension KiteClient {
    /// Requests revocation of a refresh token without changing local access credentials.
    ///
    /// This approved-platform operation follows the official SDK reference and sends
    /// no access-token authorization header. It attempts once without automatic retry.
    ///
    /// - Parameter refreshToken: The token to revoke, containing a non-whitespace character.
    /// - Returns: Kite's confirmation that the refresh token was invalidated.
    /// - Throws: `KiteError` for invalid input, transport failure, API rejection, or
    ///   malformed response. Cancellation throws `CancellationError`. Cancellation
    ///   does not establish whether Kite processed the revocation.
    @discardableResult func invalidateRefreshToken(_ refreshToken: String) async throws -> Bool {
        try Self.validateAuthenticationValue(refreshToken, field: "refreshToken")
        return try await execute(
            KiteRequest(
                method: .delete, path: "/session/token",
                query: [
                    .init("api_key", apiKey), .init("refresh_token", refreshToken),
                ], authenticated: false,
            ), as: Bool.self,
        )
    }
}

extension KiteClient {
    private static func validateResponseAccessToken(_ token: String) throws {
        do {
            try validateCredential(token, field: "accessToken")
        } catch {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Invalid session access_token: expected a nonempty credential without whitespace, control characters, or colons",
            ))
        }
    }

    private static func validateAuthenticationValue(_ value: String, field: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KiteError.validation(field: field, message: "Must be nonempty")
        }
    }
}
