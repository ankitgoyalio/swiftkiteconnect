import Foundation

/// An authenticated WebSocket connection that delivers ticker events to one iterator.
/// A connection loss observed during iteration starts automatic reconnection.
public actor KiteTicker: AsyncSequence {
    public static let defaultURL = URL(string: "wss://ws.kite.trade/")!

    private let url: URL
    private var socket: TickerSocket?
    private var connectedAt = ContinuousClock.now
    private var retryDelay = Duration.seconds(1)
    private var reconnection: Task<Void, Never>?
    private var terminalFailure: KiteTickerError?
    private var isClosed = false
    private var iteratorID: UUID?
    private var isReading = false
    private var lastWrite: Task<Void, Error>?
    private var desired: [UInt32: Mode] = [:]

    private init(socket: TickerSocket, url: URL) {
        self.socket = socket
        self.url = url
    }

    deinit {
        reconnection?.cancel()
    }

    /// Opens the WebSocket using the caller's Access Token and waits for the server's upgrade.
    /// Custom endpoints use WSS. A loopback IP address can also use WS for local testing.
    public static func connect(
        apiKey: String,
        accessToken: String,
        url: URL = KiteTicker.defaultURL
    ) async throws -> KiteTicker {
        let authenticatedURL = try TickerSocket.authenticatedURL(apiKey: apiKey, accessToken: accessToken, url: url)
        let socket = try await TickerSocket.connect(to: authenticatedURL)
        return KiteTicker(socket: socket, url: authenticatedURL)
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

    /// Requests a normal WebSocket close and finishes the event sequence.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        reconnection?.cancel()
        socket?.close()
        socket = nil
        lastWrite = nil
    }

    public enum Event: Sendable, Equatable {
        case connected
        /// Delivery was interrupted. The ticker will retry, and the caller owns gap reconciliation.
        case interrupted(KiteTickerError)
        /// The ticker has sent the restored subscriptions and modes on the new connection.
        case recovered
        /// Ticks in the order they appeared in one binary message.
        case ticks([Tick])
    }

    public struct Tick: Sendable, Equatable {
        public let instrumentToken: UInt32
        public let lastPrice: Double

        public init(instrumentToken: UInt32, lastPrice: Double) {
            self.instrumentToken = instrumentToken
            self.lastPrice = lastPrice
        }
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
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
        guard !isClosed, terminalFailure == nil else { throw KiteTickerError.closed }
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
        guard !isClosed else { return nil }
        try Task.checkCancellation()
        guard let iteratorID else {
            self.iteratorID = id
            return .connected
        }
        guard iteratorID == id else { throw KiteTickerError.iteratorAlreadyCreated }
        guard !isReading else { throw KiteTickerError.concurrentNext }
        isReading = true
        defer { isReading = false }

        if let reconnection {
            await withTaskCancellationHandler {
                await reconnection.value
            } onCancel: {
                reconnection.cancel()
            }
            guard !isClosed else { return nil }
            self.reconnection = nil
            if Task.isCancelled {
                close()
                throw CancellationError()
            }
            if let terminalFailure {
                close()
                throw terminalFailure
            }
            return .recovered
        }

        guard let socket else { return nil }
        do {
            while !isClosed {
                let message = try await socket.receive()
                guard !isClosed else { return nil }
                try Task.checkCancellation()
                if case .data(let data) = message {
                    let ticks = TickerPackets.decode(data)
                    if !ticks.isEmpty { return .ticks(ticks) }
                }
            }
            return nil
        } catch {
            guard !isClosed else { return nil }
            if Task.isCancelled {
                close()
                throw CancellationError()
            }
            guard let failure = error as? KiteTickerError, !failure.isTerminalRejection else {
                close()
                throw error
            }
            startReconnection()
            return .interrupted(failure)
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
                    await self?.recordTerminalFailure(failure)
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

    private func recordTerminalFailure(_ failure: KiteTickerError) {
        terminalFailure = failure
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
