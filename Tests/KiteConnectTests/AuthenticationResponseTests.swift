//
//  AuthenticationResponseTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test(arguments: ["exchange", "renew"], ["", "bad:token", "bad token", "bad\r\ntoken", "bad\u{7F}token"])
func `malformed server access token is decoding failure`(operation: String, token: String) async throws {
    let body: String
    if operation == "exchange" {
        let encoded = try #require(try String(data: JSONEncoder().encode(token), encoding: .utf8))
        body = authenticationJSON.replacingOccurrences(
            of: #""access_token": "XXXXXX""#, with: #""access_token": "# + encoded,
        )
    } else {
        let data = try JSONSerialization.data(withJSONObject: [
            "status": "success", "data": ["access_token": token],
        ])
        body = try #require(String(data: data, encoding: .utf8))
    }
    let transport = ControlledHTTP(body, status: 202)
    let client = try KiteClient(apiKey: "XXXXXX", accessToken: "previous", transport: transport)
    do {
        if operation == "exchange" {
            _ = try await client.exchangeRequestToken("request-credential", apiSecret: "secret-credential")
        } else {
            _ = try await client.renewSession(refreshToken: "refresh-credential", apiSecret: "secret-credential")
        }
        Issue.record("Expected malformed access_token to fail decoding")
    } catch let KiteError.decoding(status, message) {
        #expect(status == 202)
        #expect(message.contains("access_token"))
        for credential in [token, "request-credential", "refresh-credential", "secret-credential", "previous"] where !credential.isEmpty {
            #expect(!message.contains(credential))
        }
    }
    #expect(await transport.requests.count == 1)
    _ = try await client.response(for: KiteRequest(path: "/controlled"))
    #expect(await transport.requests.last?.headers["Authorization"] == "token XXXXXX:previous")
}

@Test(arguments: ["api_key", "login_time"], [201, 206])
func `invalid exchange response retains status and field`(field: String, status: Int) async throws {
    let body = field == "api_key"
        ? authenticationJSON.replacingOccurrences(of: #""api_key": "XXXXXX""#, with: #""api_key": "other-key-credential""#)
        : authenticationJSON.replacingOccurrences(of: "2021-01-01 16:15:14", with: "invalid-login-time")
    let transport = ControlledHTTP(body, status: status)
    let client = try KiteClient(apiKey: "XXXXXX", accessToken: "previous", transport: transport)
    do {
        _ = try await client.exchangeRequestToken("request-credential", apiSecret: "secret-credential")
        Issue.record("Expected malformed session response to fail decoding")
    } catch let KiteError.decoding(receivedStatus, message) {
        #expect(receivedStatus == status)
        #expect(message.contains(field))
        for value in ["XXXXXX", "other-key-credential", "invalid-login-time", "request-credential", "secret-credential", "previous"] {
            #expect(!message.contains(value))
        }
    }
    #expect(await transport.requests.count == 1)
    _ = try await client.response(for: KiteRequest(path: "/controlled"))
    #expect(await transport.requests.last?.headers["Authorization"] == "token XXXXXX:previous")
}

@Test(arguments: ["exchange-request", "exchange-secret", "renew-refresh", "renew-secret"], ["", " \t\n"])
func `invalid local authentication input remains validation failure`(operation: String, input: String) async throws {
    let transport = ControlledHTTP()
    let client = try KiteClient(apiKey: "XXXXXX", accessToken: "previous", transport: transport)
    let expectedField = switch operation {
    case "exchange-request": "requestToken"
    case "renew-refresh": "refreshToken"
    default: "apiSecret"
    }
    do {
        switch operation {
        case "exchange-request": _ = try await client.exchangeRequestToken(input, apiSecret: "secret")
        case "exchange-secret": _ = try await client.exchangeRequestToken("request", apiSecret: input)
        case "renew-refresh": _ = try await client.renewSession(refreshToken: input, apiSecret: "secret")
        default: _ = try await client.renewSession(refreshToken: "refresh", apiSecret: input)
        }
        Issue.record("Expected invalid local input to fail validation")
    } catch let KiteError.validation(field, _) {
        #expect(field == expectedField)
    }
    #expect(await transport.requests.isEmpty)
    _ = try await client.profile()
    #expect(await transport.requests.last?.headers["Authorization"] == "token XXXXXX:previous")
}

@Test(arguments: ["exchange", "renew"], ["missing", "null", "number"])
func `invalid server token field retains decoding context`(operation: String, shape: String) async throws {
    let field = switch shape {
    case "missing": ""
    case "null": #""access_token": null,"#
    default: #""access_token": 123,"#
    }
    let body = operation == "exchange"
        ? authenticationJSON.replacingOccurrences(of: #""access_token": "XXXXXX","#, with: field)
        : #"{"status":"success","data":{"# + field + #""refresh_token":"refresh-credential"}}"#
    let transport = ControlledHTTP(body, status: 203)
    let client = try KiteClient(apiKey: "XXXXXX", accessToken: "previous", transport: transport)
    do {
        if operation == "exchange" {
            _ = try await client.exchangeRequestToken("request-credential", apiSecret: "secret-credential")
        } else {
            _ = try await client.renewSession(refreshToken: "refresh-credential", apiSecret: "secret-credential")
        }
        Issue.record("Expected invalid access_token field to fail decoding")
    } catch let KiteError.decoding(status, message) {
        #expect(status == 203)
        #expect(message.contains("access_token"))
        for credential in ["XXXXXX", "request-credential", "refresh-credential", "secret-credential", "previous"] {
            #expect(!message.contains(credential))
        }
    }
    #expect(await transport.requests.count == 1)
    _ = try await client.response(for: KiteRequest(path: "/controlled"))
    #expect(await transport.requests.last?.headers["Authorization"] == "token XXXXXX:previous")
}
