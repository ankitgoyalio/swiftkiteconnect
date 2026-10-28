import Foundation

/// Shared CSV grammar for catalogue endpoints; transport bodies must already be decompressed.
/// Strict quoting avoids silently shifting financial fields into the wrong columns.
struct KiteCSV {
  static func records(_ data: Data) throws -> [[String]] {
    guard String(data: data, encoding: .utf8) != nil else { throw Failure("Invalid UTF-8") }
    var bytes = Array(data)
    if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
    var rows: [[String]] = []
    var row: [String] = []
    var field: [UInt8] = []
    enum State { case start, unquoted, quoted, closed }
    var state = State.start
    var index = 0
    func finishField() {
      row.append(String(decoding: field, as: UTF8.self))
      field.removeAll(keepingCapacity: true)
      state = .start
    }
    func finishRow() {
      finishField()
      if row != [""] { rows.append(row) }
      row.removeAll(keepingCapacity: true)
    }
    while index < bytes.count {
      if index % 4096 == 0 { try Task.checkCancellation() }
      let byte = bytes[index]
      if state == .quoted {
        if byte == 34 {
          if index + 1 < bytes.count, bytes[index + 1] == 34 {
            field.append(34)
            index += 1
          } else {
            state = .closed
          }
        } else {
          field.append(byte)
        }
      } else if byte == 44 {
        finishField()
      } else if byte == 10 || byte == 13 {
        finishRow()
        if byte == 13, index + 1 < bytes.count, bytes[index + 1] == 10 { index += 1 }
      } else if byte == 34, state == .start {
        state = .quoted
      } else {
        guard state != .closed, byte != 34 else {
          throw Failure("Unexpected character in CSV record \(rows.count + 1)")
        }
        state = .unquoted
        field.append(byte)
      }
      index += 1
    }
    guard state != .quoted else { throw Failure("Unterminated quoted CSV field") }
    if !field.isEmpty || !row.isEmpty || state != .start { finishRow() }
    return rows
  }

  struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }
}

extension KiteCSV {
  /// Shared catalogue semantics; endpoint-specific models remain in their readers.
  struct Table {
    let rows: [[String]]
    private let indices: [String: Int]

    init(_ data: Data, required: [String]) throws {
      let records = try KiteCSV.records(data)
      guard let rawHeader = records.first else { throw Failure("Missing CSV header") }
      let header = rawHeader.map { $0.trimmingCharacters(in: .whitespaces) }
      guard Set(header).count == header.count, !header.contains("") else {
        throw Failure("Duplicate or empty CSV column")
      }
      for key in required where !header.contains(key) { throw Failure("Missing column \(key)") }
      indices = Dictionary(
        uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })
      rows = Array(records.dropFirst())
    }

    func row(_ values: [String], record: Int) throws -> Row {
      try Task.checkCancellation()
      guard values.count == indices.count else {
        throw Failure("Wrong field count in CSV record \(record)")
      }
      return Row(values: values, indices: indices, record: record)
    }
  }

  struct Row {
    let values: [String]
    let indices: [String: Int]
    let record: Int

    func value(_ key: String) -> String { values[indices[key]!] }
    func failure(_ key: String) -> Failure { Failure("Invalid \(key) in CSV record \(record)") }

    func nonempty(_ key: String) throws -> String {
      let raw = value(key)
      guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw failure(key) }
      return raw
    }

    func integer<T>(_ key: String, _ parse: (String) -> T?) throws -> T {
      let raw = value(key)
      guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }), let result = parse(raw)
      else { throw failure(key) }
      return result
    }

    func boolean(_ key: String) throws -> Bool {
      guard ["0", "1"].contains(value(key)) else { throw failure(key) }
      return value(key) == "1"
    }

    func decimal(_ key: String) throws -> Decimal {
      let raw = value(key)
      let mantissa = raw.split(whereSeparator: { $0 == "e" || $0 == "E" }).first ?? ""
      let significant = mantissa.utf8.filter { (48...57).contains($0) }
        .drop(while: { $0 == 48 }).reversed().drop(while: { $0 == 48 })
      // Decimal guarantees 38 significant decimal digits. Reject rather than silently round.
      guard significant.count <= 38,
        raw.range(
          of: #"^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression)
          != nil,
        let result = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), !result.isNaN
      else { throw failure(key) }
      return result
    }
  }
}
