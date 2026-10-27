import Foundation

/// Non-order text notifications. Server errors are delivered as values: the documented
/// payload is a string. Explicit credential/session failures also stop ticker recovery.
public enum KiteBrokerEvent: Sendable, Equatable {
  case message(String)
  case serverError(String)
  case unknown(type: String, data: KiteOrderMetadata)
}

enum KiteTextEvent: Decodable {
  case order(KiteOrderUpdateEvent)
  case broker(KiteBrokerEvent)

  enum CodingKeys: String, CodingKey { case type, data }
  init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let type = try c.decode(String.self, forKey: .type)
    switch type {
    case "order": self = .order(try c.decode(KiteOrderUpdateEvent.self, forKey: .data))
    case "message": self = .broker(.message(try c.decode(String.self, forKey: .data)))
    case "error": self = .broker(.serverError(try c.decode(String.self, forKey: .data)))
    default:
      self = .broker(
        .unknown(type: type, data: try c.decode(KiteOrderMetadata.self, forKey: .data)))
    }
  }
}
