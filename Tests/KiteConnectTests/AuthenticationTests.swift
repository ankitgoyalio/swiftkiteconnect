//
//  AuthenticationTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

@Test func loginURLPreservesNestedRedirectParametersWithoutOwningBrowser() throws {
    let client = try KiteClient(apiKey: "key+&")
    let url = try client.loginURL(redirectParameters: "some=X&more=Y+₹#")
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.host == "kite.zerodha.com")
    #expect(components.path == "/connect/login")
    #expect(
        components.queryItems == [
            URLQueryItem(name: "v", value: "3"), URLQueryItem(name: "api_key", value: "key+&"),
            URLQueryItem(name: "redirect_params", value: "some=X&more=Y+₹#"),
        ],
    )
    let sandbox = try client.loginURL(
        endpoint: URL(string: "https://sandbox.kite.trade/connect/login")!,
    )
    #expect(sandbox.host == "sandbox.kite.trade")
    #expect(throws: KiteError.self) {
        try client.loginURL(endpoint: URL(string: "https://user:password@example.test/login")!)
    }
}

@Test func exchangeUsesOfficialFixtureAndKnownChecksumThenAuthenticates() async throws {
    let transport = ControlledHTTP(authenticationJSON)
    let client = try KiteClient(apiKey: "XXXXXX", transport: transport)
    let session = try await client.exchangeRequestToken("yyy", apiSecret: "zzz")
    #expect(session.profile.userID == "XX0000")
    #expect(session.profile.exchanges.contains(.nse))
    #expect(session.apiKey == "XXXXXX")
    #expect(session.accessToken == "XXXXXX")
    #expect(session.publicToken == "XXXXXXXX")
    #expect(session.refreshToken == "")
    #expect(session.loginTime == Date(timeIntervalSince1970: 1_609_497_914))
    _ = try await client.response(for: KiteRequest(path: "/user/profile"))
    let requests = await transport.requests
    #expect(requests.count == 2)
    #expect(requests[0].method == .post)
    #expect(requests[0].url.path == "/session/token")
    #expect(requests[0].headers["Authorization"] == nil)
    #expect(requests[0].headers["X-Kite-Version"] == "3")
    #expect(requests[0].headers["Content-Type"] == "application/x-www-form-urlencoded")
    #expect(
        String(data: requests[0].body!, encoding: .utf8)
            == "api_key=XXXXXX&request_token=yyy&checksum=ae867623b1de995f9bf8559398334dfd1a333bfed47c73f31eaa0d17eef4c417",
    )
    #expect(requests[1].headers["Authorization"] == "token XXXXXX:XXXXXX")
}

actor AuthenticationGate: KiteHTTPTransport {
    nonisolated let received: AsyncStream<KiteHTTPRequest>
    private let events: AsyncStream<KiteHTTPRequest>.Continuation
    private var pending: CheckedContinuation<KiteHTTPResponse, Never>?
    init() {
        (received, events) = AsyncStream.makeStream()
    }

    func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        events.yield(request)
        if request.url.path.contains("/session/") {
            return await withCheckedContinuation { pending = $0 }
        }
        return KiteHTTPResponse(statusCode: 200, body: Data(profileJSON.utf8))
    }

    func complete(_ body: String) {
        pending?.resume(returning: KiteHTTPResponse(statusCode: 200, body: Data(body.utf8)))
        pending = nil
    }
}

@Test func lateExchangeCannotOverwriteExplicitReplacement() async throws {
    let transport = AuthenticationGate()
    var requests = transport.received.makeAsyncIterator()
    let client = try KiteClient(apiKey: "XXXXXX", accessToken: "old", transport: transport)
    let exchange = Task { try await client.exchangeRequestToken("yyy", apiSecret: "zzz") }
    _ = await requests.next()
    try await client.replaceAccessToken("replacement")
    await transport.complete(authenticationJSON)
    await #expect(throws: KiteError.self) { try await exchange.value }
    _ = try await client.profile()
    #expect(await requests.next()?.headers["Authorization"] == "token XXXXXX:replacement")
}

