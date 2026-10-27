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
