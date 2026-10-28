import Foundation

/// Retry delays double up to maximumDelay. Attempts are bounded per interruption.
public struct KiteTickerReconnectPolicy: Sendable {
  public let initialDelay: Duration
  public let maximumDelay: Duration
  public let maximumAttempts: Int
  public init(
    initialDelay: Duration = .seconds(1), maximumDelay: Duration = .seconds(30),
    maximumAttempts: Int = 10
  ) {
    self.initialDelay = initialDelay
    self.maximumDelay = maximumDelay
    self.maximumAttempts = maximumAttempts
  }
}

/// A cancellation-aware time boundary. Tests can advance pending waits explicitly.
public protocol KiteTickerSleeper: Sendable {
  func sleep(for delay: Duration) async throws
}

public struct KiteTickerContinuousSleeper: KiteTickerSleeper {
  public init() {}
  public func sleep(for delay: Duration) async throws { try await Task.sleep(for: delay) }
}

/// Recovery never replays missed quotes or order updates. Applications own reconciliation.
public enum KiteTickerLifecycleEvent: Sendable, Equatable {
  case connected
  case possibleDataGap
  case reconnected
  case authenticationRequired
  case recoveryExhausted
  case disconnected
}
