import Foundation

struct RESTClient: Sendable {
    let apiKey: String
    let accessToken: String?
    private let baseURL: URL
    private let session: URLSession

    init(apiKey: String, accessToken: String? = nil, baseURL: URL, session: URLSession) {
        self.apiKey = apiKey
        self.accessToken = accessToken
        self.baseURL = baseURL
        self.session = session
    }

    /// Fetches and decodes the data in a Kite success envelope.
    func send<Value: Decodable>(
        _ endpoint: RESTRequest,
        as type: Value.Type = Value.self,
        allowsOmittedStatus: Bool = false
    ) async throws -> Value {
        let (data, response) = try await sendRaw(endpoint)
        do {
            let envelope = try JSONDecoder().decode(SuccessEnvelope<Value>.self, from: data)
            return try envelope.value(allowsOmittedStatus: allowsOmittedStatus)
        } catch {
            if let serviceError = Self.serviceError(in: data, statusCode: response.statusCode) {
                throw KiteError.service(serviceError)
            }
            throw KiteError.decoding(error)
        }
    }

    /// Fetches a raw success payload, such as an instrument CSV, with the same HTTP error handling as send.
    func sendRaw(_ endpoint: RESTRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = try endpoint.urlRequest(baseURL: baseURL)
        if endpoint.authentication == .accessToken {
            guard let accessToken else { throw KiteError.missingAccessToken }
            request.setValue("token \(apiKey):\(accessToken)", forHTTPHeaderField: "Authorization")
        }

        try Task.checkCancellation()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request, delegate: RejectRedirects())
        } catch {
            try Task.checkCancellation()
            let failure = error as NSError
            throw KiteError.transport(domain: failure.domain, code: failure.code)
        }

        guard let httpResponse = response as? HTTPURLResponse else { throw KiteError.invalidResponse }

        let statusCode = httpResponse.statusCode
        guard (200..<300).contains(statusCode) else {
            if let serviceError = Self.serviceError(in: data, statusCode: statusCode) {
                throw KiteError.service(serviceError)
            }
            throw KiteError.http(statusCode: statusCode)
        }
        return (data, httpResponse)
    }

    private static func serviceError(in data: Data, statusCode: Int) -> KiteServiceError? {
        guard let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) else { return nil }
        return .init(statusCode: statusCode, errorType: envelope.errorType, message: envelope.message)
    }
}

private struct SuccessEnvelope<Value: Decodable>: Decodable {
    private let data: Value
    private let hasStatus: Bool

    private enum Status: String, Decodable { case success }
    private enum CodingKeys: String, CodingKey { case status, data }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hasStatus = values.contains(.status)
        if hasStatus {
            _ = try values.decode(Status.self, forKey: .status)
        }
        data = try values.decode(Value.self, forKey: .data)
    }

    func value(allowsOmittedStatus: Bool) throws -> Value {
        guard hasStatus || allowsOmittedStatus else {
            throw DecodingError.keyNotFound(CodingKeys.status, .init(
                codingPath: [],
                debugDescription: "The Kite response is missing its status."
            ))
        }
        return data
    }
}

private struct ErrorEnvelope: Decodable {
    let errorType: String
    let message: String

    private enum CodingKeys: String, CodingKey {
        case status, message
        case errorType = "error_type"
    }

    private enum Status: String, Decodable { case error }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        _ = try values.decode(Status.self, forKey: .status)
        errorType = try values.decode(String.self, forKey: .errorType)
        message = try values.decode(String.self, forKey: .message)
    }
}

private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
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
