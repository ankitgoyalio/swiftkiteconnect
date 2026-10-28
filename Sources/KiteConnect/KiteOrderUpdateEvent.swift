import Foundation

/// A WebSocket postback with shared order state and delivery metadata. This decodes
/// the flat postback payload, never a REST order envelope or the stricter KiteOrder.
/// Checksum is preserved only; HTTP postback authentication belongs to the postback helper.
public struct KiteOrderUpdateEvent: Decodable, Sendable, Equatable {
  public let update: KiteOrderUpdate
  public let userID: String
  public let appID: Int64?
  public let checksum: String?

  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case appID = "app_id"
    case checksum
  }
  public init(from decoder: any Decoder) throws {
    update = try KiteOrderUpdate(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    userID = try c.decode(String.self, forKey: .userID)
    appID = try c.decodeIfPresent(Int64.self, forKey: .appID)
    checksum = try c.decodeIfPresent(String.self, forKey: .checksum)
    guard !update.orderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      update.instrumentToken > 0
    else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath, debugDescription: "Invalid streaming order identifier"))
    }
  }
}
