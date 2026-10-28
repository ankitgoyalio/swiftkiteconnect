//
//  TrustedWebSocketTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import NIOWebSocket
import Testing
import WebSocketKit

/// Disposable fixture CA and keys are public test material. No system trust changes.
/// A DNS-only leaf also proves that trusting its CA does not disable hostname checks.
@Test(.timeLimit(.minutes(1)), arguments: ["localhost", "127.0.0.1", "[::1]"])
func `trusted local web socket verifies chain hostname and carries ticks`(host: String) async throws {
    let literalIP = host != "localhost"
    let ipv6 = host == "[::1]"
    let ca = try fixtureData("localhost-cert")
    let leaf = try ipv6 ? fixtureData("trusted-ipv6-cert") : (literalIP ? ca : fixtureData("trusted-localhost-cert"))
    let key = try #require(Bundle.module.url(forResource: literalIP && !ipv6 ? "localhost-key" : "trusted-localhost-key", withExtension: "pem", subdirectory: "Fixtures"))
    let certificates = try NIOSSLCertificate.fromPEMBytes(Array(leaf))
    let tls = try TLSConfiguration.makeServerConfiguration(
        certificateChain: certificates.map { .certificate($0) },
        privateKey: .privateKey(NIOSSLPrivateKey(file: key.path, format: .pem)),
    )
    let context = try NIOSSLContext(configuration: tls)
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
        do {
            try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: context))
            let upgrader = NIOWebSocketServerUpgrader(
                shouldUpgrade: { channel, _ in channel.eventLoop.makeSucceededFuture([:]) },
                upgradePipelineHandler: { channel, _ in
                    WebSocket.server(on: channel) { socket in
                        socket.onText { socket, text in
                            if text.contains("mode") {
                                socket.send([UInt8](arrayLiteral: 0, 1, 0, 8, 0, 6, 58, 1, 0, 0, 48, 57))
                            }
                        }
                    }
                },
            )
            return channel.pipeline.configureHTTPServerPipeline(
                withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in }),
            )
        } catch { return channel.eventLoop.makeFailedFuture(error) }
    }.bind(host: ipv6 ? "::1" : "127.0.0.1", port: 0).get()
    do {
        let port = try #require(server.localAddress?.port)
        let transport = NIOKiteWebSocketTransport(connectTimeout: 2, trustRootsPEM: ca)
        if !literalIP {
            // Correct CA but wrong hostname: the DNS-only leaf has no IP SAN.
            await #expect(throws: KiteTickerError.self) {
                _ = try await transport.connect(url: #require(URL(string: "wss://127.0.0.1:\(port)/")))
            }
        }
        // Malformed explicit roots must never fall back to default trust.
        await #expect(throws: KiteTickerError.self) {
            _ = try await NIOKiteWebSocketTransport(connectTimeout: 2, trustRootsPEM: Data("invalid".utf8))
                .connect(url: #require(URL(string: "wss://\(host):\(port)/")))
        }
        // Valid hostname without its CA must still fail.
        await #expect(throws: KiteTickerError.self) {
            _ = try await NIOKiteWebSocketTransport(connectTimeout: 2).connect(
                url: #require(URL(string: "wss://\(host):\(port)/")),
            )
        }
        let ticker = try KiteTicker(apiKey: "local", accessToken: "local",
                                    endpoint: #require(URL(string: "wss://\(host):\(port)/")), transport: transport)
        let stream = try await ticker.ticks()
        do {
            try await ticker.connect()
            try await ticker.subscribe([408_065])
            var ticks = stream.makeAsyncIterator()
            #expect(try await ticks.next()?.lastPrice == Decimal(string: "123.45"))
            await ticker.disconnect()
            #expect(try await ticks.next() == nil)
        } catch {
            await ticker.disconnect()
            throw error
        }
        try await server.close().get()
        try await group.shutdownGracefully()
    } catch {
        try? await server.close().get()
        try? await group.shutdownGracefully()
        throw error
    }
}

private func fixtureData(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "pem", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

/// Initializer failures can finish before a Happy Eyeballs bootstrap settles.
/// Every public connect failure must drain that work before its event loop exits.
@Test(.timeLimit(.minutes(1)))
func `concurrent TLS initializer failures drain bootstrap work`() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let server = try await ServerBootstrap(group: group).bind(host: "127.0.0.1", port: 0).get()
    do {
        let port = try #require(server.localAddress?.port)
        let url = try #require(URL(string: "wss://localhost:\(port)/"))
        await withTaskGroup(of: Void.self) { tasks in
            for _ in 0 ..< 64 {
                tasks.addTask {
                    await #expect(throws: KiteTickerError.self) {
                        _ = try await NIOKiteWebSocketTransport(connectTimeout: 2,
                                                                trustRootsPEM: Data("invalid".utf8)).connect(url: url)
                    }
                }
            }
        }
        try await server.close().get()
        try await group.shutdownGracefully()
    } catch {
        try? await server.close().get()
        try? await group.shutdownGracefully()
        throw error
    }
}
