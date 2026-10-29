//
//  ProfileTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

let profileJSON =
    #"{"status":"success","data":{"user_id":"AB1234","user_type":"individual","email":"a@example.test","user_name":"Example User","user_shortname":"Example","broker":"ZERODHA","exchanges":["NSE","FUTURE"],"products":["CNC"],"order_types":["LIMIT"],"avatar_url":null,"meta":{"demat_consent":"physical"},"future":true}}"#

actor ControlledHTTP: KiteHTTPTransport {
    var requests: [KiteHTTPRequest] = []
    let response: KiteHTTPResponse
    init(_ body: String = profileJSON, status: Int = 200) {
        response = KiteHTTPResponse(statusCode: status, body: Data(body.utf8))
    }

    func send(_ request: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        requests.append(request)
        return response
    }
}

@Test func profileUsesVersionAndIsolatedCredentials() async throws {
    let transport = ControlledHTTP()
    let client = try KiteClient(apiKey: "key", accessToken: "session", transport: transport)
    let profile = try await client.profile()
    #expect(profile.userID == "AB1234")
    #expect(profile.exchanges == [.nse, .unknown("FUTURE")])
    #expect(profile.avatarURL == nil)
    let requests = await transport.requests
    #expect(requests.count == 1)
    #expect(requests[0].url.absoluteString == "https://api.kite.trade/user/profile")
    #expect(requests[0].method == .get)
    #expect(requests[0].headers["Authorization"] == "token key:session")
    #expect(requests[0].headers["X-Kite-Version"] == "3")
}

@Test func sandboxRoutingAndTimeout() async throws {
    let transport = ControlledHTTP()
    let config = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms", timeout: 7,
    )
    let client = try KiteClient(
        apiKey: "sandboxdemo", accessToken: "test", configuration: config, transport: transport,
    )
    _ = try await client.profile()
    _ = try await client.response(for: KiteRequest(path: "/instruments/NSE", isInstrumentDump: true))
    let requests = await transport.requests
    #expect(requests.map(\.url.path) == ["/oms/user/profile", "/instruments/NSE"])
    #expect(requests.allSatisfy { $0.timeout == 7 })
}

@Test func rateLimitAndUnknownErrorsAreNeverRetried() async throws {
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FutureException","message":"Slow down"}"#, status: 429,
    )
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    do {
        _ = try await client.profile()
        Issue.record("Expected API failure")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == 429)
        #expect(error.errorType == "FutureException")
        #expect(error.message == "Slow down")
    }
    #expect(await transport.requests.count == 1)
}

@Test func malformedRequiredProfileFailsClearly() async throws {
    let transport = ControlledHTTP(
        profileJSON.replacingOccurrences(of: #""user_id":"AB1234","#, with: ""),
    )
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    do {
        _ = try await client.profile()
        Issue.record("Expected decoding failure")
    } catch let KiteError.decoding(status, message) {
        #expect(status == 200)
        #expect(message.contains("user_id"))
    }
}

@Test func concurrentClientsAndReplacementKeepSessionsIsolated() async throws {
    let transport = ControlledHTTP()
    let first = try KiteClient(apiKey: "one", accessToken: "old", transport: transport)
    let second = try KiteClient(apiKey: "two", accessToken: "other", transport: transport)
    async let a = first.profile()
    async let b = second.profile()
    _ = try await (a, b)
    try await first.replaceAccessToken("new")
    _ = try await first.profile()
    let requests = await transport.requests
    #expect(
        Set(requests.prefix(2).compactMap { $0.headers["Authorization"] }) == [
            "token one:old", "token two:other",
        ],
    )
    #expect(requests.last?.headers["Authorization"] == "token one:new")
    try await first.replaceAccessToken(nil)
    await #expect(throws: KiteError.self) { try await first.profile() }
    #expect(await transport.requests.count == 3)
}

actor FailingHTTP: KiteHTTPTransport {
    var attempts = 0
    func send(_: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        attempts += 1
        throw URLError(.timedOut)
    }
}

@Test func transportFailuresAreSingleAttemptAndMutationOutcomesUncertain() async throws {
    let transport = FailingHTTP()
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    do {
        _ = try await client.profile()
        Issue.record("Expected transport failure")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    do {
        _ = try await client.response(
            for: KiteRequest(method: .post, path: "/controlled-mutation", isTradingMutation: true),
        )
        Issue.record("Expected uncertainty")
    } catch let KiteError.uncertainOutcome(.transport(code, _)) {
        #expect(code == URLError.timedOut.rawValue)
    }
    #expect(await transport.attempts == 2)
}

struct CancelledHTTP: KiteHTTPTransport {
    func send(_: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        throw URLError(.cancelled)
    }
}

@Test func cancellationRemainsRecognizable() async throws {
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: CancelledHTTP())
    await #expect(throws: CancellationError.self) { try await client.profile() }
}

