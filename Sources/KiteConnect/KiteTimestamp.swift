import Foundation

/// Shared timestamp policy for REST models, including future historical and order models.
/// Explicit offsets determine an instant; otherwise the configured trading zone applies.
enum KiteTimestamp {
  static func decoder(timeZone: TimeZone) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      guard let date = parse(value, timeZone: timeZone) else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "Invalid Kite timestamp: \(value)")
      }
      return date
    }
    return decoder
  }

  /// Accept second-resolution space/ISO timestamps, optional fractional seconds (1–9 digits),
  /// and Z or ±HH:mm / ±HHmm offsets. Never consult the machine's current timezone.
  static func parse(_ value: String, timeZone: TimeZone) -> Date? {
    let pattern =
      #"^([0-9]{4})-([0-9]{2})-([0-9]{2})[ T]([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]{1,9}))?(Z|[+-][0-9]{2}:?[0-9]{2})?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
      match.range.length == value.utf16.count
    else { return nil }
    func group(_ index: Int) -> String? {
      Range(match.range(at: index), in: value).map { String(value[$0]) }
    }
    guard let year = group(1).flatMap(Int.init), year > 0,
      let month = group(2).flatMap(Int.init),
      let day = group(3).flatMap(Int.init),
      let hour = group(4).flatMap(Int.init), (0...23).contains(hour),
      let minute = group(5).flatMap(Int.init), (0...59).contains(minute),
      let second = group(6).flatMap(Int.init), (0...59).contains(second)
    else { return nil }
    var zone = timeZone
    if let offset = group(8) {
      if offset == "Z" {
        zone = TimeZone(secondsFromGMT: 0)!
      } else {
        let digits = offset.dropFirst().replacingOccurrences(of: ":", with: "")
        guard let hours = Int(digits.prefix(2)), hours <= 23,
          let minutes = Int(digits.suffix(2)), minutes <= 59,
          let explicitZone = TimeZone(
            secondsFromGMT: (offset.first == "-" ? -1 : 1) * (hours * 3600 + minutes * 60))
        else { return nil }
        zone = explicitZone
      }
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let components = DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    guard let date = calendar.date(from: components) else { return nil }
    let roundTrip = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: date)
    guard roundTrip == components else { return nil }
    let fraction = group(7).flatMap { Double("0." + $0) } ?? 0
    return date.addingTimeInterval(fraction)
  }
}
