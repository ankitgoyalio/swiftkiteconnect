import Foundation
import KiteConnect
import Testing

struct SessionTests {
    @Test func exchangesRequestTokenForSession() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/generate_session.json
        let fixture = try HTTPStub.fixture("generate_session.json")
        let form = "api_key=test%2Bkey&request_token=test+token%2B%26%3D&checksum="
            + "79875f280aebdb5e92ebd194ddd2db4a23e2d538e6c7e03673e49132f97169d4"

        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/session/token")
            #expect(request.url?.query == nil)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            try #expect(HTTPStub.body(of: request) == Data(form.utf8))
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let result = try await KiteConnectClient.exchangeRequestToken(
                "test token+&=", apiKey: "test+key", apiSecret: "test-secret", baseURL: baseURL, session: session
            )

            #expect(result.accessToken == "XXXXXX")
            #expect(result.apiKey == "XXXXXX")
            #expect(result.publicToken == "XXXXXXXX")
            #expect(result.refreshToken == nil)
            #expect(result.loginTime == "2021-01-01 16:15:14")
            #expect(result.profile.userID == "XX0000")
            #expect(result.profile.userShortName == "Connect")
            #expect(result.profile.avatarURL == "abc")
            #expect(result.profile.meta.dematConsent == "physical")
            #expect(!String(describing: result).contains("XXXXXX"))
            #expect(!String(reflecting: result).contains("XXXXXX"))
            var dumpOutput = ""
            dump(result, to: &dumpOutput)
            #expect(!dumpOutput.contains("XXXXXX"))
        }
    }

    @Test func invalidatesAccessTokenUsingQueryParameters() async throws {
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/session_logout.json
        let fixture = try HTTPStub.fixture("session_logout.json")

        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url?.path == "/session/token")
            let query = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            #expect(query?.percentEncodedQuery == "api_key=test%2Bkey&access_token=test%2Btoken%26%3D")
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            try #expect(HTTPStub.body(of: request) == nil)
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(
                apiKey: "test+key", accessToken: "test+token&=", baseURL: baseURL, session: session
            )
            let invalidated = try await kite.invalidateAccessToken()
            #expect(invalidated)
        }
    }

    @Test func reportsRejectedRequestTokenExchange() async throws {
        let fixture = try HTTPStub.fixture("session_exchange_rejected.json")

        try await HTTPStub.withSession { _ in
            .init(statusCode: 403, body: fixture)
        } operation: { session, baseURL in
            do {
                _ = try await KiteConnectClient.exchangeRequestToken(
                    "expired-request-token", apiKey: "test-key", apiSecret: "test-secret",
                    baseURL: baseURL, session: session
                )
                Issue.record("Expected Kite to reject the Request Token")
            } catch KiteError.service(let error) {
                #expect(error.kind == .token)
                #expect(error.statusCode == 403)
                #expect(error.message == "Token is invalid or has expired.")
            }
        }
    }

    @Test func reportsRejectedAccessTokenInvalidation() async throws {
        let fixture = try HTTPStub.fixture("session_invalidation_rejected.json")

        try await HTTPStub.withSession { _ in
            .init(statusCode: 403, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "expired", baseURL: baseURL, session: session)
            do {
                _ = try await kite.invalidateAccessToken()
                Issue.record("Expected Kite to reject the Access Token")
            } catch KiteError.service(let error) {
                #expect(error.kind == .token)
                #expect(error.statusCode == 403)
                #expect(error.message == "Incorrect api_key or access_token.")
            }
        }
    }

    @Test func invalidationTransportErrorOmitsCredentialBearingURL() async throws {
        try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            throw URLError(.timedOut, userInfo: [NSURLErrorFailingURLErrorKey: url])
        } operation: { session, baseURL in
            let kite = KiteConnectClient(
                apiKey: "test-key", accessToken: "private-test-token", baseURL: baseURL, session: session
            )
            do {
                _ = try await kite.invalidateAccessToken()
                Issue.record("Expected a transport timeout")
            } catch let error as KiteError {
                guard case .transport(let domain, let code) = error else {
                    Issue.record("Expected a typed transport failure")
                    return
                }
                #expect(domain == NSURLErrorDomain)
                #expect(code == URLError.timedOut.rawValue)
                #expect(!String(reflecting: error).contains("private-test-token"))
            }
        }
    }
}