@Test func renewalInstallsTokenUsingRefreshChecksumWithoutSendingSecret() async throws {
    let transport = ControlledHTTP(
        #"{"status":"success","data":{"access_token":"renewed","refresh_token":"next","future":true}}"#,
    )
    let client = try KiteClient(
        apiKey: "a", accessToken: "old", configuration: .sandbox, transport: transport,
    )
    let session = try await client.renewSession(refreshToken: "b", apiSecret: "c")
    #expect(session.accessToken == "renewed")
    #expect(session.refreshToken == "next")
    _ = try await client.response(for: KiteRequest(path: "/user/profile"))
    let requests = await transport.requests
    #expect(requests[0].url.absoluteString == "https://sandbox.kite.trade/oms/session/refresh_token")
    #expect(requests[0].method == .post)
    #expect(requests[0].headers["Authorization"] == nil)
    // NIST SHA-256 "abc" vector, independent of the library's implementation.
    #expect(
        String(data: requests[0].body!, encoding: .utf8)
            == "api_key=a&refresh_token=b&checksum=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )
    #expect(requests[1].headers["Authorization"] == "token a:renewed")
}

@Test func successfulInvalidationRevokesAndClearsOnlyThisSession() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":true}"#)
    let client = try KiteClient(
        apiKey: "key", accessToken: "old+&", configuration: .sandbox, transport: transport,
    )
    #expect(try await client.invalidateSession())
    await #expect(throws: KiteError.self) { try await client.profile() }
    let requests = await transport.requests
    #expect(requests.count == 1)
    #expect(requests[0].method == .delete)
    #expect(
        requests[0].url.absoluteString
            == "https://sandbox.kite.trade/oms/session/token?api_key=key&access_token=old%2B%26",
    )
    #expect(requests[0].headers["X-Kite-Version"] == "3")
    #expect(requests[0].headers["Authorization"] == "token key:old+&")
}

@Test func refreshInvalidationIsIndependentOfInstalledAccessToken() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":true}"#)
    let client = try KiteClient(apiKey: "key", accessToken: "active", transport: transport)
    #expect(try await client.invalidateRefreshToken("refresh+&"))
    _ = try await client.response(for: KiteRequest(path: "/user/profile"))
    let requests = await transport.requests
    #expect(requests[0].method == .delete)
    #expect(requests[0].url.query == "api_key=key&refresh_token=refresh%2B%26")
    #expect(requests[0].headers["Authorization"] == nil)
    #expect(requests[1].headers["Authorization"] == "token key:active")
}

@Test(arguments: ["renew", "invalidate"])
func lateSessionOperationPreservesReplacement(operation: String) async throws {
    let transport = AuthenticationGate()
    var requests = transport.received.makeAsyncIterator()
    let client = try KiteClient(apiKey: "key", accessToken: "old", transport: transport)
    let pending = Task {
        if operation == "renew" {
            _ = try await client.renewSession(refreshToken: "refresh", apiSecret: "secret")
        } else {
            #expect(try await client.invalidateSession())
        }
    }
    _ = await requests.next()
    try await client.replaceAccessToken("replacement")
    await transport.complete(
        operation == "renew"
            ? #"{"status":"success","data":{"access_token":"stale"}}"#
            : #"{"status":"success","data":true}"#,
    )
    if operation == "renew" {
        await #expect(throws: KiteError.self) { try await pending.value }
    } else {
        try await pending.value
    }
    _ = try await client.profile()
    #expect(await requests.next()?.headers["Authorization"] == "token key:replacement")
}

