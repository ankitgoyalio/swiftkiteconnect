import CryptoKit
import Foundation
import Network

/// A raw loopback server so tests exercise Foundation's actual WebSocket handshake and frames.
enum LoopbackWebSocket {
    enum Failure: Error {
        case timedOut, missingPort, unexpectedEOF, invalidHandshake, invalidFrame, unexpectedConnection
    }

    static func run(
        server: @escaping @Sendable (Peer) async throws -> Void,
        client: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        try await run(servers: [server], client: client)
    }

    static func run(
        servers: [@Sendable (Peer) async throws -> Void],
        client: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let queue = DispatchQueue(label: "KiteConnectTests.websocket")
        let ready = AsyncThrowingStream<NWEndpoint.Port, Error>.makeStream()
        let accepted = AsyncStream<NWConnection>.makeStream(bufferingPolicy: .bufferingOldest(1))
        listener.stateUpdateHandler = { [weak listener] state in
            switch state {
            case .ready:
                if let port = listener?.port {
                    ready.continuation.yield(port)
                    ready.continuation.finish()
                } else {
                    ready.continuation.finish(throwing: Failure.missingPort)
                }
            case .failed(let error):
                ready.continuation.finish(throwing: error)
                accepted.continuation.finish()
            default:
                break
            }
        }
        listener.newConnectionHandler = { connection in
            if case .enqueued = accepted.continuation.yield(connection) { return }
            connection.cancel()
        }
        listener.start(queue: queue)
        defer {
            listener.cancel()
            accepted.continuation.finish()
        }

        try await withThrowingTaskGroup(of: Void.self) { tasks in
            tasks.addTask {
                try await Task.sleep(for: .seconds(5))
                throw Failure.timedOut
            }
            tasks.addTask {
                var ports = ready.stream.makeAsyncIterator()
                guard let port = try await ports.next() else { throw Failure.missingPort }
                try await client(URL(string: "ws://127.0.0.1:\(port.rawValue)/")!)
            }
            tasks.addTask {
                var connections = accepted.stream.makeAsyncIterator()
                for server in servers {
                    guard let connection = await connections.next() else { throw Failure.unexpectedEOF }
                    connection.start(queue: queue)
                    defer { connection.cancel() }
                    try await server(Peer(connection: connection))
                }
            }
            defer { tasks.cancelAll() }
            try await tasks.next()
            try await tasks.next()
            accepted.continuation.finish()
            var remaining = accepted.stream.makeAsyncIterator()
            if let connection = await remaining.next() {
                connection.cancel()
                throw Failure.unexpectedConnection
            }
        }
    }

    actor Peer {
        private let connection: NWConnection
        private var pending = Data()
        private var reachedEOF = false

        init(connection: NWConnection) {
            self.connection = connection
        }

        /// Accepts the upgrade and returns the raw HTTP request target, including its query.
        func acceptUpgrade() async throws -> String {
            let lines = try await requestLines()
            let requestLine = lines[0].split(separator: " ")
            guard requestLine.count == 3, requestLine[0] == "GET",
                  let keyHeader = lines.dropFirst().first(where: {
                      $0.lowercased().hasPrefix("sec-websocket-key:")
                  }),
                  let key = keyHeader.split(separator: ":", maxSplits: 1).last
            else { throw Failure.invalidHandshake }
            let challenge = key.trimmingCharacters(in: .whitespaces) + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
            let accept = Data(Insecure.SHA1.hash(data: Data(challenge.utf8))).base64EncodedString()
            let response = "HTTP/1.1 101 Switching Protocols\r\n"
                + "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                + "Sec-WebSocket-Accept: \(accept)\r\n\r\n"
            try await write(Data(response.utf8))
            return String(requestLine[1])
        }

        func rejectUpgrade(status: String) async throws {
            _ = try await requestLines()
            let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            try await write(Data(response.utf8))
        }

        func readUpgradeRequest() async throws {
            _ = try await requestLines()
        }

        struct Frame {
            let opcode: UInt8
            let payload: Data
        }

        func readFrame() async throws -> Frame {
            let header = try await read(2)
            guard header[0] & 0xF0 == 0x80, header[1] & 0x80 != 0 else {
                throw Failure.invalidFrame
            }
            var length = UInt64(header[1] & 0x7F)
            if length >= 126 {
                let extended = try await read(length == 126 ? 2 : 8)
                length = extended.reduce(0) { ($0 << 8) | UInt64($1) }
            }
            guard length <= 1_048_576 else { throw Failure.invalidFrame }
            let mask = try await read(4)
            let payload = try await read(Int(length))
            let unmasked = payload.enumerated().map { index, byte in
                byte ^ mask[index % 4]
            }
            return Frame(opcode: header[0] & 0x0F, payload: Data(unmasked))
        }

        func sendFrame(opcode: UInt8, payload: Data) async throws {
            var frame = Data([0x80 | opcode])
            switch payload.count {
            case 0...125:
                frame.append(UInt8(payload.count))
            case 126...65_535:
                frame.append(126)
                withUnsafeBytes(of: UInt16(payload.count).bigEndian) { frame.append(contentsOf: $0) }
            default:
                frame.append(127)
                withUnsafeBytes(of: UInt64(payload.count).bigEndian) { frame.append(contentsOf: $0) }
            }
            frame.append(payload)
            try await write(frame)
        }

        private func requestLines() async throws -> [String] {
            let endOfHeaders = Data("\r\n\r\n".utf8)
            while pending.range(of: endOfHeaders) == nil {
                guard pending.count < 16_384 else { throw Failure.invalidHandshake }
                try await readMore()
            }
            guard let boundary = pending.range(of: endOfHeaders),
                  let request = String(data: pending[..<boundary.lowerBound], encoding: .utf8)
            else { throw Failure.invalidHandshake }
            pending.removeSubrange(..<boundary.upperBound)
            return request.components(separatedBy: "\r\n")
        }

        private func read(_ count: Int) async throws -> Data {
            while pending.count < count {
                try await readMore()
            }
            let data = Data(pending.prefix(count))
            pending.removeFirst(count)
            return data
        }

        private func readMore() async throws {
            guard !reachedEOF else { throw Failure.unexpectedEOF }
            let connection = self.connection
            let (data, isComplete): (Data, Bool) = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, complete, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: (data ?? Data(), complete))
                        }
                    }
                }
            } onCancel: {
                connection.cancel()
            }
            pending.append(data)
            reachedEOF = isComplete
        }

        private func write(_ data: Data) async throws {
            let connection = self.connection
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    })
                }
            } onCancel: {
                connection.cancel()
            }
        }
    }
}
