/// The credentials and user profile returned by a successful Request Token exchange.
public struct UserSession: Decodable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let profile: UserProfile
    public let apiKey: String
    public let accessToken: String
    public let publicToken: String
    /// Available only to integrations with refresh-token access.
    public let refreshToken: String?
    /// The login time reported by Kite in its original format.
    public let loginTime: String

    public var description: String { "UserSession(credentials: <redacted>)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:], displayStyle: .struct) }

    private enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case accessToken = "access_token"
        case publicToken = "public_token"
        case refreshToken = "refresh_token"
        case loginTime = "login_time"
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        profile = try UserProfile(from: decoder)
        apiKey = try values.decode(String.self, forKey: .apiKey)
        accessToken = try values.decode(String.self, forKey: .accessToken)
        publicToken = try values.decode(String.self, forKey: .publicToken)
        let refreshToken = try values.decodeIfPresent(String.self, forKey: .refreshToken)
        self.refreshToken = refreshToken == "" ? nil : refreshToken
        loginTime = try values.decode(String.self, forKey: .loginTime)
    }
}
