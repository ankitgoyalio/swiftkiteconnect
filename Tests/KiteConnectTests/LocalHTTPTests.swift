//
//  LocalHTTPTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Dispatch
import Foundation
import KiteConnect
import Testing

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// A real loopback TCP service, shared by Apple and Linux tests. No external account/network.
private func localService(
    status: Int = 200, body: String = profileJSON, extraHeaders: String = "", delay: Duration = .zero,
    accepted: AsyncStream<Void>.Continuation? = nil, bodyData: Data? = nil,
)
    throws -> (URL, Task<String, any Error>)
{
    #if os(Linux)
        let listener = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
    #else
        let listener = socket(AF_INET, SOCK_STREAM, 0)
    #endif
    guard listener >= 0 else { throw URLError(.cannotConnectToHost) }
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bound = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bound == 0, listen(listener, 1) == 0 else {
        close(listener)
        throw URLError(.cannotConnectToHost)
    }
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &length) }
    }
    let port = UInt16(bigEndian: address.sin_port)
    let task = Task.detached { () throws -> String in
        defer { accepted?.finish() }
        let (connection, received) = try await blockingHTTPIO { () throws -> (Int32, Data) in
            defer { close(listener) }
            var pollDescriptor = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
            guard poll(&pollDescriptor, 1, 10000) > 0 else { throw URLError(.timedOut) }
            let connection = accept(listener, nil, nil)
            guard connection >= 0 else { throw URLError(.cannotConnectToHost) }
            var transferred = false
            defer {
                if !transferred {
                    close(connection)
                }
            }
            var timeout = timeval(tv_sec: 5, tv_usec: 0)
            _ = setsockopt(
                connection, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size),
            )
            var received = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while !received.contains(Data("\r\n\r\n".utf8)) {
                let count = recv(connection, &buffer, buffer.count, 0)
                guard count > 0, received.count < 65536 else { throw URLError(.badServerResponse) }
                received.append(contentsOf: buffer.prefix(count))
            }
            transferred = true
            return (connection, received)
        }
        defer { close(connection) }
        accepted?.yield(())
        try await Task.sleep(for: delay)
        let payload = bodyData ?? Data(body.utf8)
        var response = Data(
            "HTTP/1.1 \(status) Test\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\(extraHeaders)\r\n"
                .utf8,
        )
        response.append(payload)
        let responseBytes = response
        try await blockingHTTPIO {
            try responseBytes.withUnsafeBytes { bytes in
                var sent = 0
                while sent < bytes.count {
                    #if os(Linux)
                        let count = send(
                            connection, bytes.baseAddress!.advanced(by: sent), bytes.count - sent,
                            Int32(MSG_NOSIGNAL),
                        )
                    #else
                        var noSignal: Int32 = 1
                        _ = setsockopt(
                            connection, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size),
                        )
                        let count = send(connection, bytes.baseAddress!.advanced(by: sent), bytes.count - sent, 0)
                    #endif
                    guard count > 0 else { throw URLError(.networkConnectionLost) }
                    sent += count
                }
            }
        }
        return String(decoding: received, as: UTF8.self)
    }
    return (URL(string: "http://127.0.0.1:\(port)")!, task)
}

@Test func `profile works over real local HTTP`() async throws {
    let (url, service) = try localService()
    let client = try KiteClient(
        apiKey: "local-key", accessToken: "local-token", configuration: KiteConfiguration(baseURL: url),
    )
    let profile = try await client.profile()
    #expect(profile.userID == "AB1234")
    let request = try await service.value.lowercased()
    #expect(request.hasPrefix("get /user/profile http/1.1\r\n"))
    #expect(request.contains("authorization: token local-key:local-token\r\n"))
    #expect(request.contains("x-kite-version: 3\r\n"))
}

@Test func `real HTTP does not follow redirects`() async throws {
    let (url, service) = try localService(
        status: 302, body: "", extraHeaders: "Location: http://127.0.0.1:1/forbidden\r\n",
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: KiteConfiguration(baseURL: url),
    )
    do {
        _ = try await client.profile()
        Issue.record("Expected redirect rejection")
    } catch let KiteError.api(error) { #expect(error.statusCode == 302) }
    _ = try await service.value
}

@Test func `real HTTP honors timeout`() async throws {
    let (url, service) = try localService(delay: .seconds(2))
    let client = try KiteClient(
        apiKey: "key", accessToken: "token",
        configuration: KiteConfiguration(baseURL: url, timeout: 0.1),
    )
    do {
        _ = try await client.profile()
        Issue.record("Expected timeout")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    service.cancel()
    _ = try? await service.value
}

@Test func `real HTTP in flight cancellation remains recognizable`() async throws {
    let (accepted, continuation) = AsyncStream<Void>.makeStream()
    let (url, service) = try localService(delay: .seconds(10), accepted: continuation)
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: KiteConfiguration(baseURL: url),
    )
    let operation = Task { try await client.profile() }
    var requests = accepted.makeAsyncIterator()
    #expect(await requests.next() != nil)
    operation.cancel()
    await #expect(throws: CancellationError.self) { try await operation.value }
    service.cancel()
    _ = try? await service.value
}

@Test func `instruments decompresses gzip over real local HTTP`() async throws {
    // A fixed gzip member containing a complete one-record catalogue, generated independently.
    let gzip = try #require(Data(
        base64Encoded:
        "H4sIAAAAAAAC/02NwQqCQBiE74JvMsgaGvkABl2M8ORJNvuxH3WV3T9oe/p2KaLDDDPwMcPGiX0sZKSXdSIDeg53bUb6VrH6xmZ0frmuM4xeCLN20m+WBwrwxtYjTPBEEB6m3vErIKt8Av/N+43gaIzl95ImhTqofYm8rAqcmmMX7dx2LfIi32VVCUBlKgCoL2jaOipN3uMmWHq3AAAA",
    ))
    let (url, service) = try localService(extraHeaders: "Content-Encoding: gzip\r\n", bodyData: gzip)
    let client = try KiteClient(
        apiKey: "key", configuration: KiteConfiguration(baseURL: url, routePrefix: "/oms"),
    )
    let instruments = try await client.instruments(exchange: .nse)
    #expect(instruments.count == 1)
    #expect(instruments.first?.tradingSymbol == "INFY")
    #expect(instruments.first?.lastPrice == Decimal(string: "1412.95"))
    let request = try await service.value.lowercased()
    #expect(request.hasPrefix("get /instruments/nse http/1.1\r\n"))
}

/// Raw poll/accept/recv/send must not occupy Swift's cooperative executor.
private func blockingHTTPIO<Value: Sendable>(
    _ operation: @escaping @Sendable () throws -> Value,
) async throws -> Value {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global().async {
            continuation.resume(with: Result(catching: operation))
        }
    }
}
