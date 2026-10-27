import Foundation

/// A structurally decoded postback whose documented checksum has been checked.
/// The checksum binds only order ID and original timestamp, not the remaining order fields.
public struct KitePostback: Sendable, Equatable {
  public let userID: String
  public let appID: Int64
  public let order: KiteOrderUpdate
}

/// Local configuration and checksum failures. Malformed payloads throw `DecodingError`.
public enum KitePostbackError: Error, Sendable, Equatable {
  /// The backend must supply a nonempty API secret.
  case invalidSecret
  /// The checksum is malformed or does not match the ID, original timestamp and secret.
  case invalidChecksum
}

/// Backend helpers for raw JSON HTTP bodies. The application owns its HTTP server.
public enum KitePostbacks {
  /// Decodes a raw JSON request body and verifies its lowercase SHA-256 checksum.
  /// Keep the secret on the backend. The application owns HTTP ingress, user/app routing,
  /// replay handling and reconciliation; checksum success is not proof of execution.
  /// Offsetless timestamps use the supplied trading timezone, never the device timezone.
  public static func decode(
    _ payload: Data, apiSecret: String,
    tradingTimeZone: TimeZone = TimeZone(identifier: "Asia/Kolkata")!
  ) throws -> KitePostback {
    guard !apiSecret.isEmpty else { throw KitePostbackError.invalidSecret }
    let envelope = try KiteTimestamp.decoder(timeZone: tradingTimeZone)
      .decode(PostbackEnvelope.self, from: payload)
    let expected = KiteChecksum.sha256(
      envelope.order.orderID + envelope.order.orderTimestampRaw + apiSecret)
    // Compare every byte for equal-length digests rather than exiting at the first mismatch.
    let receivedBytes = Array(envelope.checksum.utf8)
    let expectedBytes = Array(expected.utf8)
    guard receivedBytes.count == expectedBytes.count else {
      throw KitePostbackError.invalidChecksum
    }
    var difference: UInt8 = 0
    for (received, expected) in zip(receivedBytes, expectedBytes) {
      difference |= received ^ expected
    }
    guard difference == 0 else { throw KitePostbackError.invalidChecksum }
    return KitePostback(userID: envelope.userID, appID: envelope.appID, order: envelope.order)
  }
}

private struct PostbackEnvelope: Decodable {
  let userID: String
  let appID: Int64
  let order: KiteOrderUpdate
  let checksum: String

  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case appID = "app_id"
    case unfilledQuantity = "unfilled_quantity"
    case checksum
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    userID = try container.decode(String.self, forKey: .userID)
    appID = try container.decode(Int64.self, forKey: .appID)
    checksum = try container.decode(String.self, forKey: .checksum)
    let unfilledQuantity = try container.decode(Int64.self, forKey: .unfilledQuantity)
    guard !userID.isEmpty, appID >= 0, unfilledQuantity >= 0 else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Expected a nonempty user ID and nonnegative app ID and quantity"))
    }
    order = try KiteOrderUpdate(from: decoder)
  }
}
