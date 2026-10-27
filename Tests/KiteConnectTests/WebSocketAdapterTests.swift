import Foundation
import KiteConnect
import Testing

@Test func webSocketAdapterRejectsInvalidEndpointsWithoutNetworking() async throws {
  let adapter = NIOKiteWebSocketTransport()
  await #expect(throws: KiteTickerError.self) {
    _ = try await adapter.connect(url: URL(string: "https://127.0.0.1")!)
  }
}
