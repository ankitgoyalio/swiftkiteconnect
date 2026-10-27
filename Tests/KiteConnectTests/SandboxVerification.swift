//
//  SandboxVerification.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

/// Explicit opt-in only. Session JSON stays outside the repository and CI.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_SESSION_FILE"] != nil))
func `authenticated sandbox verification`() async throws {
    let environment = ProcessInfo.processInfo.environment
    let sessionURL = try URL(fileURLWithPath: #require(environment["KITE_SANDBOX_SESSION_FILE"]))
    let session = try JSONDecoder().decode(SandboxSessionInput.self, from: Data(contentsOf: sessionURL))
    let client = try KiteClient(apiKey: "sandboxdemo", accessToken: session.accessToken, configuration: .sandbox)
    let report = SandboxVerificationReport()
    defer { report.save() }
    let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "HDFCBANK")
    await report.check("profile") { _ = try await client.profile() }
    await report.check("margins") { _ = try await client.margins() }
    await report.check("equity margins") { _ = try await client.margins(segment: .equity) }
    await report.check("holdings") { _ = try await client.holdings() }
    await report.check("positions") { _ = try await client.positions() }
    await report.check("NSE instruments") {
        let instruments = try await client.instruments(exchange: .nse)
        guard !instruments.isEmpty else { throw SandboxVerificationFailure.emptyResponse }
    }
    await report.check("quotes") {
        guard try await client.quotes(instruments: [identity])[identity] != nil else {
            throw SandboxVerificationFailure.emptyResponse
        }
    }
    await report.check("OHLC") {
        guard try await client.ohlc(instruments: [identity])[identity] != nil else {
            throw SandboxVerificationFailure.emptyResponse
        }
    }
    var snapshot: KiteLTPSnapshot?
    await report.check("LTP") {
        snapshot = try await client.ltp(instruments: [identity])[identity]
        guard snapshot != nil else { throw SandboxVerificationFailure.emptyResponse }
    }
    await report.check("orders") { _ = try await client.orders() }
    await report.check("trades") { _ = try await client.trades() }
    await report.check("alerts availability") { _ = try await client.alerts() }
    await report.check("MF orders availability") { _ = try await client.mutualFundOrders() }
    await report.check("MF SIPs availability") { _ = try await client.mutualFundSIPs() }
    await report.check("MF holdings availability") { _ = try await client.mutualFundHoldings() }
    await report.check("MF instruments availability") { _ = try await client.mutualFundInstruments() }
    if let snapshot {
        await report.check("historical availability") {
            let end = Date()
            _ = try await client.historicalCandles(instrumentToken: snapshot.instrumentToken,
                                                   interval: .day, from: end.addingTimeInterval(-7 * 86400), to: end)
        }
        for mode in KiteTickerMode.allCases {
            await report.check("WebSocket \(mode.rawValue)") {
                try await sandboxReceiveTick(session: session, token: snapshot.instrumentToken, mode: mode)
            }
        }
        if environment["KITE_SANDBOX_ORDER_CHECK"] == "1" {
            await sandboxOrderCheck(client: client, snapshot: snapshot, report: report)
        } else {
            report.record("LIMIT lifecycle", "NOT RUN: explicit order opt-in absent")
        }
    }
    report.record("GTT / calculation APIs / MARKET orders", "NOT RUN: documented sandbox exclusions")
    report.record("Browser authorisation / Publisher / delivered postbacks / position conversion",
                  "NOT RUN: requires separate eligible workflow")
    report.record("Recovery / credential replacement / order-update delivery",
                  "NOT RUN: separate session and controlled disconnect scenario required")
    #expect(report.failures == 0, "Inspect .test-results/sandbox-verification.json; unavailable endpoints remain unqualified.")
}

private struct SandboxSessionInput: Decodable, Sendable {
    let accessToken: String
    let userID: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userID = "user_id"
    }
}

private enum SandboxVerificationFailure: Error { case emptyResponse, tickTimeout, unexpectedReceipt }

/// Never serialize raw responses, URLs, credentials, order IDs or server error messages.
private final class SandboxVerificationReport {
    var results: [String: String] = [:]
    var failures = 0
    func record(_ name: String, _ result: String) {
        results[name] = result
    }

