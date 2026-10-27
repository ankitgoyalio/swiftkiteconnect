import Foundation
import KiteConnect
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import NIOWebSocket
import Testing
import WebSocketKit

/// Public, disposable self-signed fixture key: never use it outside loopback tests.
/// Verify real TLS negotiation rejects untrusted peers without adding an insecure SDK mode.
@Test(.timeLimit(.minutes(1))) func realLocalTLSRejectsUntrustedHTTPAndWebSocketPeer() async throws
{
  let certificate = try #require(
    Bundle.module.url(forResource: "localhost-cert", withExtension: "pem", subdirectory: "Fixtures")
  )
  let key = try #require(
    Bundle.module.url(forResource: "localhost-key", withExtension: "pem", subdirectory: "Fixtures"))
  let certificates = try NIOSSLCertificate.fromPEMFile(certificate.path)
  let configuration = TLSConfiguration.makeServerConfiguration(
    certificateChain: certificates.map { .certificate($0) },
    privateKey: .privateKey(try NIOSSLPrivateKey(file: key.path, format: .pem)))
  let context = try NIOSSLContext(configuration: configuration)
  let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
    do {
      try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: context))
      let upgrader = NIOWebSocketServerUpgrader(
        shouldUpgrade: { channel, _ in channel.eventLoop.makeSucceededFuture([:]) },
        upgradePipelineHandler: { channel, _ in
          WebSocket.server(on: channel) { _ in }
        })
      return channel.pipeline.configureHTTPServerPipeline(
        withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in })
      ).flatMap { channel.pipeline.addHandler(TLSProfileResponder()) }
    } catch { return channel.eventLoop.makeFailedFuture(error) }
  }.bind(host: "127.0.0.1", port: 0).get()
  do {
    let port = try #require(server.localAddress?.port)
    await #expect(throws: KiteTickerError.self) {
      _ = try await NIOKiteWebSocketTransport(connectTimeout: 2).connect(
        url: URL(string: "wss://localhost:\(port)/")!)
    }
    let client = try KiteClient(
      apiKey: "local", accessToken: "local",
      configuration: KiteConfiguration(
        baseURL: URL(string: "https://localhost:\(port)")!, timeout: 2))
    do {
      _ = try await client.profile()
      Issue.record("Untrusted TLS peer must not return a profile")
    } catch KiteError.transport {
      // Certificate validation failed through the public seam.
    }
    try await server.close().get()
    try await group.shutdownGracefully()
  } catch {
    try? await server.close().get()
    try? await group.shutdownGracefully()
    throw error
  }
}

// A working HTTPS/WSS peer: bypassing trust would succeed, so a timeout-only
// server cannot accidentally make the negative certificate test pass.
private final class TLSProfileResponder: ChannelInboundHandler, Sendable {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    guard case .end = unwrapInboundIn(data) else { return }
    var body = context.channel.allocator.buffer(capacity: profileJSON.utf8.count)
    body.writeString(profileJSON)
    let headers = HTTPHeaders([
      ("Content-Type", "application/json"), ("Content-Length", String(body.readableBytes)),
    ])
    context.write(
      wrapOutboundOut(.head(.init(version: .http1_1, status: .ok, headers: headers))), promise: nil)
    context.write(wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
    context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
  }
}
