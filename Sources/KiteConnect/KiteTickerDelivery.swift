//
//  KiteTickerDelivery.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

extension KiteTicker {
    func command(_ action: String, _ tokens: [UInt32]) throws -> String {
        try String(
            decoding: JSONSerialization.data(withJSONObject: ["a": action, "v": tokens]),
            as: UTF8.self,
        )
    }

    func modeCommand(_ mode: KiteTickerMode, _ tokens: [UInt32]) throws -> String {
        try String(
            decoding: JSONSerialization.data(withJSONObject: [
                "a": "mode", "v": [mode.rawValue, tokens],
            ]),
            as: UTF8.self,
        )
    }

    func removeBrokerSubscriber(_ id: UUID) {
        brokerSubscribers.remove(id)
    }

    func removeOrderSubscriber(_ id: UUID) {
        orderSubscribers.remove(id)
    }

    func removeMarketSubscriber(_ id: UUID) {
        marketSubscribers.remove(id)
    }

    func removeSubscriber(_ id: UUID) {
        subscribers.remove(id)
    }

    func failed(_ error: any Error, epoch: UUID, schedule: Bool = true) async {
        guard epoch == generation, active else { return }
        generation = UUID()
        connecting = false
        let closing = retireConnection()
        receiver?.cancel()
        receiver = nil
        commandOperation = nil
        let authentication = Self.isAuthenticationFailure(error)
        let terminal = switch error as? KiteTickerError {
        case .malformedPacket, .malformedText, .unsupportedPacketLength, .invalidConfiguration:
            true
        default: false
        }
        if terminal {
            active = false
            subscribers.finish(throwing: error)
            marketSubscribers.finish(throwing: error)
            brokerSubscribers.finish(throwing: error)
            orderSubscribers.finish(throwing: error)
            lifecycleSubscribers.finish(throwing: error)
        } else {
            if schedule {
                emit(.possibleDataGap)
            }
            if authentication {
                authenticationBlocked = true
                recoveryID = UUID()
                recovery?.cancel()
                recovery = nil
                emit(.authenticationRequired)
            } else if schedule {
                startRecovery()
            }
        }
        await closing.value
    }

    private static func isAuthenticationFailure(_ error: any Error) -> Bool {
        switch error as? KiteTickerError {
        case .authenticationRequired, .handshakeRejected(statusCode: 401),
             .handshakeRejected(statusCode: 403):
            true
        default: false
        }
    }

    /// The protocol supplies only a string. Recognize explicit session/credential failures;
    /// ordinary subscription errors remain broker values. Unknown strings are never guessed.
    private static func isAuthenticationText(_ text: String) -> Bool {
        let value = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "tokenexception" || value == "sessionexception"
            || value == "session expired" || value == "authentication failed"
            || value == "invalid `api_key` or `access_token`."
            || value == "invalid api_key or access_token"
            || value == "invalid access token" || value == "access token expired"
    }

    private func startRecovery() {
        recovery?.cancel()
        let id = UUID()
        recoveryID = id
        recovery = Task { [weak self] in await self?.recover(id: id) }
    }

    private func recover(id: UUID) async {
        var delay = reconnectPolicy.initialDelay
        for _ in 0 ..< reconnectPolicy.maximumAttempts {
            do { try await sleeper.sleep(for: delay) } catch { return }
            guard id == recoveryID, active, !authenticationBlocked, !Task.isCancelled else { return }
            let epoch = generation
            do {
                try await establish(epoch: epoch)
                guard id == recoveryID, epoch == generation else { return }
                recovery = nil
                emit(.reconnected)
                return
            } catch {
                guard id == recoveryID, epoch == generation, !Task.isCancelled else { return }
                await failed(error, epoch: epoch, schedule: false)
                guard id == recoveryID, active, !authenticationBlocked else { return }
            }
            delay = min(delay * 2, reconnectPolicy.maximumDelay)
        }
        guard id == recoveryID, active else { return }
        recovery = nil
        emit(.recoveryExhausted)
    }

