import Foundation
import KiteConnect
import Network
import Testing
import os

struct ProfileTests {
    @Test func fetchesAuthenticatedProfile() async throws {
        // Zerodha's shared fixture, pinned at c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        let fixture = try HTTPStub.fixture("profile.json")

        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/kite/user/profile")
            #expect(request.url?.query == nil)
            try #expect(HTTPStub.body(of: request) == nil)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(
                apiKey: "test-key",
                accessToken: "test-token",
                baseURL: baseURL.appendingPathComponent("kite", isDirectory: true),
                session: session
            )
            let profile = try await kite.profile()

            #expect(profile.userID == "AB1234")
            #expect(profile.userType == "individual")
            #expect(profile.email == "xxxyyy@gmail.com")
            #expect(profile.userName == "AxAx Bxx")
            #expect(profile.userShortName == "AxAx")
            #expect(profile.broker == "ZERODHA")
            #expect(profile.exchanges == ["BFO", "MCX", "NSE", "CDS", "BSE", "BCD", "MF", "NFO"])
            #expect(profile.products == ["CNC", "NRML", "MIS", "BO", "CO"])
            #expect(profile.orderTypes == ["MARKET", "LIMIT", "SL", "SL-M"])
            #expect(profile.avatarURL == nil)
            #expect(profile.meta.dematConsent == "physical")
        }
    }

    @Test func expiredSessionIsReportedWithoutRetrying() async throws {
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        let fixture = Data("""
            {"status":"error","error_type":"TokenException","message":"Incorrect api_key or access_token."}
            """.utf8)

        try await HTTPStub.withSession { _ in
            attempts.withLock { $0 += 1 }
            return .init(statusCode: 403, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "expired", baseURL: baseURL, session: session)
            do {
                _ = try await kite.profile()
                Issue.record("Expected Kite to reject the expired Access Token")
            } catch KiteError.service(let error) {
                #expect(error.kind == .token)
                #expect(error.isSessionExpired)
                #expect(error.statusCode == 403)
                #expect(error.message == "Incorrect api_key or access_token.")
            }
        }
        #expect(attempts.withLock { $0 } == 1)
    }

    @Test func returnsRedirectWithoutReplayingRequest() async throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let queue = DispatchQueue(label: "KiteConnectTests.redirect")
        let paths = OSAllocatedUnfairLock(initialState: [String]())
        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 24, maximumLength: 4096) { data, _, _, _ in
                guard let data else {
                    connection.cancel()
                    return
                }

                let request = String(decoding: data, as: UTF8.self)
                let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? ""
                paths.withLock { $0.append(path) }
                let response = path == "/user/profile"
                    ? "HTTP/1.1 307 Temporary Redirect\r\nLocation: /redirect-target\r\n"
                    : "HTTP/1.1 500 Internal Server Error\r\n"
                connection.send(
                    content: Data((response + "Content-Length: 0\r\nConnection: close\r\n\r\n").utf8),
                    completion: .contentProcessed { _ in connection.cancel() }
                )
            }
        }

        defer { listener.cancel() }
        let port: NWEndpoint.Port = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak listener] state in
                switch state {
                case .ready:
                    listener?.stateUpdateHandler = nil
                    if let port = listener?.port {
                        continuation.resume(returning: port)
                    } else {
                        continuation.resume(throwing: URLError(.cannotConnectToHost))
                    }
                case .failed(let error):
                    listener?.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }

        let baseURL = try #require(URL(string: "http://127.0.0.1:\(port.rawValue)"))
        let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL)
        do {
            _ = try await kite.profile()
            Issue.record("Expected HTTP 307")
        } catch KiteError.http(let statusCode) {
            #expect(statusCode == 307)
        }
        #expect(paths.withLock { $0 } == ["/user/profile"])
    }

    @Test func timeoutIsReportedWithoutRetrying() async throws {
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        try await HTTPStub.withSession { _ in
            attempts.withLock { $0 += 1 }
            throw URLError(.timedOut)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            do {
                _ = try await kite.profile()
                Issue.record("Expected a transport timeout")
            } catch KiteError.transport(let domain, let code) {
                #expect(domain == NSURLErrorDomain)
                #expect(code == URLError.timedOut.rawValue)
            }
        }
        #expect(attempts.withLock { $0 } == 1)
    }

    @Test func classifiesUnstructuredHTTPFailure() async throws {
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        try await HTTPStub.withSession { _ in
            attempts.withLock { $0 += 1 }
            return .init(statusCode: 503, body: Data("unavailable".utf8), headers: ["Content-Type": "text/plain"])
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            do {
                _ = try await kite.profile()
                Issue.record("Expected HTTP 503")
            } catch KiteError.http(let statusCode) {
                #expect(statusCode == 503)
            }
        }
        #expect(attempts.withLock { $0 } == 1)
    }

    @Test func classifiesMalformedSuccessPayload() async throws {
        let fixture = Data(#"{"status":"success","data":{"user_id":42}}"#.utf8)
        try await HTTPStub.withSession { _ in
            .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            do {
                _ = try await kite.profile()
                Issue.record("Expected a decoding failure")
            } catch KiteError.decoding(let error) {
                guard case DecodingError.typeMismatch(_, let context) = error else {
                    Issue.record("Expected a profile field type mismatch")
                    return
                }
                #expect(context.codingPath.map(\.stringValue) == ["data", "user_id"])
            }
        }
    }
}
