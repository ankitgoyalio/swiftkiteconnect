//
//  NIOKiteWebSocketTransport.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import NIOWebSocket
import Synchronization
import WebSocketKit

/// SwiftNIO/WebSocketKit adapter; see Verification.md for executed platform evidence.
/// Each connection owns one event loop and socket, and releases both on close/cancellation.
/// TLS verifies certificates and hostnames. Private origins may supply explicit trust anchors.
public struct NIOKiteWebSocketTransport: KiteWebSocketTransport {
    public let connectTimeout: TimeInterval
    public let incomingBufferCapacity: Int
    /// Optional PEM trust anchors replace system roots for this transport only.
    /// Certificate-chain and hostname verification remain enabled.
    public let trustRootsPEM: Data?
    public init(connectTimeout: TimeInterval = 15, incomingBufferCapacity: Int = 1024,
                trustRootsPEM: Data? = nil)
    {
        self.connectTimeout = connectTimeout
        self.incomingBufferCapacity = incomingBufferCapacity
        self.trustRootsPEM = trustRootsPEM
    }

    public func connect(url: URL) async throws -> any KiteWebSocketConnection {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme, ["ws", "wss"].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              parts.fragment == nil, connectTimeout.isFinite, connectTimeout > 0,
              connectTimeout <= 3600, incomingBufferCapacity > 0
        else {
            throw KiteTickerError.invalidConfiguration("Invalid WebSocket endpoint or transport bounds")
        }
        try Task.checkCancellation()
        let connection = NIOKiteConnection(capacity: incomingBufferCapacity, trustRootsPEM: trustRootsPEM)
        let socket = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                connection.start(parts: parts, timeout: connectTimeout, continuation: continuation)
            }
        } onCancel: {
            connection.stop(CancellationError())
        }
        if Task.isCancelled {
            await socket.close()
            throw CancellationError()
        }
        return socket
    }
}

private final class NIOKiteConnection: KiteWebSocketConnection {
    let messages: AsyncThrowingStream<KiteWebSocketMessage, any Error>
    private let incoming: AsyncThrowingStream<KiteWebSocketMessage, any Error>.Continuation
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private struct State {
        var socket: WebSocket?
        var channel: any Channel?
        var pending: CheckedContinuation<any KiteWebSocketConnection, any Error>?
        var stopped = false
        var shutdown: Task<Void, Never>?
    }

    private let state = Mutex(State())
    private let trustRootsPEM: Data?
    init(capacity: Int, trustRootsPEM: Data?) {
        self.trustRootsPEM = trustRootsPEM
        (messages, incoming) = AsyncThrowingStream.makeStream(
            bufferingPolicy: .bufferingOldest(capacity),
        )
    }

    func start(
        parts: URLComponents, timeout: TimeInterval,
        continuation: CheckedContinuation<any KiteWebSocketConnection, any Error>,
    ) {
        let active = state.withLock { state in
            guard !state.stopped else { return false }
            state.pending = continuation
            return true
        }
        guard active else {
            continuation.resume(throwing: CancellationError())
            return
        }
        let deadline = group.next().scheduleTask(in: .milliseconds(Int64(timeout * 1000))) {
            [weak self] in
            self?.stop(KiteTickerError.transport("WebSocket connection timed out"))
        }
        ClientBootstrap(group: group).connectTimeout(.milliseconds(Int64(timeout * 1000)))
            .channelInitializer { [self] channel in
                let active = state.withLock { state in
                    guard !state.stopped else { return false }
                    state.channel = channel
                    return true
                }
                guard active else { return channel.close() }
                do {
                    if parts.scheme == "wss" {
                        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
                        if let trustRootsPEM {
                            let roots = try NIOSSLCertificate.fromPEMBytes(Array(trustRootsPEM))
                            guard !roots.isEmpty else {
                                throw KiteTickerError.invalidConfiguration("PEM trust anchors must contain a certificate")
                            }
                            tlsConfiguration.trustRoots = .certificates(roots)
                        }
                        let context = try NIOSSLContext(configuration: tlsConfiguration)
                        // Literal IP addresses cannot be sent as SNI. NIOSSL still checks the
                        // peer certificate against the connected IP when no DNS name is supplied.
                        let host = parts.host!
                        let serverName = (try? SocketAddress(ipAddress: host, port: 0)) == nil ? host : nil
                        let tls = try NIOSSLClientHandler(context: context, serverHostname: serverName)
                        try channel.pipeline.syncOperations.addHandler(tls)
                    }
                    let request = KiteUpgradeRequest(
                        parts: parts, fail: { [weak self] error in self?.stop(error) },
                        activated: { [weak self] channel in
                            guard let self else { return }
                            let active = state.withLock { state in
                                guard !state.stopped else { return false }
                                state.channel = channel
                                return true
                            }
                            guard active else { channel.close(promise: nil); return }
                            // A failed DNS candidate is not the end of the connection attempt.
                            // Observe close only after TCP connects, allowing address fallback.
                            channel.closeFuture.whenComplete { [weak self] _ in
                                self?.stop(KiteTickerError.connectionClosed)
                            }
                        },
                    )
                    let key = Data((0 ..< 16).map { _ in UInt8.random(in: .min ... .max) })
                        .base64EncodedString()
                    let upgrader = NIOWebSocketClientUpgrader(requestKey: key, maxFrameSize: 1_048_576) {
                        [self] channel, _ in
                        var config = WebSocket.Configuration()
                        config.maxAccumulatedFrameSize = 1_048_576
                        config.maxAccumulatedFrameCount = 1024
                        return WebSocket.client(on: channel, config: config) { [self] socket in
                            socket.onText { [weak self] _, text in self?.deliver(.text(text)) }
                            socket.onBinary { [weak self] _, bytes in
                                self?.deliver(.binary(Data(bytes.readableBytesView)))
                            }
                            let pending = state.withLock { state in
                                guard !state.stopped else {
                                    return nil as CheckedContinuation<any KiteWebSocketConnection, any Error>?
                                }
                                state.socket = socket
                                defer { state.pending = nil }
                                return state.pending
                            }
                            deadline.cancel()
                            if let pending {
                                pending.resume(returning: self)
                            } else {
                                socket.close(promise: nil)
                            }
                        }
                    }
                    try channel.pipeline.syncOperations.addHTTPClientHandlers(
                        withClientUpgrade: (
                            upgraders: [upgrader],
                            completionHandler: { context in
                                context.pipeline.removeHandler(request, promise: nil)
                            },
                        ),
                    )
                    try channel.pipeline.syncOperations.addHandler(request)
                    return channel.eventLoop.makeSucceededVoidFuture()
                } catch { return channel.eventLoop.makeFailedFuture(error) }
            }.connect(host: parts.host!, port: parts.port ?? (parts.scheme == "wss" ? 443 : 80))
            .whenFailure { [weak self] _ in
                self?.stop(KiteTickerError.transport("WebSocket connection failed"))
            }
    }

