//
//  KiteTickerRecovery.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// Retry delays double up to maximumDelay. Attempts are bounded per interruption.
public struct KiteTickerReconnectPolicy: Sendable {
    /// The first retry delay after each connection interruption.
    public let initialDelay: Duration
    /// The cap on exponential retry delay, at most one hour.
    public let maximumDelay: Duration
    /// Maximum retries per interruption. Zero disables automatic connection attempts.
    public let maximumAttempts: Int
    /// Stores retry bounds, which the ticker validates when initialized.
    /// - Parameters:
    ///   - initialDelay: Positive first delay. Defaults to one second.
    ///   - maximumDelay: At least the initial delay and at most one hour. Defaults to 30 seconds.
    ///   - maximumAttempts: Retry count in 0...1000. Defaults to ten attempts.
    public init(
        initialDelay: Duration = .seconds(1), maximumDelay: Duration = .seconds(30),
        maximumAttempts: Int = 10,
    ) {
        self.initialDelay = initialDelay
        self.maximumDelay = maximumDelay
        self.maximumAttempts = maximumAttempts
    }
}

/// A cancellation-aware time boundary. Tests can advance pending waits explicitly.
public protocol KiteTickerSleeper: Sendable {
    /// Waits for the recovery delay and throws when cancelled.
    /// - Parameter delay: Positive duration requested by the reconnect policy.
    func sleep(for delay: Duration) async throws
}

/// Production recovery delay provider backed by the Swift task clock.
public struct KiteTickerContinuousSleeper: KiteTickerSleeper {
    /// Creates a task-clock sleeper without starting a wait.
    public init() {}
    /// Suspends for the requested duration or throws on task cancellation.
    /// - Parameter delay: Duration before the next reconnect attempt.
    public func sleep(for delay: Duration) async throws {
        try await Task.sleep(for: delay)
    }
}

/// Recovery never replays missed quotes or order updates. Applications own reconciliation.
public enum KiteTickerLifecycleEvent: Sendable, Equatable {
    /// The initial socket is established and desired subscriptions are restored.
    case connected
    /// An interruption may have lost ticks or order updates. No replay follows.
    case possibleDataGap
    /// A replacement socket is established and desired subscriptions are restored.
    case reconnected
    /// Recovery is blocked until the application supplies fresh credentials.
    case authenticationRequired
    /// The bounded retry budget ended. Streams remain open until explicitly disconnected.
    case recoveryExhausted
    /// An explicit disconnect has finished the ticker lifecycle and its streams.
    case disconnected
}
