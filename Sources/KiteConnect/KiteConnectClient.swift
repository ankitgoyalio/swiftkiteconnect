import Foundation

/// A Kite Connect v3 client for an authenticated session owned by the caller.
public struct KiteConnectClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://api.kite.trade")!

    let rest: RESTClient

    public init(
        apiKey: String,
        accessToken: String,
        baseURL: URL = Self.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.rest = RESTClient(apiKey: apiKey, accessToken: accessToken, baseURL: baseURL, session: session)
    }

    /// Retrieves the user profile associated with the Access Token.
    public func profile() async throws -> UserProfile {
        try await rest.send(.init(.get, path: ["user", "profile"]))
    }
}
