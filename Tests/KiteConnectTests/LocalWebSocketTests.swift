import Foundation
import KiteConnect
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOWebSocket
import Testing
import WebSocketKit

/// Real HTTP upgrade, client-masked text writes, server binary/text frames and close handshake.
/// Runs unchanged on macOS, iOS Simulator, and Ubuntu 24.04; no Kite hosts or credentials.
@Test(.timeLimit(.minutes(1))) func realLocalWebSocketCarriesLTP() async throws {
  let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let (requests, received) = AsyncStream<String>.makeStream()
  let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
    let upgrader = NIOWebSocketServerUpgrader(
      shouldUpgrade: { channel, request in
        received.yield(request.uri)
        return channel.eventLoop.makeSucceededFuture([:])
      },
      upgradePipelineHandler: { channel, _ in
        WebSocket.server(on: channel) { socket in
          socket.onText { socket, text in
            received.yield(text)
            if text.contains("mode") {
              socket.send([UInt8](arrayLiteral: 0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 48, 57))
            }
          }
        }
      })
    return channel.pipeline.configureHTTPServerPipeline(
      withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in }))
  }.bind(host: "127.0.0.1", port: 0).get()
  do {
    let port = try #require(server.localAddress?.port)
    let ticker = try KiteTicker(
      apiKey: "local-key", accessToken: "local-token",
      endpoint: URL(string: "ws://127.0.0.1:\(port)/ticks")!, transport: NIOKiteWebSocketTransport()
    )
    let ticks = try await ticker.ticks()
    try await ticker.connect()
    try await ticker.subscribe([408065])
    var iterator = ticks.makeAsyncIterator()
    #expect(try await iterator.next()?.lastPrice == Decimal(string: "123.45"))
    await ticker.disconnect()
    #expect(try await iterator.next() == nil)
    var wire = requests.makeAsyncIterator()
    #expect(await wire.next() == "/ticks?api_key=local-key&access_token=local-token")
    #expect(await wire.next()?.contains("subscribe") == true)
    #expect(await wire.next()?.contains("mode") == true)
    try await server.close().get()
    try await group.shutdownGracefully()
  } catch {
    try? await server.close().get()
    try? await group.shutdownGracefully()
    throw error
  }
}

/// A real TCP peer that accepts HTTP but deliberately never completes the WebSocket upgrade.
private final class HoldUpgrade: ChannelInboundHandler, Sendable {
  typealias InboundIn = HTTPServerRequestPart
  let accepted: AsyncStream<Void>.Continuation
  init(_ accepted: AsyncStream<Void>.Continuation) { self.accepted = accepted }
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    if case .head = unwrapInboundIn(data) { accepted.yield(()) }
  }
}

@Test(.timeLimit(.minutes(1))) func webSocketAdapterCancelsPendingRealHandshake() async throws {
  let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let (requests, accepted) = AsyncStream<Void>.makeStream()
  let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
    channel.pipeline.configureHTTPServerPipeline().flatMap {
      channel.pipeline.addHandler(HoldUpgrade(accepted))
    }
  }.bind(host: "127.0.0.1", port: 0).get()
  do {
    let url = URL(string: "ws://127.0.0.1:\(server.localAddress!.port!)/")!
    let connecting = Task { try await NIOKiteWebSocketTransport().connect(url: url) }
    var iterator = requests.makeAsyncIterator()
    _ = await iterator.next()
    connecting.cancel()
    await #expect(throws: CancellationError.self) { _ = try await connecting.value }
    try await server.close().get()
    try await group.shutdownGracefully()
  } catch {
    try? await server.close().get()
    try? await group.shutdownGracefully()
    throw error
  }
}

@Test(.timeLimit(.minutes(1))) func webSocketAdapterTimesOutRealHandshake() async throws {
  let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let (_, accepted) = AsyncStream<Void>.makeStream()
  let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
    channel.pipeline.configureHTTPServerPipeline().flatMap {
      channel.pipeline.addHandler(HoldUpgrade(accepted))
    }
  }.bind(host: "127.0.0.1", port: 0).get()
  do {
    let url = URL(string: "ws://127.0.0.1:\(server.localAddress!.port!)/")!
    await #expect(throws: KiteTickerError.self) {
      _ = try await NIOKiteWebSocketTransport(connectTimeout: 0.1).connect(url: url)
    }
    try await server.close().get()
    try await group.shutdownGracefully()
  } catch {
    try? await server.close().get()
    try? await group.shutdownGracefully()
    throw error
  }
}

