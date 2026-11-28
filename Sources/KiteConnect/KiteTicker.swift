import Foundation

/// An authenticated WebSocket connection that delivers ticker events to one iterator.
public actor KiteTicker: AsyncSequence {
    public static let defaultURL = URL(string: "wss://ws.kite.trade/")!

    private let socket: TickerSocket
    private var isClosed = false
    private var iteratorID: UUID?
    private var isReading = false
    private var lastWrite: Task<Void, Error>?

    private init(socket: TickerSocket) {
        self.socket = socket
    }

    /// Opens the WebSocket using the caller's Access Token and waits for the server's upgrade.
    /// Custom endpoints use WSS. A loopback IP address can also use WS for local testing.
    public static func connect(
        apiKey: String,
        accessToken: String,
        url: URL = KiteTicker.defaultURL
    ) async throws -> KiteTicker {
        let socket = try await TickerSocket.connect(apiKey: apiKey, accessToken: accessToken, url: url)
        return KiteTicker(socket: socket)
    }

    /// Subscribes to the instruments and sets their mode.
    public func subscribe(_ instrumentTokens: [UInt32], mode: Mode) async throws {
        try await write([.subscribe(instrumentTokens), .mode(mode, instrumentTokens)])
    }

    /// Removes the instruments from the subscription.
    public func unsubscribe(_ instrumentTokens: [UInt32]) async throws {
        try await write([.unsubscribe(instrumentTokens)])
    }

    /// Changes the mode for subscribed instruments.
    public func setMode(_ mode: Mode, for instrumentTokens: [UInt32]) async throws {
        try await write([.mode(mode, instrumentTokens)])
    }

    public enum Mode: String, Sendable {
        case ltp, quote, full
    }

    /// Requests a normal WebSocket close and finishes the event sequence.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        socket.close()
    }

    public enum Event: Sendable, Equatable {
        case connected
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

    private func write(_ commands: [TickerCommand]) async throws {
        try Task.checkCancellation()
        guard !isClosed else { throw KiteTickerError.closed }
        let previous = lastWrite
        let write = Task { [socket] in
            // Keep each subscription and its mode together even when callers overlap.
            try await previous?.value
            for command in commands {
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
            close()
            try Task.checkCancellation()
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
}
