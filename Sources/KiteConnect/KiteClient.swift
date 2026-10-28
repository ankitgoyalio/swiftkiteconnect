import Foundation

public struct KiteAPIError: Error, Sendable, Equatable {
  public let statusCode: Int
  /// Raw server value, including unfamiliar error types.
  public let errorType: String?
  public let message: String
  public let headers: [String: String]
}

public indirect enum KiteError: Error, Sendable {
  case validation(field: String, message: String)
  case transport(code: Int?, message: String)
  case api(KiteAPIError)
  case decoding(statusCode: Int, message: String)
  /// A mutation may have reached Kite. Reconcile before submitting another action.
  case uncertainOutcome(KiteError)
}

public struct KiteConfiguration: Sendable {
  public let baseURL: URL
  public let routePrefix: String
  public let timeout: TimeInterval
  public let tradingTimeZone: TimeZone
  public init(
    baseURL: URL = URL(string: "https://api.kite.trade")!, routePrefix: String = "",
    timeout: TimeInterval = 30, tradingTimeZone: TimeZone = TimeZone(identifier: "Asia/Kolkata")!
  ) throws {
    guard ["https", "http"].contains(baseURL.scheme), baseURL.host != nil, baseURL.user == nil,
      baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil
    else {
      throw KiteError.validation(
        field: "baseURL", message: "Expected an HTTP origin without credentials, query, or fragment"
      )
    }
    guard timeout.isFinite, timeout > 0 else {
      throw KiteError.validation(field: "timeout", message: "Must be finite and positive")
    }
    guard
      routePrefix.isEmpty
        || (routePrefix.hasPrefix("/") && !routePrefix.contains("?") && !routePrefix.contains("#")
          && !routePrefix.contains(".."))
    else {
      throw KiteError.validation(field: "routePrefix", message: "Expected an absolute path prefix")
    }
    self.baseURL = baseURL
    self.routePrefix = routePrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    self.timeout = timeout
    self.tradingTimeZone = tradingTimeZone
  }
  public static var sandbox: KiteConfiguration {
    try! KiteConfiguration(baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms")
  }
}

/// Repeated pairs preserve parameters such as `i=NSE:INFY&i=NSE:RELIANCE`.
public struct KiteParameter: Sendable, Equatable {
  public let name: String
  public let value: String
  public init(_ name: String, _ value: String) {
    self.name = name
    self.value = value
  }
}
public enum KiteRequestBody: Sendable {
  case form([KiteParameter])
  case json(Data)
}

/// Shared request contract for typed endpoint extensions and controlled protocol tests.
public struct KiteRequest: Sendable {
  public let method: KiteHTTPMethod
  public let path: String
  public let query: [KiteParameter]
  public let body: KiteRequestBody?
  public let authenticated: Bool
  public let isTradingMutation: Bool
  public let isInstrumentDump: Bool
  public init(
    method: KiteHTTPMethod = .get, path: String, query: [KiteParameter] = [],
    body: KiteRequestBody? = nil, authenticated: Bool = true, isTradingMutation: Bool = false,
    isInstrumentDump: Bool = false
  ) {
    self.method = method
    self.path = path
    self.query = query
    self.body = body
    self.authenticated = authenticated
    self.isTradingMutation = isTradingMutation
    self.isInstrumentDump = isInstrumentDump
  }
}

/// Supplied authenticated credentials. Validated when constructing a client.
public struct KiteSessionCredentials: Sendable {
  public let apiKey: String
  public let accessToken: String
  public init(apiKey: String, accessToken: String) {
    self.apiKey = apiKey
    self.accessToken = accessToken
  }
}

/// One API key/session per actor. No request queue or automatic retry is maintained.
public actor KiteClient {
  public nonisolated let configuration: KiteConfiguration
  public nonisolated let apiKey: String
  // Actor-isolated access for typed authentication endpoint extensions in this module.
  var accessToken: String?
  var sessionRevision: UInt64 = 0
  private let transport: any KiteHTTPTransport

  public init(
    apiKey: String, accessToken: String? = nil,
    configuration: KiteConfiguration = try! KiteConfiguration(),
    transport: any KiteHTTPTransport = URLSessionKiteTransport()
  ) throws {
    try Self.validateCredential(apiKey, field: "apiKey")
    if let accessToken { try Self.validateCredential(accessToken, field: "accessToken") }
    self.apiKey = apiKey
    self.accessToken = accessToken
    self.configuration = configuration
    self.transport = transport
  }
  public init(
    session: KiteSessionCredentials,
    configuration: KiteConfiguration = try! KiteConfiguration(),
    transport: any KiteHTTPTransport = URLSessionKiteTransport()
  ) throws {
    try self.init(
      apiKey: session.apiKey, accessToken: session.accessToken,
      configuration: configuration, transport: transport)
  }

  /// Requests already handed to the transport may complete with their original session.
  /// Every request admitted after this returns uses the new token; nil clears it locally.
  public func replaceAccessToken(_ token: String?) throws {
    if let token { try Self.validateCredential(token, field: "accessToken") }
    accessToken = token
    sessionRevision &+= 1
  }
  static func validateCredential(_ value: String, field: String) throws {
    guard !value.isEmpty,
      !value.contains(where: {
        $0.isWhitespace || $0.isNewline || $0 == ":"
          || $0.asciiValue.map({ $0 < 32 || $0 == 127 }) == true
      })
    else {
      throw KiteError.validation(
        field: field,
        message: "Must be a nonempty credential without whitespace, control characters, or colons")
    }
  }
  public func profile() async throws -> KiteUserProfile {
    try await execute(KiteRequest(path: "/user/profile"), as: KiteUserProfile.self)
  }
  public func execute<Value: Decodable & Sendable>(_ request: KiteRequest, as type: Value.Type)
    async throws -> Value
  {
    let response = try await response(for: request)
    do {
      let envelope = try KiteTimestamp.decoder(timeZone: configuration.tradingTimeZone).decode(
        Envelope<Value>.self, from: response.body)
      guard envelope.status == "success" else {
        throw KiteError.decoding(
          statusCode: response.statusCode, message: "Expected success envelope")
      }
      return envelope.data
    } catch {
      let failure = KiteError.decoding(
        statusCode: response.statusCode,
        message: "Malformed or missing required response data: \(error)")
      throw request.isTradingMutation ? KiteError.uncertainOutcome(failure) : failure
    }
  }
  /// Validates HTTP/API errors, returning bytes for CSV and other non-JSON endpoints.
  public func response(for request: KiteRequest) async throws -> KiteHTTPResponse {
    try Task.checkCancellation()
    guard request.path.hasPrefix("/"), !request.path.contains(".."), !request.path.contains("?"),
      !request.path.contains("#"), !request.path.contains("://")
    else {
      throw KiteError.validation(
        field: "path", message: "Expected a relative API path without query or traversal")
    }
    var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)!
    let prefix = request.isInstrumentDump ? "" : configuration.routePrefix
    components.path =
      components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).withLeadingSlash
      + (prefix.isEmpty ? "" : "/" + prefix) + request.path
    components.percentEncodedQuery = request.query.isEmpty ? nil : Self.encode(request.query)
    guard let url = components.url else {
      throw KiteError.validation(field: "path", message: "Invalid URL")
    }
    var headers = ["X-Kite-Version": "3", "Accept": "application/json"]
    if request.authenticated {
      guard let accessToken else {
        throw KiteError.validation(
          field: "accessToken", message: "An authenticated session is required")
      }
      headers["Authorization"] = "token \(apiKey):\(accessToken)"
    }
    var body: Data?
    switch request.body {
    case .form(let fields):
      body = Data(Self.encode(fields).utf8)
      headers["Content-Type"] = "application/x-www-form-urlencoded"
    case .json(let data):
      body = data
      headers["Content-Type"] = "application/json"
    case nil: break
    }
    let wire = KiteHTTPRequest(
      url: url, method: request.method, headers: headers, body: body, timeout: configuration.timeout
    )
    let response: KiteHTTPResponse
    do { response = try await transport.send(wire) } catch {
      let ns = error as NSError
      if error is CancellationError
        || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled)
        || Task.isCancelled
      {
        throw CancellationError()
      }
      let failure = KiteError.transport(code: ns.code, message: ns.localizedDescription)
      throw request.isTradingMutation ? KiteError.uncertainOutcome(failure) : failure
    }
    try Task.checkCancellation()
    let apiFailure = try? JSONDecoder().decode(ErrorEnvelope.self, from: response.body)
    if !(200..<300).contains(response.statusCode) || apiFailure?.status == "error" {
      // A valid Kite error envelope confirms rejection. Gateway/non-JSON mutation failures remain uncertain.
      let failure = KiteError.api(
        KiteAPIError(
          statusCode: response.statusCode, errorType: apiFailure?.errorType,
          message: apiFailure?.message ?? "HTTP \(response.statusCode)", headers: response.headers))
      if request.isTradingMutation && apiFailure?.status != "error" {
        throw KiteError.uncertainOutcome(failure)
      }
      throw failure
    }
    return response
  }
  static func encode(_ parameters: [KiteParameter]) -> String {
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    return parameters.map {
      $0.name.addingPercentEncoding(withAllowedCharacters: allowed)! + "=" + $0.value
        .addingPercentEncoding(withAllowedCharacters: allowed)!
    }.joined(separator: "&")
  }
}
private struct Envelope<Value: Decodable>: Decodable {
  let status: String
  let data: Value
}
private struct ErrorEnvelope: Decodable {
  let status: String
  let message: String?
  let errorType: String?
  enum CodingKeys: String, CodingKey {
    case status, message
    case errorType = "error_type"
  }
}
extension String { fileprivate var withLeadingSlash: String { isEmpty ? "" : "/" + self } }
