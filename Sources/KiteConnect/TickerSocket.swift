import Foundation

/// Owns one WebSocket connection, from the HTTP upgrade to close.
final class TickerSocket: Sendable {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private let termination: Task<KiteTickerError?, Never>

    private init(url: URL, upgrade: AsyncThrowingStream<Void, Error>.Continuation) {
        let ended = AsyncStream<KiteTickerError>.makeStream(bufferingPolicy: .bufferingOldest(1))
        let delegate = Delegate(upgrade: upgrade, termination: ended.continuation)
        session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        task = session.webSocketTask(with: url)
        termination = Task {
            var events = ended.stream.makeAsyncIterator()
            return await events.next()
        }
    }

    deinit {
        termination.cancel()
        if task.state == .running {
            close()
        }
    }

    static func connect(to authenticatedURL: URL) async throws -> TickerSocket {
        try Task.checkCancellation()
        let upgrade = AsyncThrowingStream<Void, Error>.makeStream()
        let socket = TickerSocket(url: authenticatedURL, upgrade: upgrade.continuation)
        return try await withTaskCancellationHandler {
            socket.task.resume()
            var result = upgrade.stream.makeAsyncIterator()
            let opened: Void? = try await result.next()
            try Task.checkCancellation()
            guard opened != nil else { throw TickerSocket.failure(for: socket.task, error: nil) }
            return socket
        } onCancel: {
            socket.close()
        }
    }

    func send(_ command: TickerCommand) async throws {
        try Task.checkCancellation()
        let data = try JSONEncoder().encode(command)
        try await withTaskCancellationHandler {
            do {
                try await task.send(.string(String(decoding: data, as: UTF8.self)))
            } catch {
                throw await failure(after: error)
            }
        } onCancel: {
            close()
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await withTaskCancellationHandler {
            do {
                return try await task.receive()
            } catch {
                throw await failure(after: error)
            }
        } onCancel: {
            close()
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }

    private func failure(after error: any Error) async -> KiteTickerError {
        // Foundation can fail the I/O before making the peer's close code available.
        await termination.value ?? Self.failure(for: task, error: error)
    }

    static func authenticatedURL(apiKey: String, accessToken: String, url: URL) throws -> URL {
        guard !accessToken.isEmpty else { throw KiteTickerError.missingAccessToken }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.fragment == nil,
              components.scheme == "wss" || (
                  components.scheme == "ws" && ["127.0.0.1", "::1", "[::1]"].contains(host)
              )
        else { throw KiteTickerError.invalidEndpoint }

        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var query = (components.percentEncodedQueryItems ?? []).filter { item in
            let name = item.name.removingPercentEncoding
            return name != "api_key" && name != "access_token"
        }
        for (name, value) in [("api_key", apiKey), ("access_token", accessToken)] {
            guard let encoded = value.addingPercentEncoding(withAllowedCharacters: unreserved) else {
                throw KiteTickerError.invalidEndpoint
            }
            query.append(URLQueryItem(name: name, value: encoded))
        }
        components.percentEncodedQueryItems = query
        guard let authenticatedURL = components.url else { throw KiteTickerError.invalidEndpoint }
        return authenticatedURL
    }

    private static func failure(for task: URLSessionTask, error: (any Error)?) -> KiteTickerError {
        if let response = task.response as? HTTPURLResponse, response.statusCode != 101 {
            return .http(statusCode: response.statusCode)
        }
        if let socket = task as? URLSessionWebSocketTask, socket.closeCode != .invalid {
            return .socketClosed(code: socket.closeCode.rawValue)
        }
        let failure = (error ?? URLError(.networkConnectionLost)) as NSError
        return .transport(domain: failure.domain, code: failure.code)
    }

    private final class Delegate: NSObject, URLSessionWebSocketDelegate {
        let upgrade: AsyncThrowingStream<Void, Error>.Continuation
        let termination: AsyncStream<KiteTickerError>.Continuation

        init(
            upgrade: AsyncThrowingStream<Void, Error>.Continuation,
            termination: AsyncStream<KiteTickerError>.Continuation
        ) {
            self.upgrade = upgrade
            self.termination = termination
        }

        func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didOpenWithProtocol protocol: String?
        ) {
            upgrade.yield(())
            upgrade.finish()
        }

        func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
            reason: Data?
        ) {
            termination.yield(.socketClosed(code: closeCode.rawValue))
            termination.finish()
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: (any Error)?
        ) {
            let failure = TickerSocket.failure(for: task, error: error)
            termination.yield(failure)
            termination.finish()
            upgrade.finish(throwing: failure)
            session.finishTasksAndInvalidate()
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }
}

enum TickerCommand: Encodable {
    case subscribe([UInt32])
    case unsubscribe([UInt32])
    case mode(KiteTicker.Mode, [UInt32])

    private enum CodingKeys: String, CodingKey {
        case action = "a"
        case value = "v"
    }

    func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .subscribe(let tokens):
            try fields.encode("subscribe", forKey: .action)
            try fields.encode(tokens, forKey: .value)
        case .unsubscribe(let tokens):
            try fields.encode("unsubscribe", forKey: .action)
            try fields.encode(tokens, forKey: .value)
        case .mode(let mode, let tokens):
            try fields.encode("mode", forKey: .action)
            var value = fields.nestedUnkeyedContainer(forKey: .value)
            try value.encode(mode.rawValue)
            try value.encode(tokens)
        }
    }
}
