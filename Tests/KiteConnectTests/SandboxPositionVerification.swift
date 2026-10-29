//
//  SandboxPositionVerification.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_POSITION_FILE"] != nil))
func `sandbox eligible position conversion`() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["KITE_SANDBOX_POSITION_FILE"])
    let session = try JSONDecoder().decode(SandboxSessionInput.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let client = try KiteClient(apiKey: "sandboxdemo", accessToken: session.accessToken, configuration: .sandbox)
    let report = SandboxVerificationReport()
    defer { report.save(filename: "sandbox-position.json") }
    let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "HDFCBANK")
    var opened = false
    var product = KiteProduct.cnc
    var uncertainConversion = false
    await report.check("create eligible simulated position") {
        guard try await client.positions().net.allSatisfy({ $0.identity != identity || $0.quantity == 0 }) else {
            throw SandboxVerificationFailure.unexpectedReceipt
        }
        try await sandboxFillOne(client: client, identity: identity, side: .buy, product: product,
                                 ledgerPath: path + ".position-entry")
        opened = true
        guard try await client.positions().net.contains(where: {
            $0.identity == identity && $0.product == product && $0.quantity == 1
        }) else { throw SandboxVerificationFailure.emptyResponse }
    }
    if opened {
        await report.check("eligible CNC to MIS conversion") {
            do {
                guard try await client.convertPosition(.init(
                    instrument: identity, transactionType: .buy, positionType: .day,
                    quantity: 1, oldProduct: .cnc, newProduct: .mis,
                )) else { throw SandboxVerificationFailure.unexpectedReceipt }
                product = .mis
            } catch let error as KiteError {
                if case .uncertainOutcome = error {
                    uncertainConversion = true
                }
                throw error
            }
            guard try await client.positions().net.contains(where: {
                $0.identity == identity && $0.product == .mis && $0.quantity == 1
            }) else { throw SandboxVerificationFailure.emptyResponse }
        }
        if uncertainConversion {
            report.record("simulated position cleanup", "UNCERTAIN: reconcile conversion before further mutations")
        } else {
            await report.check("close simulated position") {
                try await sandboxFillOne(client: client, identity: identity, side: .sell, product: product,
                                         ledgerPath: path + ".position-exit")
                guard try await client.positions().net.allSatisfy({ $0.identity != identity || $0.quantity == 0 }) else {
                    throw SandboxVerificationFailure.unexpectedReceipt
                }
            }
        }
    }
    #expect(report.failures == 0, "Inspect the sanitized simulated position report.")
}

private func sandboxFillOne(
    client: KiteClient, identity: KiteInstrumentIdentity, side: KiteOrderMutationSide,
    product: KiteProduct, ledgerPath: String,
) async throws {
    guard let snapshot = try await client.ltp(instruments: [identity])[identity] else {
        throw SandboxVerificationFailure.emptyResponse
    }
    let ledger = URL(fileURLWithPath: ledgerPath)
    let tag = "sdk27" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
    let attempt = try SandboxOrderAttempt(url: ledger, tag: tag)
    var price = snapshot.lastPrice * Decimal(string: side == .buy ? "1.02" : "0.98")!
    var rounded = Decimal()
    NSDecimalRound(&rounded, &price, 1, side == .buy ? .up : .down)
    var order = KiteOrderPlacement(tradingSymbol: identity.tradingSymbol, exchange: .nse,
                                   transactionType: side, orderType: .limit, quantity: 1, product: product)
    order.price = rounded
    order.tag = tag
    guard case let .order(receipt) = try await client.placeOrder(order) else {
        throw SandboxVerificationFailure.unexpectedReceipt
    }
    try attempt.acknowledge(orderID: receipt.orderID)
    for _ in 0 ..< 30 {
        try await Task.sleep(for: .seconds(1))
        let history = try await client.orderHistory(orderID: receipt.orderID)
        guard let latest = history.last else { throw SandboxVerificationFailure.emptyResponse }
        if latest.status == .complete {
            return
        }
        if latest.status == .rejected || latest.status == .cancelled {
            throw SandboxVerificationFailure.unexpectedReceipt
        }
    }
    if try await client.orderHistory(orderID: receipt.orderID).last?.status == .open {
        _ = try await client.cancelOrder(orderID: receipt.orderID)
    }
    throw SandboxVerificationFailure.emptyResponse
}
