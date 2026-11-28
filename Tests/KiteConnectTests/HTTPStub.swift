import Foundation

/// A host-scoped URLSession stub so parallel contract tests can use independent handlers.
final class HTTPStub: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        let statusCode: Int
        let body: Data
        var headers: [String: String] = ["Content-Type": "application/json"]
    }

    typealias Handler = @Sendable (URLRequest) throws -> Response

    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [String: Handler] = [:]

        func register(_ handler: @escaping Handler, for host: String) {
            lock.withLock { handlers[host] = handler }
        }

        func remove(_ host: String) {
            lock.withLock { handlers[host] = nil }
        }

        func handler(for host: String) -> Handler? {
            lock.withLock { handlers[host] }
        }
    }

    private static let registry = Registry()

    static func withSession<Value>(
        handler: @escaping Handler,
        operation: (URLSession, URL) async throws -> Value
    ) async rethrows -> Value {
        let host = "\(UUID().uuidString.lowercased()).example.test"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTPStub.self]
        let session = URLSession(configuration: configuration)

        registry.register(handler, for: host)
        defer {
            session.invalidateAndCancel()
            registry.remove(host)
        }

        return try await operation(session, URL(string: "https://\(host)")!)
    }

    static func fixture(_ filename: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: filename])
        }
        return try Data(contentsOf: url)
    }

    /// Foundation can deliver the body to URLProtocol as a stream.
    static func body(of request: URLRequest) throws -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count == 0 { return body }
            if count < 0 { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
            body.append(contentsOf: buffer.prefix(count))
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let handler = Self.registry.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        do {
            let output = try handler(request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: output.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: output.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: output.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