    func receive(_ message: KiteWebSocketMessage, epoch: UUID) throws {
        guard epoch == generation else { return }
        if case let .text(text) = message {
            do {
                let event = try KiteTimestamp.decoder(timeZone: tradingTimeZone).decode(
                    KiteTextEvent.self, from: Data(text.utf8),
                )
                switch event {
                case let .order(order):
                    orderSubscribers.yield(order)
                case let .broker(event):
                    brokerSubscribers.yield(event)
                    if case let .serverError(text) = event, Self.isAuthenticationText(text) {
                        throw KiteTickerError.authenticationRequired
                    }
                }
            } catch KiteTickerError.authenticationRequired {
                throw KiteTickerError.authenticationRequired
            } catch { throw KiteTickerError.malformedText }
            return
        }
        guard case let .binary(data) = message else { return }
        let ticks = try Self.decode(data)
        for tick in ticks {
            marketSubscribers.yield(tick)
            let tick = KiteLTPTick(instrumentToken: tick.instrumentToken, lastPrice: tick.lastPrice)
            subscribers.yield(tick)
        }
    }

    private static func decode(_ data: Data) throws -> [KiteMarketTick] {
        let bytes = [UInt8](data)
        if bytes.count == 1 {
            return []
        } // documented binary heartbeat
        guard bytes.count >= 2 else { throw KiteTickerError.malformedPacket }
        func short(_ offset: Int) -> Int {
            Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
        }
        func word(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8
                | UInt32(bytes[offset + 3])
        }
        let count = short(0)
        var offset = 2
        var result: [KiteMarketTick] = []
        for _ in 0 ..< count {
            guard offset + 2 <= bytes.count else { throw KiteTickerError.malformedPacket }
            let length = short(offset)
            offset += 2
            guard offset + length <= bytes.count else { throw KiteTickerError.malformedPacket }
            // Packet length defines the layout, including packets in flight during mode changes.
            guard [8, 28, 32, 44, 184].contains(length) else {
                throw KiteTickerError.unsupportedPacketLength(length)
            }
            let token = word(offset)
            guard token > 0 else { throw KiteTickerError.malformedPacket }
            let raw = word(offset + 4)
            let segment = token & 0xFF
            let divisor = segment == 3 ? 10_000_000 : ([6, 12].contains(segment) ? 10000 : 100)
            func price(_ field: Int) -> Decimal {
                Decimal(word(offset + field)) / Decimal(divisor)
            }
            var details: KiteMarketTick.Details = .ltp
            if length == 44 || length == 184 {
                let quote = KiteQuoteFields(
                    lastTradedQuantity: word(offset + 8), averageTradedPrice: price(12),
                    volumeTraded: word(offset + 16), totalBuyQuantity: word(offset + 20),
                    totalSellQuantity: word(offset + 24),
                    ohlc: KiteOHLC(open: price(28), high: price(32), low: price(36), close: price(40)),
                )
                details = .quote(quote)
                if length == 184 {
                    let levels = stride(from: 64, to: 184, by: 12).map { field in
                        KiteDepthLevel(
                            price: price(field + 4), quantity: Int64(word(offset + field)),
                            orders: Int64(short(offset + field + 8)),
                        )
                    }
                    details = .full(
                        KiteFullFields(
                            quote: quote,
                            lastTradeTime: Date(timeIntervalSince1970: TimeInterval(word(offset + 44))),
                            openInterest: word(offset + 48), openInterestDayHigh: word(offset + 52),
                            openInterestDayLow: word(offset + 56),
                            exchangeTimestamp: Date(timeIntervalSince1970: TimeInterval(word(offset + 60))),
                            depth: KiteMarketDepth(buy: Array(levels.prefix(5)), sell: Array(levels.suffix(5))),
                        ),
                    )
                }
            }
            if length == 28 || length == 32 {
                let index = KiteIndexFields(
                    ohlc: KiteOHLC(open: price(16), high: price(8), low: price(12), close: price(20)),
                    priceChange: Decimal(Int32(bitPattern: word(offset + 24))) / Decimal(divisor),
                )
                details = .indexQuote(index)
                if length == 32 {
                    details = .indexFull(
                        index,
                        exchangeTimestamp: Date(timeIntervalSince1970: TimeInterval(word(offset + 28))),
                    )
                }
            }
            result.append(
                KiteMarketTick(
                    instrumentToken: token, lastPrice: Decimal(raw) / Decimal(divisor), details: details,
                ),
            )
            offset += length
        }
        guard offset == bytes.count else { throw KiteTickerError.malformedPacket }
        return result
    }
}
