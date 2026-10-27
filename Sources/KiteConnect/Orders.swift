import Foundation

extension KiteClient {
  /// Retrieve all order states for the current trading day, including open and executed orders.
  public func orders() async throws -> [KiteOrder] {
    try await orderRead(path: "/orders", as: [KiteOrder].self)
  }

  /// Inspect a caller-supplied order ID without first placing an order through this client.
  /// History and the order book are transient, retained by Kite for the trading day.
  public func orderHistory(orderID: String) async throws -> [KiteOrder] {
    try validateOrderID(orderID)
    return try await orderRead(path: "/orders/" + orderID, as: [KiteOrder].self)
  }

  /// Retrieve all executions for the trading day, retaining each partial fill separately.
  public func trades() async throws -> [KiteTrade] {
    try await orderRead(path: "/trades", as: [KiteTrade].self)
  }

  /// Retrieve executions for an externally supplied order ID; no write API is required.
  public func orderTrades(orderID: String) async throws -> [KiteTrade] {
    try validateOrderID(orderID)
    return try await orderRead(path: "/orders/" + orderID + "/trades", as: [KiteTrade].self)
  }

  private func validateOrderID(_ value: String) throws {
    guard !value.isEmpty, !value.contains(".."),
      !value.contains(where: { $0.isWhitespace || $0.isNewline || "/\\?#".contains($0) }),
      !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else {
      throw KiteError.validation(
        field: "orderID",
        message:
          "Expected a nonempty order ID path component without whitespace, traversal, or URL delimiters"
      )
    }
  }

  private func orderRead<Value: Decodable & Sendable>(path: String, as type: Value.Type)
    async throws -> Value
  {
    let response = try await response(for: KiteRequest(path: path))
    do {
      let result = try KiteTimestamp.decoder(timeZone: configuration.tradingTimeZone)
        .decode(OrderReadEnvelope<Value>.self, from: response.body)
      guard result.status == "success" else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: [], debugDescription: "Expected success envelope"))
      }
      return result.data
    } catch {
      throw KiteError.decoding(
        statusCode: response.statusCode, message: "Malformed order response: \(error)")
    }
  }
}
private struct OrderReadEnvelope<Value: Decodable>: Decodable {
  let status: String
  let data: Value
}
