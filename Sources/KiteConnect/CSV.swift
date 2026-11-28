import Foundation

struct CSVError: Error, CustomStringConvertible {
    let row: Int
    let reason: String

    var description: String { "CSV row \(row): \(reason)" }
}

/// Decodes UTF-8 CSV by header name. Each record must have the same width as the header.
enum CSV {
    struct Row {
        let number: Int
        fileprivate let columns: [String: Int]
        fileprivate let fields: [String]

        func field(_ column: String) throws -> String {
            guard let index = columns[column] else {
                throw CSVError(row: number, reason: "Missing column \(column).")
            }
            return fields[index]
        }

        func nonempty(_ column: String) throws -> String {
            let value = try field(column)
            guard !value.isEmpty else { throw invalidValue(in: column) }
            return value
        }

        func integer<Value: FixedWidthInteger>(_ column: String) throws -> Value {
            guard let value = Value(try field(column)) else {
                throw invalidValue(in: column)
            }
            return value
        }

        func decimal(_ column: String) throws -> Double {
            try parseDecimal(field(column), column: column)
        }

        func optionalDecimal(_ column: String) throws -> Double? {
            let text = try field(column)
            return text.isEmpty ? nil : try parseDecimal(text, column: column)
        }

        private func parseDecimal(_ text: String, column: String) throws -> Double {
            guard let value = Double(text), value.isFinite else {
                throw invalidValue(in: column)
            }
            return value
        }

        private func invalidValue(in column: String) -> CSVError {
            CSVError(row: number, reason: "Invalid value in column \(column).")
        }
    }

    static func decode<Value>(
        _ data: Data,
        requiredColumns: [String],
        transform: (Row) throws -> Value
    ) throws -> [Value] {
        var columns: [String: Int] = [:]
        var results: [Value] = []
        try readRecords(data) { number, fields in
            if number == 1 {
                for (index, field) in fields.enumerated() {
                    guard !field.isEmpty, columns[field] == nil else {
                        throw CSVError(row: number, reason: "Empty or duplicate column name.")
                    }
                    columns[field] = index
                }
                for column in requiredColumns where columns[column] == nil {
                    throw CSVError(row: number, reason: "Missing column \(column).")
                }
            } else {
                guard fields.count == columns.count else {
                    throw CSVError(row: number, reason: "Field count differs from the header.")
                }
                results.append(try transform(Row(number: number, columns: columns, fields: fields)))
            }
        }
        guard !columns.isEmpty else {
            throw CSVError(row: 1, reason: "Missing header.")
        }
        return results
    }

    private enum FieldState {
        case unquoted, quoted, afterQuote
    }

    private static func readRecords(_ data: Data, consume: (Int, [String]) throws -> Void) throws {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        let quote = UInt8(ascii: "\"")
        let comma = UInt8(ascii: ",")
        let cr = UInt8(ascii: "\r")
        let lf = UInt8(ascii: "\n")

        var state = FieldState.unquoted
        var field: [UInt8] = []
        var record: [String] = []
        var number = 1
        var skipLineFeed = false

        func finishField() throws {
            guard let text = String(bytes: field, encoding: .utf8) else {
                throw CSVError(row: number, reason: "Invalid UTF-8.")
            }
            record.append(text)
            field.removeAll(keepingCapacity: true)
            state = .unquoted
        }

        func finishRecord() throws {
            try finishField()
            try consume(number, record)
            record.removeAll(keepingCapacity: true)
            number += 1
        }

        for byte in data.dropFirst(data.starts(with: bom) ? bom.count : 0) {
            if skipLineFeed {
                skipLineFeed = false
                if byte == lf { continue }
            }
            switch (state, byte) {
            case (.quoted, quote):
                state = .afterQuote
            case (.quoted, _), (.afterQuote, quote):
                field.append(byte)
                state = .quoted
            case (_, comma):
                try finishField()
            case (_, cr), (_, lf):
                try finishRecord()
                skipLineFeed = byte == cr
            case (.unquoted, quote) where field.isEmpty:
                state = .quoted
            case (.unquoted, quote), (.afterQuote, _):
                throw CSVError(row: number, reason: "Unexpected character in a quoted field.")
            case (.unquoted, _):
                field.append(byte)
            }
        }

        guard state != .quoted else {
            throw CSVError(row: number, reason: "Unterminated quoted field.")
        }
        if !record.isEmpty || !field.isEmpty || state == .afterQuote {
            try finishRecord()
        }
    }
}