    private func deliver(_ message: KiteWebSocketMessage) {
        if case .dropped = incoming.yield(message) {
            stop(KiteTickerError.bufferOverflow)
        }
    }

    func send(text: String) async throws {
        try Task.checkCancellation()
        guard let socket = state.withLock({ $0.stopped ? nil : $0.socket }) else {
            throw KiteTickerError.connectionClosed
        }
        let promise = socket.eventLoop.makePromise(of: Void.self)
        socket.send(text, promise: promise)
        do {
            try await withTaskCancellationHandler {
                try await promise.futureResult.get()
            } onCancel: {
                self.stop(CancellationError())
            }
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw KiteTickerError.transport("WebSocket write failed")
        }
        try Task.checkCancellation()
    }

    func close() async {
        stop(nil)
        let shutdown = state.withLock { $0.shutdown }
        await shutdown?.value
    }

    func stop(_ error: any Error?) {
        let actions = state.withLock {
            state -> (
                CheckedContinuation<any KiteWebSocketConnection, any Error>?, WebSocket?, any Channel?,
            )? in
            guard !state.stopped else { return nil }
            state.stopped = true
            let actions = (state.pending, state.socket, state.channel)
            state.pending = nil
            state.socket = nil
            state.channel = nil
            state.shutdown = Task { [group] in
                await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                    group.shutdownGracefully { _ in done.resume() }
                }
            }
            return actions
        }
        guard let (pending, socket, channel) = actions else { return }
        if let error {
            incoming.finish(throwing: error)
        } else {
            incoming.finish()
        }
        pending?.resume(throwing: error ?? CancellationError())
        // Channel close callbacks may execute synchronously. Never invoke them under the mutex.
        socket?.close(promise: nil)
        channel?.close(promise: nil)
    }
}

/// Confined to its channel's event loop. Owns no continuation or NIO promise, so early
/// EOF, timeout and cancellation cannot strand an unresolved HTTP upgrade future.
private final class KiteUpgradeRequest: ChannelInboundHandler, RemovableChannelHandler, Sendable {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClientRequestPart
    let parts: URLComponents
    let fail: @Sendable (any Error) -> Void
    let activated: @Sendable (any Channel) -> Void
    init(parts: URLComponents, fail: @escaping @Sendable (any Error) -> Void,
         activated: @escaping @Sendable (any Channel) -> Void)
    {
        self.parts = parts
        self.fail = fail
        self.activated = activated
    }

    func channelActive(context: ChannelHandlerContext) {
        activated(context.channel)
        let host = parts.host!
        var headers = HTTPHeaders()
        headers.add(name: "Host", value: host + (parts.port.map { ":\($0)" } ?? ""))
        let path = parts.percentEncodedPath.isEmpty ? "/" : parts.percentEncodedPath
        let uri = path + (parts.percentEncodedQuery.map { "?" + $0 } ?? "")
        context.write(
            wrapOutboundOut(
                .head(HTTPRequestHead(version: .http1_1, method: .GET, uri: uri, headers: headers)),
            ),
            promise: nil,
        )
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        if case let .head(head) = unwrapInboundIn(data) {
            fail(KiteTickerError.handshakeRejected(statusCode: Int(head.status.code)))
        }
        context.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error _: any Error) {
        fail(KiteTickerError.transport("WebSocket handshake failed"))
        context.close(promise: nil)
    }
}
