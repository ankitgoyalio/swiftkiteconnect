import Foundation

/// An authenticated WebSocket connection that delivers ticker events to one iterator.
/// A background producer buffers up to 64 events and pauses receives while the buffer is full.
/// The first iterator advanced owns the stream. Cancelling a suspended next call closes the ticker.
public actor KiteTicker: AsyncSequence {
    public static let defaultURL = URL(string: "wss://ws.kite.trade/")!

    private let url: URL
    private let eventCapacity: Int
    private let observeStream: (@Sendable (StreamObservation) -> Void)?
    private var events: [Event] = [.connected]
    private var receiveTask: Task<Void, Never>?
    private var recoveryPending = false
    private var socket: TickerSocket?
    private var connectedAt = ContinuousClock.now
    private var retryDelay = Duration.seconds(1)
    private var reconnection: Task<Void, Never>?
    private var terminalFailure: KiteTickerError?
    private var isClosed = false
    private var iteratorID: UUID?
    private var demandID: UUID?
    private var waitingConsumer: CheckedContinuation<Event?, Error>?
    private var lastWrite: Task<Void, Error>?
    private var desired: [UInt32: Mode] = [:]

    private init(
        socket: TickerSocket,
        url: URL,
        eventCapacity: Int,
        observeStream: (@Sendable (StreamObservation) -> Void)?
    ) {
        self.socket = socket
        self.url = url
        self.eventCapacity = eventCapacity
        self.observeStream = observeStream
    }

    deinit {
        receiveTask?.cancel()
        reconnection?.cancel()
    }

    enum StreamObservation: Equatable, Sendable {
        case willReceive
        case bufferFull
        case waitingForEvent
    }

    /// Opens the WebSocket using the caller's Access Token and waits for the server's upgrade.
    /// Custom endpoints use WSS. A loopback IP address can also use WS for local testing.
    public static func connect(
        apiKey: String,
        accessToken: String,
        url: URL = KiteTicker.defaultURL
    ) async throws -> KiteTicker {
        try await connect(apiKey: apiKey, accessToken: accessToken, url: url, eventCapacity: 64)
    }

    static func connect(
        apiKey: String,
        accessToken: String,
        url: URL,
        eventCapacity: Int,
        observeStream: (@Sendable (StreamObservation) -> Void)? = nil
    ) async throws -> KiteTicker {
        precondition(eventCapacity > 0)
        let authenticatedURL = try TickerSocket.authenticatedURL(apiKey: apiKey, accessToken: accessToken, url: url)
        let socket = try await TickerSocket.connect(to: authenticatedURL)
        let ticker = KiteTicker(
            socket: socket, url: authenticatedURL, eventCapacity: eventCapacity, observeStream: observeStream
        )
        await ticker.resumeReceiving()
        return ticker
    }

    /// Subscribes to the instruments and sets their mode. During reconnect, records the change for replay.
    public func subscribe(_ instrumentTokens: [UInt32], mode: Mode) async throws {
        try checkWritable()
        for token in instrumentTokens {
            desired[token] = mode
        }
        try await write([.subscribe(instrumentTokens), .mode(mode, instrumentTokens)])
    }

    /// Removes the instruments from the subscription, including during reconnect.
    public func unsubscribe(_ instrumentTokens: [UInt32]) async throws {
        try checkWritable()
        for token in instrumentTokens {
            desired.removeValue(forKey: token)
        }
        try await write([.unsubscribe(instrumentTokens)])
    }

    /// Changes the mode for subscribed instruments, including during reconnect.
    public func setMode(_ mode: Mode, for instrumentTokens: [UInt32]) async throws {
        try checkWritable()
        for token in instrumentTokens where desired[token] != nil {
            desired[token] = mode
        }
        try await write([.mode(mode, instrumentTokens)])
    }

    public enum Mode: String, Sendable {
        case ltp, quote, full
    }

    /// Requests a normal WebSocket close. The event sequence drains buffered events before finishing.
    public func close() {
        finish()
    }

    public enum Event: Sendable, Equatable {
        case connected
        /// Delivery was interrupted. The ticker will retry, and the caller owns gap reconciliation.
        case interrupted(KiteTickerError)
        /// The ticker has sent the restored subscriptions and modes on the new connection.
        case recovered
        /// Ticks in the order they appeared in one binary message.
        case ticks([Tick])
        /// An order status event from the authenticated WebSocket.
        case orderUpdate(Order)
        /// Kite sent an order update whose payload could not be decoded. The stream continues.
        case invalidOrderUpdate
    }

    public struct AsyncIterator: AsyncIteratorProtocol, Sendable {
        fileprivate let ticker: KiteTicker
        fileprivate let id = UUID()

        public mutating func next() async throws -> Event? {
            try await ticker.nextEvent(for: id)
        }
    }

    public nonisolated func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(ticker: self)
    }

    private func checkWritable() throws {
        try Task.checkCancellation()
        guard !isClosed else { throw KiteTickerError.closed }
    }

    private func write(_ commands: [TickerCommand]) async throws {
        guard let socket else { return }
        let previous = lastWrite
        let write = Task {
            // Keep each subscription and its mode together even when callers overlap.
            try await previous?.value
            for command in commands {
                guard self.socket === socket else {
                    try checkWritable()
                    return // The replacement socket uses the latest desired state.
                }
                try await socket.send(command)
            }
        }
        lastWrite = write
        do {
            try await write.value
        } catch {
            guard !isClosed else { throw KiteTickerError.closed }
            throw error
        }
    }

    private func nextEvent(for id: UUID) async throws -> Event? {
        try Task.checkCancellation()
        if iteratorID == nil { iteratorID = id }
        guard iteratorID == id else { throw KiteTickerError.iteratorAlreadyCreated }
        guard demandID == nil else { throw KiteTickerError.concurrentNext }

        if !events.isEmpty {
            let event = events.removeFirst()
            resumeReceiving()
            return event
        }
        if isClosed { return try endOfSequence() }

        let demand = UUID()
        demandID = demand
        defer { demandID = nil }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waitingConsumer = continuation
                observeStream?(.waitingForEvent)
            }
        } onCancel: {
            Task { await self.cancelDemand(demand) }
        }
    }

    private func cancelDemand(_ demand: UUID) {
        guard demandID == demand, let consumer = waitingConsumer else { return }
        waitingConsumer = nil
        finish()
        consumer.resume(throwing: CancellationError())
    }

    private func enqueue(_ event: Event) {
        if let consumer = waitingConsumer {
            waitingConsumer = nil
            consumer.resume(returning: event)
        } else {
            events.append(event)
        }
    }

    private func endOfSequence() throws -> Event? {
        if let failure = terminalFailure {
            terminalFailure = nil
            throw failure
        }
        return nil
    }

    private func finish(throwing failure: KiteTickerError? = nil) {
        guard !isClosed else { return }
        isClosed = true
        terminalFailure = failure
        receiveTask?.cancel()
        receiveTask = nil
        reconnection?.cancel()
        reconnection = nil
        socket?.close()
        socket = nil
        lastWrite = nil
        if let consumer = waitingConsumer {
            waitingConsumer = nil
            consumer.resume(with: Result { try endOfSequence() })
        }
    }

    private func resumeReceiving() {
        guard !isClosed, receiveTask == nil, let socket else { return }

        // The producer parks here when the FIFO is full. Dequeuing an event
        // restarts it, while close and subscription commands stay independent.
        if recoveryPending, events.count < eventCapacity {
            recoveryPending = false
            enqueue(.recovered)
        }
        guard events.count < eventCapacity else {
            observeStream?(.bufferFull)
            return
        }

        receiveTask = Task { [weak self, observeStream] in
            do {
                try Task.checkCancellation()
                let message = try await socket.receive {
                    observeStream?(.willReceive)
                }
                await self?.received(message, from: socket)
            } catch {
                let underlying = error as NSError
                let failure = error as? KiteTickerError ?? .transport(domain: underlying.domain, code: underlying.code)
                await self?.receiveFailed(failure, from: socket)
            }
        }
    }

    private func received(_ message: URLSessionWebSocketTask.Message, from source: TickerSocket) {
        guard socket === source else { return }
        receiveTask = nil
        if let event = Self.decode(message) { enqueue(event) }
        resumeReceiving()
    }

    private func receiveFailed(_ failure: KiteTickerError, from source: TickerSocket) {
        guard socket === source else { return }
        receiveTask = nil
        if failure.isTerminalRejection {
            finish(throwing: failure)
        } else {
            enqueue(.interrupted(failure))
            startReconnection()
        }
    }

    private static func decode(_ message: URLSessionWebSocketTask.Message) -> Event? {
        switch message {
        case .data(let data):
            let ticks = TickerPackets.decode(data)
            return ticks.isEmpty ? nil : .ticks(ticks)
        case .string(let text):
            return (try? JSONDecoder().decode(TextEvent.self, from: Data(text.utf8)))?.event
        @unknown default:
            return nil
        }
    }

    private struct TextEvent: Decodable {
        let event: Event?

        private enum CodingKeys: String, CodingKey {
            case type, data
        }

        init(from decoder: any Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            guard try fields.decode(String.self, forKey: .type) == "order" else {
                event = nil
                return
            }
            if let order = try? fields.decode(Order.self, forKey: .data) {
                event = .orderUpdate(order)
            } else {
                event = .invalidOrderUpdate
            }
        }
    }

    private func startReconnection() {
        socket = nil
        lastWrite = nil
        // A socket that drops shortly after recovery keeps the increasing delay.
        let initialDelay = connectedAt.duration(to: .now) >= .seconds(30) ? .seconds(1) : retryDelay
        reconnection = Task { [weak self, url] in
            var delay = initialDelay
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: delay)
                    let candidate = try await TickerSocket.connect(to: url)
                    guard let self else { return }
                    try await self.restoreSubscriptions(on: candidate, nextDelay: Self.increase(delay))
                    return
                } catch let failure as KiteTickerError where failure.isTerminalRejection {
                    await self?.finish(throwing: failure)
                    return
                } catch {
                    delay = Self.increase(delay)
                }
            }
        }
    }

    private static func increase(_ delay: Duration) -> Duration {
        Swift.min(delay * 2, .seconds(30))
    }

    private func restoreSubscriptions(on candidate: TickerSocket, nextDelay: Duration) async throws {
        do {
            var sent: [UInt32: Mode] = [:]
            while sent != desired {
                let target = desired
                let removed = sent.keys.filter { target[$0] == nil }.sorted()
                if !removed.isEmpty {
                    try await candidate.send(.unsubscribe(removed))
                }
                let added = target.keys.filter { sent[$0] == nil }.sorted()
                if !added.isEmpty {
                    try await candidate.send(.subscribe(added))
                }
                for mode in [Mode.ltp, .quote, .full] {
                    let changed = target.keys.filter { target[$0] == mode && sent[$0] != mode }.sorted()
                    if !changed.isEmpty {
                        try await candidate.send(.mode(mode, changed))
                    }
                }
                // Advance to the snapshot that went over the wire. Commands arriving during
                // a send update desired and will be reconciled in the next pass.
                sent = target
            }
            try Task.checkCancellation()
            socket = candidate
            connectedAt = .now
            retryDelay = nextDelay
            reconnection = nil
            recoveryPending = true
            resumeReceiving()
        } catch {
            candidate.close()
            throw error
        }
    }
}

/// A ticker failure without the authenticated request URL or unsanitized Foundation error.
public enum KiteTickerError: Error, Equatable {
    case invalidEndpoint
    case missingAccessToken
    case closed
    case http(statusCode: Int)
    case socketClosed(code: Int)
    case transport(domain: String, code: Int)
    case iteratorAlreadyCreated
    case concurrentNext

    fileprivate var isTerminalRejection: Bool {
        switch self {
        case .http(statusCode: 400), .http(statusCode: 401), .http(statusCode: 403),
             .socketClosed(code: 1008):
            true
        default:
            false
        }
    }
}