    func check(_ name: String, operation: () async throws -> Void) async {
        try? await Task.sleep(for: .seconds(1))
        do {
            try await operation()
            record(name, "PASS")
        } catch {
            failures += 1
            record(name, Self.category(error))
        }
    }

    func save() {
        let directory = URL(fileURLWithPath: ".test-results", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let payload: [String: Any] = ["date": ISO8601DateFormatter().string(from: Date()),
                                          "environment": "sandbox", "results": results]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("sandbox-verification.json"), options: .atomic)
        } catch {
            Issue.record("Could not save sanitized sandbox report")
        }
    }

    static func category(_ error: any Error) -> String {
        switch error {
        case let KiteError.api(api): "FAIL: API HTTP \(api.statusCode)"
        case let KiteError.decoding(status, _): "FAIL: decoding HTTP \(status)"
        case KiteError.transport: "FAIL: transport"
        case KiteError.validation: "FAIL: validation"
        case KiteError.uncertainOutcome: "UNCERTAIN: reconcile before further mutations"
        case SandboxVerificationFailure.tickTimeout: "FAIL: no matching tick within 30 seconds"
        case SandboxVerificationFailure.emptyResponse: "FAIL: expected data missing"
        default: "FAIL: operation (details withheld)"
        }
    }
}

private func sandboxReceiveTick(session: SandboxSessionInput, token: UInt32, mode: KiteTickerMode) async throws {
    let ticker = try KiteTicker(apiKey: "sandboxdemo", accessToken: session.accessToken, userID: session.userID,
                                endpoint: URL(string: "wss://ws-sandbox.kite.trade")!, transport: NIOKiteWebSocketTransport(),
                                reconnectPolicy: .init(initialDelay: .seconds(1), maximumDelay: .seconds(1), maximumAttempts: 0))
    let stream = try await ticker.marketTicks()
    let timeout = Task {
        try await Task.sleep(for: .seconds(30))
        await ticker.disconnect()
    }
    do {
        try await ticker.connect()
        try await ticker.subscribe([token], mode: mode)
        var received = false
        for try await tick in stream where tick.instrumentToken == token {
            switch (mode, tick.details) {
            case (.ltp, .ltp), (.quote, .quote), (.full, .full): received = true
            default: continue
            }
            break
        }
        timeout.cancel()
        await ticker.disconnect()
        guard received else { throw SandboxVerificationFailure.tickTimeout }
    } catch {
        timeout.cancel()
        await ticker.disconnect()
        throw error
    }
}

private func sandboxOrderCheck(client: KiteClient, snapshot: KiteLTPSnapshot, report: SandboxVerificationReport) async {
    // One placement only. No retries or replacement order if the outcome is uncertain.
    var orderID: String?
    await report.check("LIMIT placement") {
        var order = KiteOrderPlacement(tradingSymbol: "HDFCBANK", exchange: .nse,
                                       transactionType: .buy, orderType: .limit, quantity: 1, product: .mis)
        var price = snapshot.lastPrice * Decimal(string: "0.98")!
        var rounded = Decimal()
        NSDecimalRound(&rounded, &price, 1, .down)
        order.price = rounded
        order.tag = "sdkverify27"
        guard case let .order(receipt) = try await client.placeOrder(order) else {
            throw SandboxVerificationFailure.unexpectedReceipt
        }
        orderID = receipt.orderID
    }
    guard let orderID else { return }
    await report.check("order history") { _ = try await client.orderHistory(orderID: orderID) }
    await report.check("order trades") { _ = try await client.orderTrades(orderID: orderID) }
    await report.check("modify OPEN order") {
        guard try await client.orderHistory(orderID: orderID).last?.status == .open else {
            throw SandboxVerificationFailure.emptyResponse
        }
        var changes = KiteOrderModification()
        changes.quantity = 1
        _ = try await client.modifyOrder(orderID: orderID, changes: changes)
    }
    await report.check("cancel OPEN order") {
        guard try await client.orderHistory(orderID: orderID).last?.status == .open else {
            throw SandboxVerificationFailure.emptyResponse
        }
        _ = try await client.cancelOrder(orderID: orderID)
    }
    await report.check("final order history") { _ = try await client.orderHistory(orderID: orderID) }
}
