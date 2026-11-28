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
        guard packet.count == 8 else { return nil }
        let token = UInt32(bigEndian: packet.loadUnaligned(as: UInt32.self))
        let rawPrice = UInt32(bigEndian: packet.loadUnaligned(fromByteOffset: 4, as: UInt32.self))
        let divisor: Double
        switch token & 0xFF {
        case 3: divisor = 10_000_000 // CDS
        case 6, 12: divisor = 10_000 // BCD and NCO
        default: divisor = 100
        }
        return KiteTicker.Tick(instrumentToken: token, lastPrice: Double(rawPrice) / divisor)
    }
}
