import Foundation

struct RESTRequest: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    enum Authentication: Sendable {
        case accessToken
        case none
    }

    enum Body: Sendable {
        case none
        case form([URLQueryItem])
        case json(Data)
    }

    let method: Method
    let path: [String]
    let query: [URLQueryItem]
    let body: Body
    let authentication: Authentication

    /// Path segments and query items are supplied unescaped. Repeated query items retain their order.
    init(
        _ method: Method,
        path: [String],
        query: [URLQueryItem] = [],
        body: Body = .none,
        authentication: Authentication = .accessToken
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.authentication = authentication
    }

    func urlRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true),
              let scheme = components.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil
        else {
            throw KiteError.invalidBaseURL
        }

        guard !path.isEmpty, path.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw KiteError.invalidPath
        }

        let prefix = components.percentEncodedPath
        let separator = prefix.hasSuffix("/") ? "" : "/"
        components.percentEncodedPath = prefix + separator + path.map(Self.percentEncode).joined(separator: "/")
        if !query.isEmpty {
            components.percentEncodedQuery = query.map { field in
                let name = Self.percentEncode(field.name)
                return field.value.map { name + "=" + Self.percentEncode($0) } ?? name
            }.joined(separator: "&")
        }
        guard let url = components.url else { throw KiteError.invalidBaseURL }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpShouldHandleCookies = false
        request.httpMethod = method.rawValue
        request.setValue("3", forHTTPHeaderField: "X-Kite-Version")
        switch body {
        case .none:
            break
        case .form(let fields):
            let encoded = fields.map { field in
                Self.formEncode(field.name) + "=" + Self.formEncode(field.value ?? "")
            }.joined(separator: "&")
            request.httpBody = Data(encoded.utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        case .json(let data):
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
    private static let formUnescaped = unreserved
        .subtracting(CharacterSet(charactersIn: "~"))
        .union(CharacterSet(charactersIn: "*"))

    private static func percentEncode(_ value: String) -> String {
        // Swift strings always have a UTF-8 representation.
        value.addingPercentEncoding(withAllowedCharacters: unreserved)!
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: formUnescaped)!
            .replacingOccurrences(of: "%20", with: "+")
    }
}