@Test func invalidConfigurationAndCredentialsFailBeforeNetworking() throws {
    #expect(throws: KiteError.self) { try KiteClient(apiKey: "bad\r\nkey") }
    #expect(throws: KiteError.self) { try KiteConfiguration(timeout: 0) }
    #expect(throws: KiteError.self) {
        try KiteConfiguration(baseURL: URL(string: "https://example.test?secret=1")!)
    }
}

@Test func formQueryAndJSONEncodingPreserveRepeatedValues() async throws {
    let transport = ControlledHTTP()
    let client = try KiteClient(apiKey: "key", transport: transport)
    _ = try await client.response(
        for: KiteRequest(
            method: .post, path: "/controlled", query: [.init("i", "NSE:A B"), .init("i", "NSE:C+D")],
            body: .form([.init("tag", "a&b=+₹")]), authenticated: false,
        ),
    )
    _ = try await client.response(
        for: KiteRequest(
            method: .put, path: "/controlled", body: .json(Data(#"{"price":123.45}"#.utf8)),
            authenticated: false,
        ),
    )
    let requests = await transport.requests
    #expect(requests[0].url.query == "i=NSE%3AA%20B&i=NSE%3AC%2BD")
    #expect(String(data: requests[0].body!, encoding: .utf8) == "tag=a%26b%3D%2B%E2%82%B9")
    #expect(requests[0].headers["Authorization"] == nil)
    #expect(requests[0].headers["Content-Type"] == "application/x-www-form-urlencoded")
    #expect(requests[1].headers["Content-Type"] == "application/json")
    #expect(requests[1].body == Data(#"{"price":123.45}"#.utf8))
}

@Test func knownAndUnknownServerValuesRemainTyped() async throws {
    let transport = ControlledHTTP(
        profileJSON.replacingOccurrences(of: #"["CNC"]"#, with: #"["CNC","FUTURE_PRODUCT"]"#),
    )
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    let profile = try await client.profile()
    #expect(profile.products == [.cnc, .unknown("FUTURE_PRODUCT")])
    #expect(profile.orderTypes == [.limit])
    #expect(profile.exchanges == [.nse, .unknown("FUTURE")])
}

actor SuspendedHTTP: KiteHTTPTransport {
    let started: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    init() {
        (started, continuation) = AsyncStream.makeStream()
    }

    func send(_: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        continuation.yield(())
        try await Task.sleep(for: .seconds(60))
        return KiteHTTPResponse(statusCode: 200, body: Data(profileJSON.utf8))
    }
}

@Test func cancellingInFlightTaskCancelsTransport() async throws {
    let transport = SuspendedHTTP()
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    let operation = Task { try await client.profile() }
    for await _ in transport.started {
        break
    }
    operation.cancel()
    await #expect(throws: CancellationError.self) { try await operation.value }
}

@Test func confirmedMutationRejectionAndLostGatewayResponseDiffer() async throws {
    let rejection = ControlledHTTP(
        #"{"status":"error","error_type":"OrderException","message":"Rejected"}"#, status: 400,
    )
    let gateway = ControlledHTTP("Gateway unavailable", status: 502)
    let rejectedClient = try KiteClient(apiKey: "key", accessToken: "token", transport: rejection)
    let uncertainClient = try KiteClient(apiKey: "key", accessToken: "token", transport: gateway)
    let mutation = KiteRequest(method: .post, path: "/controlled-mutation", isTradingMutation: true)
    do {
        _ = try await rejectedClient.response(for: mutation)
        Issue.record("Expected rejection")
    } catch let KiteError.api(error) { #expect(error.errorType == "OrderException") }
    do {
        _ = try await uncertainClient.response(for: mutation)
        Issue.record("Expected uncertainty")
    } catch let KiteError.uncertainOutcome(.api(error)) { #expect(error.statusCode == 502) }
    #expect(await rejection.requests.count == 1)
    #expect(await gateway.requests.count == 1)
}

@Test func malformedErrorEnvelopeRetainsAvailableKiteDetails() async throws {
    let transport = ControlledHTTP(#"{"status":"error","error_type":"FutureException"}"#, status: 503)
    let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
    do {
        _ = try await client.profile()
        Issue.record("Expected API failure")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == 503)
        #expect(error.errorType == "FutureException")
        #expect(error.message == "HTTP 503")
    }
}

struct ApplicationFailureHTTP: KiteHTTPTransport {
    func send(_: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        throw NSError(domain: "ControlledApplication", code: -999)
    }
}

@Test func unrelatedTransportErrorCodeIsNotCancellation() async throws {
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", transport: ApplicationFailureHTTP(),
    )
    do {
        _ = try await client.profile()
        Issue.record("Expected transport failure")
    } catch let KiteError.transport(code, _) { #expect(code == -999) }
}

@Test func typedSessionCredentialsConstructAnIsolatedClient() async throws {
    let transport = ControlledHTTP()
    let credentials = KiteSessionCredentials(apiKey: "typed-key", accessToken: "typed-token")
    let client = try KiteClient(session: credentials, transport: transport)
    _ = try await client.profile()
    #expect(await transport.requests.first?.headers["Authorization"] == "token typed-key:typed-token")
}
