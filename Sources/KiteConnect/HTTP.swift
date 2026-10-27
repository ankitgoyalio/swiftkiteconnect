import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum KiteHTTPMethod: String, Sendable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case delete = "DELETE"
}

/// One request attempt. Implementations must honor cancellation and must not retry.
public protocol KiteHTTPTransport: Sendable {
  func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse
}

public struct KiteHTTPRequest: Sendable {
  public let url: URL
  public let method: KiteHTTPMethod
  public let headers: [String: String]
  public let body: Data?
  public let timeout: TimeInterval
  public init(
    url: URL, method: KiteHTTPMethod, headers: [String: String] = [:], body: Data? = nil,
    timeout: TimeInterval = 30
  ) {
    self.url = url
    self.method = method
    self.headers = headers
    self.body = body
    self.timeout = timeout
  }
}

public struct KiteHTTPResponse: Sendable {
  public let statusCode: Int
  public let headers: [String: String]
  public let body: Data
  public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
    self.statusCode = statusCode
    self.headers = headers
    self.body = body
  }
}

/// Ephemeral HTTP only; WebSocket transport qualification belongs to the streaming tickets.
public final class URLSessionKiteTransport: NSObject, KiteHTTPTransport, URLSessionTaskDelegate {
  public override init() { super.init() }
  public func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = request.timeout
    configuration.timeoutIntervalForResource = request.timeout
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    var wire = URLRequest(url: request.url, timeoutInterval: request.timeout)
    wire.httpMethod = request.method.rawValue
    wire.allHTTPHeaderFields = request.headers
    wire.httpBody = request.body
    let (data, response) = try await session.data(for: wire)
    guard let http = response as? HTTPURLResponse else {
      throw KiteError.transport(code: nil, message: "Non-HTTP response")
    }
    let headers = http.allHeaderFields.reduce(into: [String: String]()) {
      $0[String(describing: $1.key)] = String(describing: $1.value)
    }
    return KiteHTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
  }
  // Redirects are surfaced, preventing credential forwarding and hidden mutation resubmission.
  public func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
