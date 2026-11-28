/// The profile and trading capabilities of an authenticated Kite user.
public struct UserProfile: Decodable, Equatable, Sendable {
    public let userID: String
    public let userType: String
    public let email: String
    public let userName: String
    public let userShortName: String
    public let broker: String
    public let exchanges: [String]
    public let products: [String]
    public let orderTypes: [String]
    public let avatarURL: String?
    public let meta: Metadata

    public struct Metadata: Decodable, Equatable, Sendable {
        public let dematConsent: String

        private enum CodingKeys: String, CodingKey {
            case dematConsent = "demat_consent"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case userType = "user_type"
        case email
        case userName = "user_name"
        case userShortName = "user_shortname"
        case broker
        case exchanges
        case products
        case orderTypes = "order_types"
        case avatarURL = "avatar_url"
        case meta
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        userID = try values.decode(String.self, forKey: .userID)
        userType = try values.decode(String.self, forKey: .userType)
        email = try values.decode(String.self, forKey: .email)
        userName = try values.decode(String.self, forKey: .userName)
        userShortName = try values.decode(String.self, forKey: .userShortName)
        broker = try values.decode(String.self, forKey: .broker)
        exchanges = try values.decodeIfPresent([String].self, forKey: .exchanges) ?? []
        products = try values.decodeIfPresent([String].self, forKey: .products) ?? []
        orderTypes = try values.decodeIfPresent([String].self, forKey: .orderTypes) ?? []
        avatarURL = try values.decodeIfPresent(String.self, forKey: .avatarURL)
        meta = try values.decode(Metadata.self, forKey: .meta)
    }
}
