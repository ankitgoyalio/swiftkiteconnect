//
//  KiteTicker.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// One explicit WebSocket owner with bounded recovery, without missed-event replay.
///
/// See <doc:Connect-and-consume-streams> for usage and <doc:Streaming-recovery>
/// for subscriber buffers, authentication failures, and application-owned reconciliation.
public actor KiteTicker {
    private var url: URL
    let reconnectPolicy: KiteTickerReconnectPolicy
    let sleeper: any KiteTickerSleeper
    var recovery: Task<Void, Never>?
    var recoveryID = UUID()
    var active = false
    var authenticationBlocked = false
    var modes: [UInt32: KiteTickerMode] = [:]
    var desiredRevision = UUID()
    var lifecycleSubscribers = BoundedSubscribers<KiteTickerLifecycleEvent>()
    let tradingTimeZone: TimeZone
    var brokerSubscribers = BoundedSubscribers<KiteBrokerEvent>()
    var orderSubscribers = BoundedSubscribers<KiteOrderUpdateEvent>()
    private let transport: any KiteWebSocketTransport
    var connection: any KiteWebSocketConnection?
    // Retired handshakes own cleanup of any late socket result. Every new handshake waits
    // for this chain, so detaching actor state never releases physical admission early.
    private var teardown: Task<Void, Never>?
    var receiver: Task<Void, Never>?
    var generation = UUID()
    var connecting = false
    private var connector: Task<any KiteWebSocketConnection, any Error>?
    var subscribers = BoundedSubscribers<KiteLTPTick>()
    var marketSubscribers = BoundedSubscribers<KiteMarketTick>()
    var subscriptions: Set<UInt32> = []
    var commandOperation: UUID?

    /// Creates an explicitly owned ticker without opening a socket.
    ///
    /// - Parameters:
    ///   - apiKey: Nonempty API key for this streaming session.
    ///   - accessToken: Nonempty session token. REST credentials remain independent.
    ///   - userID: Sandbox user identifier, required for `ws-sandbox.kite.trade`.
    ///   - endpoint: A ws or wss URL without user information, query, or fragment.
    ///   - transport: The connection factory. Each ticker owns one connection at a time.
    ///   - tradingTimeZone: Zone for offsetless order-update timestamps. Binary timestamps use Unix seconds.
    ///   - reconnectPolicy: Bounded retry delays and attempts, validated on creation.
    ///   - sleeper: Cancellation-aware delay provider for recovery.
    /// - Throws: ``KiteTickerError/invalidConfiguration(_:)`` for invalid credentials, endpoint, or retry bounds.
    public init(
        apiKey: String, accessToken: String, userID: String? = nil,
        endpoint: URL = URL(string: "wss://ws.kite.trade")!,
        transport: any KiteWebSocketTransport,
        tradingTimeZone: TimeZone = TimeZone(identifier: "Asia/Kolkata")!,
        reconnectPolicy: KiteTickerReconnectPolicy = .init(),
        sleeper: any KiteTickerSleeper = KiteTickerContinuousSleeper(),
    ) throws {
        guard reconnectPolicy.initialDelay > .zero,
              reconnectPolicy.maximumDelay >= reconnectPolicy.initialDelay,
              reconnectPolicy.maximumDelay <= .seconds(3600),
              (0 ... 1000).contains(reconnectPolicy.maximumAttempts)
        else { throw KiteTickerError.invalidConfiguration("Invalid reconnect bounds") }
        guard !apiKey.isEmpty, !accessToken.isEmpty,
              var parts = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              ["ws", "wss"].contains(parts.scheme), parts.host != nil,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil
        else {
            throw KiteTickerError.invalidConfiguration(
                "Supply credentials and a ws/wss endpoint without query or user info",
            )
        }
        if parts.host == "ws-sandbox.kite.trade", userID?.isEmpty != false {
            throw KiteTickerError.invalidConfiguration("Sandbox WebSocket requires user_id")
        }
        parts.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "access_token", value: accessToken),
        ]
        if let userID {
            parts.queryItems?.append(URLQueryItem(name: "user_id", value: userID))
        }
        // HTTP query parsers commonly interpret a literal plus as a space.
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(
            of: "+", with: "%2B",
        )
        self.reconnectPolicy = reconnectPolicy
        self.sleeper = sleeper
        url = parts.url!
        self.transport = transport
        self.tradingTimeZone = tradingTimeZone
    }

    /// Each call creates an independent bounded subscriber. Overflow ends only that subscriber.
    ///
    /// An LTP projection of every decoded market-data layout.
    /// - Parameter bufferCapacity: Positive per-subscriber event capacity.
    /// - Returns: An independent stream. Cancelling its consumer leaves the ticker connected.
    /// - Throws: Invalid configuration for nonpositive capacity. Later overflow throws
    ///   `bufferOverflow` in this subscriber. Disconnect finishes it normally.
    public func ticks(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<KiteLTPTick, any Error> {
        try subscribers.stream(capacity: bufferCapacity) { [weak self] id in
            Task { await self?.removeSubscriber(id) }
        }
    }

    /// Each subscriber receives every binary layout with its own bounded buffer.
    ///
    /// Typed market-data layouts, independent of order updates.
    /// - Parameter bufferCapacity: Positive per-subscriber event capacity.
    /// - Returns: An independent stream. Cancelling its consumer leaves the ticker connected.
    /// - Throws: Invalid configuration for nonpositive capacity. Later overflow throws
    ///   `bufferOverflow` in this subscriber. Disconnect finishes it normally.
    public func marketTicks(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<
        KiteMarketTick, any Error,
    > {
        try marketSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
            Task { await self?.removeMarketSubscriber(id) }
        }
    }

    /// Each call has a bounded buffer independent of all market-data subscribers.
    ///
    /// Order-state notifications, independent of market-data ticks.
    /// - Parameter bufferCapacity: Positive per-subscriber event capacity.
    /// - Returns: An independent stream. Cancelling its consumer leaves the ticker connected.
    /// - Throws: Invalid configuration for nonpositive capacity. Later overflow throws
    ///   `bufferOverflow` in this subscriber. Disconnect finishes it normally.
    public func orderUpdates(bufferCapacity: Int = 256) throws -> AsyncThrowingStream<
        KiteOrderUpdateEvent, any Error,
    > {
        try orderSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
            Task { await self?.removeOrderSubscriber(id) }
        }
    }

    /// Broker notices and errors have their own per-subscriber bounded capacity.
    ///
    /// Broker notices, server errors, and unknown text-event types.
    /// - Parameter bufferCapacity: Positive per-subscriber event capacity.
    /// - Returns: An independent stream. Cancelling its consumer leaves the ticker connected.
    /// - Throws: Invalid configuration for nonpositive capacity. Later overflow throws
    ///   `bufferOverflow` in this subscriber. Disconnect finishes it normally.
    public func brokerEvents(bufferCapacity: Int = 64) throws -> AsyncThrowingStream<
        KiteBrokerEvent, any Error,
    > {
        try brokerSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
            Task { await self?.removeBrokerSubscriber(id) }
        }
    }

    /// Registers an independent bounded stream of connection and recovery transitions.
    ///
    /// - Parameter bufferCapacity: Positive event capacity, independent of data streams.
    /// - Returns: A stream that ends on disconnect or terminal protocol failure.
    /// - Throws: Invalid configuration for nonpositive capacity. Overflow later fails this subscriber.
    public func lifecycleEvents(bufferCapacity: Int = 64) throws -> AsyncThrowingStream<
        KiteTickerLifecycleEvent, any Error,
    > {
        try lifecycleSubscribers.stream(capacity: bufferCapacity) { [weak self] id in
            Task { await self?.removeLifecycleSubscriber(id) }
        }
    }

    private func removeLifecycleSubscriber(_ id: UUID) {
        lifecycleSubscribers.remove(id)
    }

    func emit(_ event: KiteTickerLifecycleEvent) {
        lifecycleSubscribers.yield(event)
    }

    /// Opens the socket and restores desired subscriptions before emitting `connected`.
    ///
    /// The initial failure is thrown even when bounded recovery starts in the background.
    /// Cancellation disconnects this lifecycle. An active or authentication-blocked ticker rejects this call.
    /// See <doc:Connect-and-consume-streams> and <doc:Streaming-recovery>.
    ///
    /// - Throws: A ticker, transport, or cancellation error.
    public func connect() async throws {
        try Task.checkCancellation()
        guard !authenticationBlocked else { throw KiteTickerError.authenticationRequired }
        guard !active else { throw KiteTickerError.alreadyConnected }
        active = true
        let epoch = generation
        do {
            try await establish(epoch: epoch)
            emit(.connected)
        } catch {
            if epoch != generation || Task.isCancelled || error is CancellationError {
                if epoch == generation {
                    await disconnect()
                }
                throw CancellationError()
            }
            await failed(error, epoch: epoch)
            throw error
        }
    }

    /// Replaces this ticker's session, closing the old socket before connecting with new credentials.
    /// Desired subscriptions survive; in-flight old-session work is cancelled and generation-fenced.
    /// If explicitly disconnected, only updates credentials; call connect() to start again.
    /// REST credentials do not change. This clears the authentication recovery block.
    /// - Parameters:
    ///   - apiKey: Nonempty API key for the replacement session.
    ///   - accessToken: Nonempty access token for the replacement session.
    ///   - userID: Required sandbox user identifier when using the sandbox endpoint.
    /// - Throws: Invalid configuration, transport, or cancellation errors.
    public func replaceCredentials(apiKey: String, accessToken: String, userID: String? = nil)
        async throws
    {
        guard !apiKey.isEmpty, !accessToken.isEmpty else {
            throw KiteTickerError.invalidConfiguration("Supply nonempty credentials")
        }
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if parts.host == "ws-sandbox.kite.trade", userID?.isEmpty != false {
            throw KiteTickerError.invalidConfiguration("Sandbox WebSocket requires user_id")
        }
        parts.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "access_token", value: accessToken),
        ]
        if let userID {
            parts.queryItems?.append(URLQueryItem(name: "user_id", value: userID))
        }
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(
            of: "+", with: "%2B",
        )
        url = parts.url!
        let wasActive = active
        let wasBlocked = authenticationBlocked
        authenticationBlocked = false
        generation = UUID()
        let epoch = generation
        recoveryID = UUID()
        recovery?.cancel()
        recovery = nil
        let closing = retireConnection()
        receiver?.cancel()
        receiver = nil
        connecting = wasActive
        commandOperation = nil
        if wasActive, !wasBlocked {
            emit(.possibleDataGap)
        }
        await closing.value
        guard epoch == generation else { throw CancellationError() }
        if Task.isCancelled {
            await disconnect()
            throw CancellationError()
        }
        guard wasActive else { return }
        do {
            try await establish(epoch: epoch)
            emit(.reconnected)
        } catch {
            if epoch != generation || error is CancellationError || Task.isCancelled {
                if epoch == generation {
                    await disconnect()
                }
                throw CancellationError()
            }
            await failed(error, epoch: epoch)
            throw error
        }
    }

    func establish(epoch: UUID) async throws {
        guard epoch == generation, active else { throw CancellationError() }
        if let teardown {
            await teardown.value
        }
        try Task.checkCancellation()
        guard epoch == generation, active else { throw CancellationError() }
        connecting = true
        let pending = Task { [transport, url] in try await transport.connect(url: url) }
        connector = pending
        let socket = try await withTaskCancellationHandler {
            try await pending.value
        } onCancel: {
            pending.cancel()
        }
        guard epoch == generation, !Task.isCancelled, active else {
            // The transition which invalidated this epoch owns late-result cleanup.
            throw CancellationError()
        }
        connector = nil
        // Retain the socket so failure/disconnect/replacement owns any blocked restore cleanup.
        connection = socket
        var sent: Set<UInt32> = []
        repeat {
            let revision = desiredRevision
            let snapshot = modes
            let tokens = Set(snapshot.keys)
            if !sent.subtracting(tokens).isEmpty {
                try await send(
                    command("unsubscribe", sent.subtracting(tokens).sorted()), on: socket, epoch: epoch,
                )
            }
            if !tokens.isEmpty {
                try await send(command("subscribe", tokens.sorted()), on: socket, epoch: epoch)
                for mode in KiteTickerMode.allCases {
                    let group = tokens.filter { snapshot[$0] == mode }.sorted()
                    if !group.isEmpty {
                        try await send(modeCommand(mode, group), on: socket, epoch: epoch)
                    }
                }
            }
            sent = tokens
            if revision == desiredRevision {
                break
            }
        } while true
        guard epoch == generation, active, !Task.isCancelled else {
            throw CancellationError()
        }
        connecting = false
        receiver = Task { [weak self] in
            do {
                for try await message in socket.messages {
                    try Task.checkCancellation()
                    guard let self else { break }
                    try await receive(message, epoch: epoch)
                }
                await self?.failed(KiteTickerError.connectionClosed, epoch: epoch)
            } catch { await self?.failed(error, epoch: epoch) }
        }
    }

    func send(_ text: String, on socket: any KiteWebSocketConnection, epoch: UUID)
        async throws
    {
        guard epoch == generation, active else { throw CancellationError() }
        try Task.checkCancellation()
        try await socket.send(text: text)
        guard epoch == generation, active else { throw CancellationError() }
        try Task.checkCancellation()
    }

    /// Cancels recovery, clears subscriptions, and finishes all registered streams.
    ///
    /// Closes the current socket. Late cancelled handshakes are cleaned up before any new
    /// connection is admitted. Register new streams and subscriptions when connecting again.
    /// Cancelling an individual stream consumer does not call this method.
    public func disconnect() async {
        active = false
        recoveryID = UUID()
        recovery?.cancel()
        recovery = nil
        generation = UUID()
        connecting = false
        let hadSocket = connection != nil
        let closing = retireConnection()
        receiver?.cancel()
        receiver = nil
        subscriptions.removeAll()
        modes.removeAll()
        commandOperation = nil
        subscribers.finish()
        marketSubscribers.finish()
        brokerSubscribers.finish()
        orderSubscribers.finish()
        emit(.disconnected)
        lifecycleSubscribers.finish()
        if hadSocket {
            await closing.value
        }
    }

    /// Install the fence synchronously, before any actor suspension or recovery admission.
    func retireConnection() -> Task<Void, Never> {
        let previous = teardown
        let pending = connector
        let socket = connection
        pending?.cancel()
        connector = nil
        connection = nil
        let closing = Task {
            await previous?.value
            if let socket {
                await socket.close()
            }
            if let pending, let late = try? await pending.value {
                await late.close()
            }
        }
        teardown = closing
        return closing
    }
}
