//
//  KiteTickerTypes.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// One complete inbound WebSocket message, before market-data or text-event decoding.
public enum KiteWebSocketMessage: Sendable, Equatable {
    /// A binary market-data frame, including heartbeat frames.
    case binary(Data)
    /// A text frame containing an order update or broker notification.
    case text(String)
}

/// A single connection. Messages must be ordered and bounded; overflow must fail explicitly.
/// Closing must release the socket and finish messages. No retries belong at this boundary.
public protocol KiteWebSocketConnection: Sendable {
    /// Ordered inbound messages with bounded storage. Overflow must finish with an error.
    var messages: AsyncThrowingStream<KiteWebSocketMessage, any Error> { get }
    /// Sends one text command or throws a transport or cancellation error.
    /// - Parameter text: The complete JSON command to send.
    /// - Throws: A transport error if submission fails, or a cancellation error.
    ///   A failed write can leave server subscription state uncertain.
    func send(text: String) async throws
    /// Releases the socket and finishes messages. Must complete cleanup before returning.
    func close() async
}

/// Creates an independent connection for each call; implementations must honor cancellation.
public protocol KiteWebSocketTransport: Sendable {
    /// Opens an independent socket or throws a handshake, transport, or cancellation error.
    /// - Parameter url: The WebSocket URL, including application-supplied credentials.
    /// - Returns: A connection whose lifetime belongs to the caller.
    /// - Throws: A handshake, transport, or cancellation error. A cancelled handshake
    ///   must release any socket it creates before subsequent admission can proceed.
    func connect(url: URL) async throws -> any KiteWebSocketConnection
}

/// Configuration, protocol, lifecycle, and bounded-buffer failures from streaming.
///
/// See <doc:Streaming-recovery> for terminal failures and recovery behavior.
public enum KiteTickerError: Error, Sendable, Equatable {
    /// A local value violates ticker or transport bounds. The string explains the constraint.
    case invalidConfiguration(String)
    /// Credentials are missing or rejected. Recovery waits for replacement credentials.
    case authenticationRequired
    /// A subscription command requires an active ticker lifecycle.
    case notConnected
    /// Connect was called while the ticker was active, including recovery.
    case alreadyConnected
    /// Another subscription command is suspended. Serialize commands at the call site.
    case operationInProgress
    /// A text event cannot decode with its required structure. This ends event streams.
    case malformedText
    /// A binary message has invalid framing or fields. This ends event streams.
    case malformedPacket
    /// A binary packet has an unsupported byte length. This ends event streams.
    case unsupportedPacketLength(Int)
    /// A bounded subscriber or transport ingress cannot retain another event.
    /// Subscriber overflow ends only that subscriber. Ingress overflow fails the connection.
    case bufferOverflow
    /// The inbound message stream ended without an explicit ticker disconnect.
    case connectionClosed
    /// The server rejected the WebSocket upgrade with this HTTP status.
    /// Statuses 401 and 403 block automatic recovery until credentials change.
    case handshakeRejected(statusCode: Int)
    /// A transport operation failed. The string describes the underlying failure.
    case transport(String)
}

/// The instrument token and last price projected from any supported market-data layout.
public struct KiteLTPTick: Sendable, Equatable {
    /// The subscription identifier. Tokens can be reused after derivative expiry.
    public let instrumentToken: UInt32
    /// The last traded price in price units after segment-specific wire scaling.
    public let lastPrice: Decimal
}