private func withLocalWebSocket(
  onUpgrade: @escaping @Sendable (WebSocket) -> Void,
  operation: (URL) async throws -> Void
) async throws {
  let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
    let upgrader = NIOWebSocketServerUpgrader(
      shouldUpgrade: { channel, _ in
        channel.eventLoop.makeSucceededFuture([:])
      },
      upgradePipelineHandler: { channel, _ in
        WebSocket.server(on: channel, onUpgrade: onUpgrade)
      })
    return channel.pipeline.configureHTTPServerPipeline(
      withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in }))
  }.bind(host: "127.0.0.1", port: 0).get()
  do {
    try await operation(URL(string: "ws://127.0.0.1:\(server.localAddress!.port!)/")!)
    try await server.close().get()
    try await group.shutdownGracefully()
  } catch {
    try? await server.close().get()
    try? await group.shutdownGracefully()
    throw error
  }
}

@Test(.timeLimit(.minutes(1))) func realLocalWebSocketReassemblesBinaryAndPreservesText()
  async throws
{
  try await withLocalWebSocket(
    onUpgrade: { socket in
      socket.onText { socket, _ in
        socket.send("broker message")
        socket.send(raw: [UInt8](arrayLiteral: 0, 1, 0, 8, 0, 6), opcode: .binary, fin: false)
        socket.send(
          raw: [UInt8](arrayLiteral: 58, 1, 0, 0, 48, 57), opcode: .continuation, fin: true)
      }
    },
    operation: { url in
      let connection = try await NIOKiteWebSocketTransport().connect(url: url)
      try await connection.send(text: "go")
      var messages = connection.messages.makeAsyncIterator()
      #expect(try await messages.next() == .text("broker message"))
      #expect(try await messages.next() == .binary(Data([0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 48, 57])))
      await connection.close()
      #expect(try await messages.next() == nil)
    })
}

@Test(.timeLimit(.minutes(1))) func webSocketAdapterReportsBoundedIngressOverflow() async throws {
  let (closed, closeSignal) = AsyncStream<Void>.makeStream()
  try await withLocalWebSocket(
    onUpgrade: { socket in
      socket.onClose.whenComplete { _ in closeSignal.yield(()) }
      socket.onText { socket, _ in
        socket.send("first")
        socket.send("overflow")
      }
    },
    operation: { url in
      let connection = try await NIOKiteWebSocketTransport(incomingBufferCapacity: 1).connect(
        url: url)
      try await connection.send(text: "go")
      var peer = closed.makeAsyncIterator()
      _ = await peer.next()
      var messages = connection.messages.makeAsyncIterator()
      #expect(try await messages.next() == .text("first"))
      await #expect(throws: KiteTickerError.bufferOverflow) { _ = try await messages.next() }
      await connection.close()
    })
}

private final class RejectUpgrade: ChannelInboundHandler, Sendable {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    if case .head = unwrapInboundIn(data) {
      let head = HTTPResponseHead(
        version: .http1_1, status: .forbidden, headers: ["Content-Length": "0"])
      context.write(wrapOutboundOut(.head(head)), promise: nil)
      context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
  }
}

@Test(.timeLimit(.minutes(1))) func webSocketAdapterPreservesRejectedHandshakeStatus() async throws
{
  let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
    channel.pipeline.configureHTTPServerPipeline().flatMap {
      channel.pipeline.addHandler(RejectUpgrade())
    }
  }.bind(host: "127.0.0.1", port: 0).get()
  let url = URL(string: "ws://127.0.0.1:\(server.localAddress!.port!)/")!
  await #expect(throws: KiteTickerError.handshakeRejected(statusCode: 403)) {
    _ = try await NIOKiteWebSocketTransport().connect(url: url)
  }
  try await server.close().get()
  try await group.shutdownGracefully()
}

@Test(.timeLimit(.minutes(1))) func webSocketAdapterReportsRemoteDisconnect() async throws {
  try await withLocalWebSocket(
    onUpgrade: { socket in
      socket.onText { socket, _ in socket.close(promise: nil) }
    },
    operation: { url in
      let connection = try await NIOKiteWebSocketTransport().connect(url: url)
      try await connection.send(text: "close")
      var messages = connection.messages.makeAsyncIterator()
      await #expect(throws: KiteTickerError.connectionClosed) { _ = try await messages.next() }
      await connection.close()
    })
}
