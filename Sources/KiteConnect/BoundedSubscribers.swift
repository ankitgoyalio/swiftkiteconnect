//
//  BoundedSubscribers.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// Actor-owned policy shared by independent, typed event registries.
struct BoundedSubscribers<Element: Sendable> {
    private var continuations: [UUID: AsyncThrowingStream<Element, any Error>.Continuation] = [:]

    mutating func stream(
        capacity: Int, onTermination: @escaping @Sendable (UUID) -> Void,
    ) throws -> AsyncThrowingStream<Element, any Error> {
        guard capacity > 0 else {
            throw KiteTickerError.invalidConfiguration("Buffer capacity must be positive")
        }
        let id = UUID()
        let (stream, continuation) = AsyncThrowingStream<Element, any Error>.makeStream(
            bufferingPolicy: .bufferingOldest(capacity),
        )
        continuations[id] = continuation
        continuation.onTermination = { _ in onTermination(id) }
        return stream
    }

    mutating func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    mutating func yield(_ event: Element) {
        for (id, continuation) in continuations {
            switch continuation.yield(event) {
            case .dropped:
                continuation.finish(throwing: KiteTickerError.bufferOverflow)
                continuations.removeValue(forKey: id)
            case .terminated: continuations.removeValue(forKey: id)
            case .enqueued: break
            @unknown default: break
            }
        }
    }

    mutating func finish(throwing error: any Error? = nil) {
        let current = continuations.values
        continuations.removeAll()
        for continuation in current {
            continuation.finish(throwing: error)
        }
    }
}