@Test(arguments: ["exchange", "renew", "invalidate"])
func cancellationDoesNotInstallOrClearSession(operation: String) async throws {
    let transport = AuthenticationGate()
    var requests = transport.received.makeAsyncIterator()
    let client = try KiteClient(apiKey: "XXXXXX", accessToken: "old", transport: transport)
    let pending = Task {
        switch operation {
        case "exchange": _ = try await client.exchangeRequestToken("request", apiSecret: "secret")
        case "renew": _ = try await client.renewSession(refreshToken: "refresh", apiSecret: "secret")
        default: _ = try await client.invalidateSession()
        }
    }
    _ = await requests.next()
    pending.cancel()
    await transport.complete(
        operation == "invalidate"
            ? #"{"status":"success","data":true}"# : authenticationJSON,
    )
    await #expect(throws: CancellationError.self) { try await pending.value }
    _ = try await client.profile()
    #expect(await requests.next()?.headers["Authorization"] == "token XXXXXX:old")
}

@Test(arguments: ["exchange", "renew", "invalidate", "refresh-invalidate"])
func authenticationAPIErrorsAreSingleAttemptAndPreserveCredentials(operation: String) async throws {
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FutureException","message":"Rejected"}"#, status: 429,
    )
    let client = try KiteClient(apiKey: "key", accessToken: "old", transport: transport)
    do {
        switch operation {
        case "exchange": _ = try await client.exchangeRequestToken("request", apiSecret: "secret")
        case "renew": _ = try await client.renewSession(refreshToken: "refresh", apiSecret: "secret")
        case "invalidate": _ = try await client.invalidateSession()
        default: _ = try await client.invalidateRefreshToken("refresh")
        }
        Issue.record("Expected API rejection")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == 429)
        #expect(error.errorType == "FutureException")
        #expect(error.message == "Rejected")
    }
    #expect(await transport.requests.count == 1)
    _ = try? await client.response(for: KiteRequest(path: "/controlled", authenticated: true))
    #expect(await transport.requests.last?.headers["Authorization"] == "token key:old")
}

@Test func malformedExchangeAndFalseLogoutPreserveCredentials() async throws {
    for body in [
        authenticationJSON.replacingOccurrences(
            of: #""api_key": "XXXXXX""#, with: #""api_key": "other""#,
        ),
        authenticationJSON.replacingOccurrences(of: #""access_token": "XXXXXX","#, with: ""),
        authenticationJSON.replacingOccurrences(of: "2021-01-01 16:15:14", with: "not-a-date"),
        authenticationJSON.replacingOccurrences(
            of: #""access_token": "XXXXXX""#, with: #""access_token": """#,
        ),
        #"{"status":"success","data":{}}"#,
    ] {
        let transport = ControlledHTTP(body)
        let client = try KiteClient(apiKey: "XXXXXX", accessToken: "old", transport: transport)
        await #expect(throws: KiteError.self) {
            try await client.exchangeRequestToken("request", apiSecret: "secret")
        }
        _ = try await client.response(for: KiteRequest(path: "/controlled"))
        #expect(await transport.requests.last?.headers["Authorization"] == "token XXXXXX:old")
    }
    let transport = ControlledHTTP(#"{"status":"success","data":false}"#)
    let client = try KiteClient(apiKey: "key", accessToken: "old", transport: transport)
    #expect(try await !client.invalidateSession())
    _ = try await client.response(for: KiteRequest(path: "/controlled"))
    #expect(await transport.requests.last?.headers["Authorization"] == "token key:old")
}

@Test func invalidAuthInputsNeverReachTransportOrClearValidSession() async throws {
    let transport = ControlledHTTP()
    let client = try KiteClient(apiKey: "key", accessToken: "old", transport: transport)
    await #expect(throws: KiteError.self) {
        try await client.exchangeRequestToken("", apiSecret: "secret")
    }
    await #expect(throws: KiteError.self) {
        try await client.exchangeRequestToken("request", apiSecret: "")
    }
    await #expect(throws: KiteError.self) {
        try await client.renewSession(refreshToken: "", apiSecret: "secret")
    }
    await #expect(throws: KiteError.self) { try await client.invalidateRefreshToken("") }
    await #expect(throws: KiteError.self) { try await client.replaceAccessToken("bad\r\ntoken") }
    #expect(await transport.requests.isEmpty)
    _ = try await client.profile()
    #expect(await transport.requests.last?.headers["Authorization"] == "token key:old")
}

