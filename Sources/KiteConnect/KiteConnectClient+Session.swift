import CryptoKit
import Foundation

extension KiteConnectClient {
    /// Exchanges the one-time Request Token from the caller's login flow for a Kite session.
    ///
    /// For distributed apps, keep the API secret on a trusted backend and perform the exchange
    /// there. The caller handles browser login and stores the returned credentials.
    public static func exchangeRequestToken(
        _ requestToken: String,
        apiKey: String,
        apiSecret: String,
        baseURL: URL = Self.defaultBaseURL,
        session: URLSession = .shared
    ) async throws -> UserSession {
        let checksum = SHA256.hash(data: Data((apiKey + requestToken + apiSecret).utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let rest = RESTClient(apiKey: apiKey, baseURL: baseURL, session: session)
        return try await rest.send(.init(
            .post,
            path: ["session", "token"],
            body: .form([
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "request_token", value: requestToken),
                URLQueryItem(name: "checksum", value: checksum),
            ]),
            authentication: .none
        ))
    }

    /// Invalidates this client's Access Token and returns Kite's Boolean result.
    /// The caller manages stored credentials and starts a fresh login before making further authenticated calls.
    public func invalidateAccessToken() async throws -> Bool {
        guard let accessToken = rest.accessToken else { throw KiteError.missingAccessToken }
        return try await rest.send(.init(
            .delete,
            path: ["session", "token"],
            query: [
                URLQueryItem(name: "api_key", value: rest.apiKey),
                URLQueryItem(name: "access_token", value: accessToken),
            ],
            authentication: .none
        ))
    }
}
