import Foundation

extension KiteClient {
  /// Applications own browser presentation, registered redirect handling and credential storage.
  /// Pass the sandbox login endpoint explicitly when using `KiteConfiguration.sandbox`.
  public nonisolated func loginURL(
    redirectParameters: String? = nil,
    endpoint: URL = URL(string: "https://kite.zerodha.com/connect/login")!
  ) throws -> URL {
    guard endpoint.scheme == "https", endpoint.host != nil, endpoint.user == nil,
      endpoint.password == nil, endpoint.query == nil, endpoint.fragment == nil,
      var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
    else {
      throw KiteError.validation(
        field: "endpoint",
        message: "Expected an HTTPS login URL without credentials, query or fragment")
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

/// Authentication response. Treat every token as sensitive; the SDK does not persist it.
public struct KiteSession: Sendable {
  public let profile: KiteUserProfile
  public let apiKey: String
  public let accessToken: String
  public let publicToken: String
  /// Usually empty. Long-standing read permissions require platform approval from Kite.
  public let refreshToken: String
  public let loginTime: Date
}

extension KiteClient {
  /// Exchange a short-lived, one-time request token. Distributed apps must run this on a backend.
  /// Installs the returned access token only after the complete response has been validated.
  public func exchangeRequestToken(_ requestToken: String, apiSecret: String) async throws
    -> KiteSession
  {
    try Self.validateAuthenticationValue(requestToken, field: "requestToken")
    try Self.validateAuthenticationValue(apiSecret, field: "apiSecret")
    let revision = sessionRevision
    let wire = try await execute(
      KiteRequest(
        method: .post, path: "/session/token",
        body: .form([
          .init("api_key", apiKey), .init("request_token", requestToken),
          .init("checksum", KiteChecksum.sha256(apiKey + requestToken + apiSecret)),
        ]), authenticated: false), as: SessionWire.self)
    guard wire.apiKey == apiKey else {
      throw KiteError.decoding(statusCode: 200, message: "Session API key does not match client")
    }
    let loginTime = KiteTimestamp.parse(wire.loginTime, timeZone: configuration.tradingTimeZone)
    guard let loginTime else {
      throw KiteError.decoding(statusCode: 200, message: "Invalid session login_time")
    }
    try Self.validateCredential(wire.accessToken, field: "accessToken")
    let session = KiteSession(
      profile: wire.profile, apiKey: wire.apiKey, accessToken: wire.accessToken,
      publicToken: wire.publicToken, refreshToken: wire.refreshToken, loginTime: loginTime)
    guard sessionRevision == revision else {
      throw KiteError.validation(
        field: "session", message: "Session changed while authentication was in flight")
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

/// Minimal refresh response contract: the official SDK guarantees a new access token.
public struct KiteSessionRenewal: Decodable, Sendable {
  public let accessToken: String
  public let refreshToken: String?
  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
  }
}

extension KiteClient {
  /// Backend only, for platforms approved by Kite for refresh tokens. Never renews automatically.
  /// Route and checksum follow the official Python SDK; not fully described in the user snapshot.
  public func renewSession(refreshToken: String, apiSecret: String) async throws
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
        ]), authenticated: false), as: KiteSessionRenewal.self)
    try Self.validateCredential(session.accessToken, field: "accessToken")
    guard sessionRevision == revision else {
      throw KiteError.validation(
        field: "session", message: "Session changed while authentication was in flight")
    }
    try replaceAccessToken(session.accessToken)
    return session
  }
}

extension KiteClient {
  /// Revoke the installed session. Only a confirmed `true` clears the matching local credentials.
  /// Does not log the user out of official Kite apps. Already transmitted work may still complete.
  @discardableResult public func invalidateSession() async throws -> Bool {
    guard let token = accessToken else {
      throw KiteError.validation(
        field: "accessToken", message: "An authenticated session is required")
    }
    let revision = sessionRevision
    let invalidated = try await execute(
      KiteRequest(
        method: .delete, path: "/session/token",
        query: [
          .init("api_key", apiKey), .init("access_token", token),
        ]), as: Bool.self)
    if invalidated && sessionRevision == revision { try replaceAccessToken(nil) }
    return invalidated
  }
}

extension KiteClient {
  /// Approved-platform SDK-reference operation; revokes a refresh token without clearing local access credentials.
  @discardableResult public func invalidateRefreshToken(_ refreshToken: String) async throws -> Bool
  {
    try Self.validateAuthenticationValue(refreshToken, field: "refreshToken")
    return try await execute(
      KiteRequest(
        method: .delete, path: "/session/token",
        query: [
          .init("api_key", apiKey), .init("refresh_token", refreshToken),
        ], authenticated: false), as: Bool.self)
  }
}

extension KiteClient {
  private static func validateAuthenticationValue(_ value: String, field: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw KiteError.validation(field: field, message: "Must be nonempty")
    }
  }
}