@Test func exchangeHonorsExplicitOffsetAndConfiguredTradingTimezone() async throws {
    let utc = try KiteConfiguration(tradingTimeZone: TimeZone(secondsFromGMT: 0)!)
    for (time, config, expected) in [
        ("2021-01-01 16:15:14", utc, 1_609_517_714.0),
        ("2021-01-01T10:45:14Z", utc, 1_609_497_914.0),
        ("2021-01-01 16:15:14+05:30", utc, 1_609_497_914.0),
        ("2021-01-01T16:15:14+05:30", utc, 1_609_497_914.0),
    ] {
        let transport = ControlledHTTP(
            authenticationJSON.replacingOccurrences(of: "2021-01-01 16:15:14", with: time),
        )
        let client = try KiteClient(apiKey: "XXXXXX", configuration: config, transport: transport)
        let session = try await client.exchangeRequestToken("request", apiSecret: "secret")
        #expect(session.loginTime == Date(timeIntervalSince1970: expected))
    }
}

@Test func checksumUsesExactUTF8SecretBytesRatherThanHeaderCredentialRules() async throws {
    let transport = ControlledHTTP(authenticationJSON)
    let client = try KiteClient(apiKey: "XXXXXX", transport: transport)
    _ = try await client.exchangeRequestToken("request+&", apiSecret: "secret: ₹")
    let request = try #require(await transport.requests.first)
    #expect(
        String(data: request.body!, encoding: .utf8)
            == "api_key=XXXXXX&request_token=request%2B%26&checksum=33724cbcc31ead10ba37dafaa74fa0db29001e290cf4b0ad27ec8b18630750d2",
    )
}

actor AuthenticationFailure: KiteHTTPTransport {
    var requests: [KiteHTTPRequest] = []
    func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        requests.append(request)
        if request.url.path.contains("/session/") {
            throw URLError(.timedOut)
        }
        return KiteHTTPResponse(statusCode: 200, body: Data(profileJSON.utf8))
    }
}

@Test(arguments: ["exchange", "renew", "invalidate", "refresh-invalidate"])
func authenticationTransportFailureIsSingleAttemptAndPreservesSession(operation: String)
    async throws
{
    let transport = AuthenticationFailure()
    let client = try KiteClient(apiKey: "key", accessToken: "old", transport: transport)
    do {
        switch operation {
        case "exchange": _ = try await client.exchangeRequestToken("request", apiSecret: "secret")
        case "renew": _ = try await client.renewSession(refreshToken: "refresh", apiSecret: "secret")
        case "invalidate": _ = try await client.invalidateSession()
        default: _ = try await client.invalidateRefreshToken("refresh")
        }
        Issue.record("Expected transport failure")
    } catch let KiteError.transport(code, _) {
        #expect(code == URLError.timedOut.rawValue)
    }
    #expect(await transport.requests.count == 1)
    _ = try await client.profile()
    #expect(await transport.requests.last?.headers["Authorization"] == "token key:old")
}

@Test func exchangingOneUsersSessionDoesNotChangeAnotherClient() async throws {
    let transport = ControlledHTTP(authenticationJSON)
    let first = try KiteClient(apiKey: "XXXXXX", accessToken: "first", transport: transport)
    let second = try KiteClient(apiKey: "another", accessToken: "second", transport: transport)
    _ = try await first.exchangeRequestToken("request", apiSecret: "secret")
    _ = try await first.response(for: KiteRequest(path: "/controlled"))
    _ = try await second.response(for: KiteRequest(path: "/controlled"))
    #expect(
        await transport.requests.suffix(2).compactMap { $0.headers["Authorization"] } == [
            "token XXXXXX:XXXXXX", "token another:second",
        ],
    )
    try await first.replaceAccessToken(nil)
    let count = await transport.requests.count
    await #expect(throws: KiteError.self) { try await first.invalidateSession() }
    #expect(await transport.requests.count == count)
}
