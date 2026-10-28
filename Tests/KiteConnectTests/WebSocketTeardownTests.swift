//
//  WebSocketTeardownTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation
import KiteConnect
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOWebSocket
import Testing
import WebSocketKit

@Test(.timeLimit(.minutes(1)))
func `real socket concurrent writes and close always settle`() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let server = try await ServerBootstrap(group: group).childChannelInitializer { channel in
        let upgrader = NIOWebSocketServerUpgrader(
            shouldUpgrade: { channel, _ in channel.eventLoop.makeSucceededFuture([:]) },
            upgradePipelineHandler: { channel, _ in WebSocket.server(on: channel) { _ in } },
        )
        return channel.pipeline.configureHTTPServerPipeline(
            withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in }),
        )
    }.bind(host: "127.0.0.1", port: 0).get()
    do {
        let port = try #require(server.localAddress?.port)
        let url = try #require(URL(string: "ws://127.0.0.1:\(port)/"))
        for _ in 0 ..< 100 {
            let connection = try await NIOKiteWebSocketTransport(connectTimeout: 2).connect(url: url)
            await withTaskGroup(of: Void.self) { tasks in
                for _ in 0 ..< 32 {
                    tasks.addTask { try? await connection.send(text: "race") }
                }
                tasks.addTask { await connection.close() }
            }
            await connection.close()
            await #expect(throws: KiteTickerError.connectionClosed) {
                try await connection.send(text: "after close")
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
