//
//  SandboxScenarioVerification.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_SCENARIOS_FILE"] != nil))
func `sandbox remaining scenarios`() async throws {
    let environment = ProcessInfo.processInfo.environment
    let path = try #require(environment["KITE_SANDBOX_SCENARIOS_FILE"])
    let session = try JSONDecoder().decode(SandboxSessionInput.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let client = try KiteClient(apiKey: "sandboxdemo", accessToken: session.accessToken, configuration: .sandbox)
    let report = SandboxVerificationReport()
    defer { report.save(filename: "sandbox-scenarios.json") }
    let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "HDFCBANK")
    var snapshot: KiteLTPSnapshot?
    await report.check("scenario LTP") {
        snapshot = try await client.ltp(instruments: [identity])[identity]
        guard snapshot != nil else { throw SandboxVerificationFailure.emptyResponse }
    }
    if let snapshot {
        for mode in KiteTickerMode.allCases {
            await report.check("remote recovery \(mode.rawValue)") {
                try await sandboxRecoveryCheck(session: session, token: snapshot.instrumentToken, mode: mode)
            }
        }
        if let replacementPath = environment["KITE_SANDBOX_REPLACEMENT_FILE"] {
            let replacement = try JSONDecoder().decode(
                SandboxSessionInput.self, from: Data(contentsOf: URL(fileURLWithPath: replacementPath)),
            )
            if session.accessToken == replacement.accessToken {
                report.record("remote credential replacement", "NOT TESTED: sandbox login reused the same access token")
            } else {
                await report.check("remote credential replacement") {
                    try await sandboxReplacementCheck(session: session, replacement: replacement, token: snapshot.instrumentToken)
                }
            }
        } else {
            report.record("remote credential replacement", "NOT TESTED: second authenticated session required")
        }
        if environment["KITE_SANDBOX_ORDER_CHECK"] == "1" {
            await sandboxObservedOrderCheck(client: client, session: session, snapshot: snapshot, report: report)
        }
    }
    await report.check("holdings authorisation initiation") { _ = try await client.authoriseHoldings() }
    await report.check("position conversion eligibility") {
        let positions = try await client.positions()
        report.record("eligible position conversion", positions.net.contains { $0.quantity != 0 }
            ? "NOT TESTED: requires selection of an eligible existing position"
            : "NOT TESTED: no open position")
    }
    #expect(report.failures == 0, "Inspect the sanitized sandbox scenario report.")
}

func sandboxObservedOrderCheck(
    client: KiteClient, session: SandboxSessionInput, snapshot: KiteLTPSnapshot,
    report: SandboxVerificationReport,
) async {
    do {
        let shapes = SandboxWireShapes()
        let ticker = try sandboxTicker(session: session, transport: SandboxObservedTransport(shapes: shapes))
        let stream = try await ticker.orderUpdates()
        let events = SandboxOrderEvents()
        let consumer = Task {
            for try await event in stream {
                await events.append(event)
            }
        }
        let timeout = Task {
            try await Task.sleep(for: .seconds(60))
            await ticker.disconnect()
        }
        do {
            let ticks = try await ticker.marketTicks()
            try await ticker.connect()
            try await ticker.subscribe([snapshot.instrumentToken], mode: .ltp)
            try await sandboxRequireTick(ticks, token: snapshot.instrumentToken, mode: .ltp)
            let orderID = await sandboxOrderCheck(client: client, snapshot: snapshot, report: report)
            if let orderID {
                await report.check("streamed CANCELLED order update") {
                    // Bounded observation only; never resubmit a mutation to obtain an event.
                    for _ in 0 ..< 30 {
                        if await events.received(orderID: orderID, status: .cancelled) {
                            return
                        }
                        try await Task.sleep(for: .seconds(1))
                    }
                    throw SandboxVerificationFailure.emptyResponse
                }
            }
            await ticker.disconnect()
            do {
                try await consumer.value
                report.record("order-update decoder", "PASS: stream ended normally")
            } catch {
                report.record("order-update decoder", SandboxVerificationReport.category(error))
                report.failures += 1
            }
            let summary = await shapes.summary()
            report.record("order-update wire shapes", summary.isEmpty ? "No text messages received" : summary.description)
            consumer.cancel()
            timeout.cancel()
        } catch {
            await ticker.disconnect()
            consumer.cancel()
            timeout.cancel()
            throw error
        }
    } catch {
        report.record("order-update observation", SandboxVerificationReport.category(error))
        report.failures += 1
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_OBSERVED_ORDER_FILE"] != nil))
func `sandbox observed order lifecycle`() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["KITE_SANDBOX_OBSERVED_ORDER_FILE"])
    let session = try JSONDecoder().decode(SandboxSessionInput.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let client = try KiteClient(apiKey: "sandboxdemo", accessToken: session.accessToken, configuration: .sandbox)
    let report = SandboxVerificationReport()
    defer { report.save(filename: "sandbox-observed-order.json") }
    let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "HDFCBANK")
    var snapshot: KiteLTPSnapshot?
    await report.check("observed order LTP") {
        snapshot = try await client.ltp(instruments: [identity])[identity]
        guard snapshot != nil else { throw SandboxVerificationFailure.emptyResponse }
    }
    if let snapshot {
        await sandboxObservedOrderCheck(client: client, session: session, snapshot: snapshot, report: report)
    }
    #expect(report.failures == 0, "Inspect the sanitized order-update report.")
}
