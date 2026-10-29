//
//  SandboxAuthenticationVerification.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

/// Exchanges a browser callback once; private input/output stays outside Git.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_EXCHANGE_FILE"] != nil))
func `sandbox SDK request token exchange`() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["KITE_SANDBOX_EXCHANGE_FILE"])
    let url = URL(fileURLWithPath: path)
    let input = try JSONDecoder().decode(SandboxExchangeInput.self, from: Data(contentsOf: url))
    let client = try KiteClient(apiKey: "sandboxdemo", configuration: .sandbox)
    do {
        let session = try await client.exchangeRequestToken(input.requestToken, apiSecret: "sandboxdemo-secret")
        let data = try JSONSerialization.data(withJSONObject: [
            "access_token": session.accessToken, "user_id": session.profile.userID,
            "refresh_token": session.refreshToken,
        ])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        _ = try await client.profile()
    } catch {
        // Never let Swift Testing print credential-bearing server diagnostics.
        switch error {
        case let KiteError.api(api): Issue.record("Sandbox SDK exchange failed: API HTTP \(api.statusCode)")
        case let KiteError.decoding(status, _): Issue.record("Sandbox SDK exchange failed: decoding HTTP \(status)")
        default: Issue.record("Sandbox SDK exchange failed (private details withheld)")
        }
    }
}

private struct SandboxExchangeInput: Decodable {
    let requestToken: String
    enum CodingKeys: String, CodingKey { case requestToken = "request_token" }
}

/// Only run when the authenticated session actually supplied a refresh token.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_RENEW_FILE"] != nil))
func `sandbox SDK session renewal`() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["KITE_SANDBOX_RENEW_FILE"])
    let url = URL(fileURLWithPath: path)
    let input = try JSONDecoder().decode(SandboxRenewalInput.self, from: Data(contentsOf: url))
    let client = try KiteClient(apiKey: "sandboxdemo", accessToken: input.accessToken, configuration: .sandbox)
    let report = SandboxVerificationReport()
    defer { report.save(filename: "sandbox-renewal.json") }
    if input.refreshToken.isEmpty {
        report.record("SDK renewal", "NOT TESTED: session supplied no refresh token")
        return
    }
    await report.check("SDK renewal") {
        let renewed = try await client.renewSession(refreshToken: input.refreshToken, apiSecret: "sandboxdemo-secret")
        let data = try JSONSerialization.data(withJSONObject: [
            "access_token": renewed.accessToken, "user_id": input.userID,
            "refresh_token": renewed.refreshToken ?? input.refreshToken,
        ])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        _ = try await client.profile()
        report.record("renewal changed access token", renewed.accessToken == input.accessToken ? "NO" : "YES")
    }
    #expect(report.failures == 0, "Inspect the sanitized sandbox renewal report.")
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_LOGOUT_FILE"] != nil))
func `sandbox SDK session logout`() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["KITE_SANDBOX_LOGOUT_FILE"])
    let input = try JSONDecoder().decode(SandboxSessionInput.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let client = try KiteClient(apiKey: "sandboxdemo", accessToken: input.accessToken, configuration: .sandbox)
    let report = SandboxVerificationReport()
    defer { report.save(filename: "sandbox-logout.json") }
    await report.check("SDK logout confirmation") {
        guard try await client.invalidateSession() else { throw SandboxVerificationFailure.unexpectedReceipt }
    }
    if report.failures == 0 {
        await report.check("server rejects revoked access token") {
            let old = try KiteClient(apiKey: "sandboxdemo", accessToken: input.accessToken, configuration: .sandbox)
            do {
                _ = try await old.profile()
                throw SandboxVerificationFailure.unexpectedReceipt
            } catch let KiteError.api(api) where api.statusCode == 401 || api.statusCode == 403 {
                return
            }
        }
    }
    #expect(report.failures == 0, "Inspect the sanitized sandbox logout report.")
}

private struct SandboxRenewalInput: Decodable {
    let accessToken: String
    let userID: String
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", userID = "user_id", refreshToken = "refresh_token"
    }
}
