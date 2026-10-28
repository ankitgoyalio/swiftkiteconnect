//
//  KiteDateOnly.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// A Gregorian calendar date, with no time or time zone. Intended for contract expiries.
public struct KiteDateOnly: Sendable, Hashable, CustomStringConvertible {
    /// The Gregorian year in the range 1 through 9999, without a time zone.
    public let year: Int
    /// The Gregorian month number, from 1 for January through 12 for December.
    public let month: Int
    /// The day of the month, validated against Gregorian month lengths and leap years.
    public let day: Int
    /// The original validated date text in the exact `YYYY-MM-DD` format.
    public let description: String

    /// Parses a Gregorian date without assigning a time or time zone.
    ///
    /// - Parameter value: Exactly ten ASCII characters in `YYYY-MM-DD` format, with a year from 0001 through 9999.
    /// - Throws: ``KiteError/validation(field:message:)`` for an invalid format or calendar day.
    public init(_ value: String) throws {
        let bytes = Array(value.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({
                  $0.offset == 4 || $0.offset == 7 || (48 ... 57).contains($0.element)
              }),
              let year = Int(value.prefix(4)), year > 0,
              let month = Int(value.dropFirst(5).prefix(2)), (1 ... 12).contains(month),
              let day = Int(value.suffix(2))
        else { throw KiteError.validation(field: "date", message: "Expected Gregorian YYYY-MM-DD") }
        let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let lengths = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard (1 ... lengths[month - 1]).contains(day) else {
            throw KiteError.validation(field: "date", message: "Invalid Gregorian calendar day")
        }
        self.year = year
        self.month = month
        self.day = day
        description = value
    }
}
