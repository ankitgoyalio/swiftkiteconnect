import Foundation

enum TickerPackets {
    static func decode(_ data: Data) -> [KiteTicker.Tick] {
        // A one-byte message is a heartbeat.
        guard data.count >= 2 else { return [] }
        return data.withUnsafeBytes { bytes in
            let count = Int(UInt16(bigEndian: bytes.loadUnaligned(as: UInt16.self)))
            var offset = 2
            var ticks: [KiteTicker.Tick] = []
            for _ in 0..<count {
                guard bytes.count - offset >= 2 else { break }
                let length = Int(UInt16(bigEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self)))
                offset += 2
                guard bytes.count - offset >= length else { break }
                let packet = UnsafeRawBufferPointer(rebasing: bytes[offset..<(offset + length)])
                if let tick = decodePacket(packet) {
                    ticks.append(tick)
                }
                offset += length
            }
            return ticks
        }
    }

    private static func decodePacket(_ packet: UnsafeRawBufferPointer) -> KiteTicker.Tick? {
        guard packet.count >= 8 else { return nil }
        func uint32(_ offset: Int) -> UInt32 {
            UInt32(bigEndian: packet.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }

        let token = uint32(0)
        let divisor: Double
        switch token & 0xFF {
        case 3: divisor = 10_000_000 // CDS
        case 6, 12: divisor = 10_000 // BCD and NCO
        default: divisor = 100
        }

        func price(_ offset: Int) -> Double {
            Double(uint32(offset)) / divisor
        }

        func timestamp(_ offset: Int) -> Date {
            Date(timeIntervalSince1970: TimeInterval(uint32(offset)))
        }

        var tick = KiteTicker.Tick(instrumentToken: token, lastPrice: price(4))
        switch (tick.isIndex, packet.count) {
        case (_, 8):
            return tick
        case (true, 28), (true, 32):
            tick.high = price(8)
            tick.low = price(12)
            tick.open = price(16)
            tick.close = price(20)
            tick.mode = .quote
            if packet.count == 32 {
                tick.mode = .full
                tick.exchangeTime = timestamp(28)
            }
        case (false, 44), (false, 184):
            tick.lastQuantity = uint32(8)
            tick.averagePrice = price(12)
            tick.volume = uint32(16)
            tick.buyQuantity = uint32(20)
            tick.sellQuantity = uint32(24)
            tick.open = price(28)
            tick.high = price(32)
            tick.low = price(36)
            tick.close = price(40)
            tick.mode = .quote
            if packet.count == 184 {
                tick.mode = .full
                tick.lastTradeTime = timestamp(44)
                tick.openInterest = uint32(48)
                tick.openInterestDayHigh = uint32(52)
                tick.openInterestDayLow = uint32(56)
                tick.exchangeTime = timestamp(60)
                func level(_ index: Int) -> KiteTicker.DepthEntry {
                    let offset = 64 + index * 12
                    let orders = UInt16(bigEndian: packet.loadUnaligned(fromByteOffset: offset + 8, as: UInt16.self))
                    return KiteTicker.DepthEntry(quantity: uint32(offset), price: price(offset + 4), orders: orders)
                }
                tick.depth = KiteTicker.MarketDepth(buy: (0..<5).map(level), sell: (5..<10).map(level))
            }
        default:
            return nil
        }
        return tick
    }
}
