import Foundation

/// A Gregorian calendar date, with no time or time zone. Intended for contract expiries.
public struct KiteDateOnly: Sendable, Hashable, CustomStringConvertible {
  public let year: Int
  public let month: Int
  public let day: Int
  public let description: String

  /// Parse exactly YYYY-MM-DD, validating Gregorian month lengths and leap years.
  public init(_ value: String) throws {
    let bytes = Array(value.utf8)
    guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
      bytes.enumerated().allSatisfy({
        $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element)
      }),
      let year = Int(value.prefix(4)), year > 0,
      let month = Int(value.dropFirst(5).prefix(2)), (1...12).contains(month),
      let day = Int(value.suffix(2))
    else { throw KiteError.validation(field: "date", message: "Expected Gregorian YYYY-MM-DD") }
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    let lengths = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    guard (1...lengths[month - 1]).contains(day) else {
      throw KiteError.validation(field: "date", message: "Invalid Gregorian calendar day")
    }
    self.year = year
    self.month = month
    self.day = day
    self.description = value
  }
}
