//
//  KiteTickerSubscriptions.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

public extension KiteTicker {
    /// Subscribes nonzero instrument tokens in LTP mode.
    ///
    /// Equivalent to `subscribe(_:mode:)` with `.ltp`, including its limits and errors.
    /// - Parameter tokens: Nonempty nonzero tokens, with at most 3000 unique desired subscriptions.
    /// - Throws: Invalid configuration, inactive lifecycle, concurrent command, transport,
    ///   or cancellation errors, as with subscribe(_:mode:).
    func subscribe(_ tokens: [UInt32]) async throws {
        try await subscribe(tokens, mode: .ltp)
    }

    /// Adds desired instrument tokens and requests their subscription mode.
    ///
    /// During recovery, records the desired state for restoration. A failed write can leave
    /// server state uncertain. Serialize commands to avoid `operationInProgress`.
    /// - Parameters:
    ///   - tokens: Nonempty nonzero tokens, with at most 3000 unique desired tokens in total.
    ///   - mode: The requested layout. Incoming packet length determines actual tick details.
    /// - Throws: Invalid configuration, inactive lifecycle, concurrent command, transport, or cancellation errors.
    func subscribe(_ tokens: [UInt32], mode: KiteTickerMode) async throws {
        guard !tokens.isEmpty, tokens.allSatisfy({ $0 > 0 }), subscriptions.union(tokens).count <= 3000
        else {
            throw KiteTickerError.invalidConfiguration("Subscribe to 1...3000 nonzero instrument tokens")
        }
        guard active else { throw KiteTickerError.notConnected }
        guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
        try Task.checkCancellation()
        subscriptions.formUnion(tokens)
        for token in tokens {
            modes[token] = mode
        }
        desiredRevision = UUID()
        guard let connection, !connecting else { return }
        let operation = UUID()
        commandOperation = operation
        defer {
            if commandOperation == operation {
                commandOperation = nil
            }
        }
        let epoch = generation
        try Task.checkCancellation()
        do {
            try await send(command("subscribe", tokens), on: connection, epoch: epoch)
            guard epoch == generation else { throw CancellationError() }
            try await send(modeCommand(mode, tokens), on: connection, epoch: epoch)
            guard epoch == generation else { throw CancellationError() }
        } catch {
            await failed(error, epoch: epoch)
            throw error
        }
    }

    /// Changes the desired mode for currently subscribed tokens, including during recovery.
    ///
    /// Serialize commands at the call site. Incoming layouts can reflect an earlier mode.
    /// - Parameters:
    ///   - mode: Requested market-data detail level.
    ///   - tokens: Nonempty nonzero tokens already in the desired subscription set.
    /// - Throws: Invalid configuration, inactive lifecycle, concurrent command, transport, or cancellation errors.
    func setMode(_ mode: KiteTickerMode, for tokens: [UInt32]) async throws {
        guard !tokens.isEmpty, tokens.allSatisfy({ $0 > 0 }) else {
            throw KiteTickerError.invalidConfiguration("Supply nonzero instrument tokens")
        }
        guard active else { throw KiteTickerError.notConnected }
        guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
        guard Set(tokens).isSubset(of: subscriptions) else {
            throw KiteTickerError.invalidConfiguration("Mode changes require subscribed tokens")
        }
        try Task.checkCancellation()
        for token in tokens {
            modes[token] = mode
        }
        desiredRevision = UUID()
        guard let connection, !connecting else { return }
        let operation = UUID()
        commandOperation = operation
        defer {
            if commandOperation == operation {
                commandOperation = nil
            }
        }
        let epoch = generation
        do {
            try Task.checkCancellation()
            try await send(modeCommand(mode, tokens), on: connection, epoch: epoch)
            guard epoch == generation else { throw CancellationError() }
        } catch {
            await failed(error, epoch: epoch)
            throw error
        }
    }

    /// Removes tokens from desired subscriptions and sends the command when connected.
    ///
    /// During recovery, updates the state to restore. Serialize this with other subscription commands.
    /// - Parameter tokens: A nonempty list of nonzero instrument tokens.
    /// - Throws: Invalid configuration, inactive lifecycle, concurrent command, transport, or cancellation errors.
    func unsubscribe(_ tokens: [UInt32]) async throws {
        guard !tokens.isEmpty, tokens.allSatisfy({ $0 > 0 }) else {
            throw KiteTickerError.invalidConfiguration("Supply nonzero instrument tokens")
        }
        guard active else { throw KiteTickerError.notConnected }
        guard commandOperation == nil else { throw KiteTickerError.operationInProgress }
        try Task.checkCancellation()
        subscriptions.subtract(tokens)
        for token in tokens {
            modes.removeValue(forKey: token)
        }
        desiredRevision = UUID()
        guard let connection, !connecting else { return }
        let operation = UUID()
        commandOperation = operation
        defer {
            if commandOperation == operation {
                commandOperation = nil
            }
        }
        let epoch = generation
        do {
            try Task.checkCancellation()
            try await send(command("unsubscribe", tokens), on: connection, epoch: epoch)
            guard epoch == generation else { throw CancellationError() }
        } catch {
            await failed(error, epoch: epoch)
            throw error
        }
    }
}
