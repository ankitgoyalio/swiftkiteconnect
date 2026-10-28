import Foundation

/// Newly enabled exchanges, products and order types survive decoding through open enums.
public struct KiteUserProfile: Decodable, Sendable, Equatable {
  public let userID: String
  public let userType: String
  public let email: String
  public let userName: String
  public let userShortname: String
  public let broker: String
  public let exchanges: [KiteExchange]
  public let products: [KiteProduct]
  public let orderTypes: [KiteOrderType]
  public let avatarURL: String?
  public let meta: Metadata
  public struct Metadata: Decodable, Sendable, Equatable {
    public let dematConsent: String
    enum CodingKeys: String, CodingKey { case dematConsent = "demat_consent" }
  }
  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case userType = "user_type"
    case email
    case userName = "user_name"
    case userShortname = "user_shortname"
    case broker, exchanges, products
    case orderTypes = "order_types"
    case avatarURL = "avatar_url"
    case meta
  }
}
