import Foundation

/// Documented request intervals. These are request options, not open server values.
public enum KiteHistoricalInterval: String, Sendable, CaseIterable {
  case minute, day
  case threeMinute = "3minute"
  case fiveMinute = "5minute"
  case tenMinute = "10minute"
  case fifteenMinute = "15minute"
  case thirtyMinute = "30minute"
  case sixtyMinute = "60minute"
}

/// A six- or seven-element candle decoded into named values. Prices use decimal arithmetic.
public struct KiteHistoricalCandle: Sendable, Equatable {
  public let timestamp: Date
  public let open: Decimal
  public let high: Decimal
  public let low: Decimal
  public let close: Decimal
  public let volume: Int64
  /// Absent when the server omits OI; required for every row when `oi: true`.
  public let openInterest: Int64?
}

extension KiteClient {
  /// Retrieve candles with bounds formatted to whole seconds in the configured trading time zone.
  /// Explicit response offsets determine instants; offsetless responses use that configured zone.
  /// A present OI must be an integer. Six-element rows are allowed only when `oi` is false.
  /// Continuous data is documented for day candles of NFO/MCX futures using a live token.
  /// Applications own instrument persistence and expired-contract token mappings.
  public func historicalCandles(
    instrumentToken: UInt32, interval: KiteHistoricalInterval, from: Date, to: Date,
    continuous: Bool = false, oi: Bool = false
  ) async throws -> [KiteHistoricalCandle] {
    guard instrumentToken > 0 else {
      throw KiteError.validation(field: "instrumentToken", message: "Expected a positive token")
    }
    guard from.timeIntervalSince1970.isFinite, to.timeIntervalSince1970.isFinite, from <= to else {
      throw KiteError.validation(field: "from/to", message: "Expected finite, ordered bounds")
    }
    guard !continuous || interval == .day else {
      throw KiteError.validation(
        field: "continuous", message: "Continuous data requires day candles")
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = configuration.tradingTimeZone
    for bound in [from, to] {
      let parts = calendar.dateComponents([.era, .year], from: bound)
      guard parts.era == 1, let year = parts.year, (1...9999).contains(year) else {
        throw KiteError.validation(field: "from/to", message: "Expected four-digit Gregorian years")
      }
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = configuration.tradingTimeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let response = try await response(
      for: KiteRequest(
        path: "/instruments/historical/\(instrumentToken)/\(interval.rawValue)",
        query: [
          KiteParameter("from", formatter.string(from: from)),
          KiteParameter("to", formatter.string(from: to)),
          KiteParameter("continuous", continuous ? "1" : "0"),
          KiteParameter("oi", oi ? "1" : "0"),
        ]))
    do {
      let result = try JSONDecoder().decode(HistoricalEnvelope.self, from: response.body)
      guard result.status == "success" else { throw HistoricalFailure("Expected success envelope") }
      return try result.data.candles.map { row in
        if oi && row.openInterest == nil {
          throw HistoricalFailure("Missing requested open interest")
        }
        guard
          let timestamp = KiteTimestamp.parse(
            row.timestamp, timeZone: configuration.tradingTimeZone)
        else { throw HistoricalFailure("Invalid candle timestamp") }
        return KiteHistoricalCandle(
          timestamp: timestamp, open: row.open, high: row.high,
          low: row.low, close: row.close, volume: row.volume, openInterest: row.openInterest)
      }
    } catch {
      throw KiteError.decoding(
        statusCode: response.statusCode, message: "Malformed historical candles: \(error)")
    }
  }
}

private struct HistoricalFailure: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}
private struct HistoricalEnvelope: Decodable {
  let status: String
  let data: HistoricalData
}
private struct HistoricalData: Decodable { let candles: [HistoricalRow] }
private struct HistoricalRow: Decodable {
  let timestamp: String
  let open: Decimal
  let high: Decimal
  let low: Decimal
  let close: Decimal
  let volume: Int64
  let openInterest: Int64?
  init(from decoder: any Decoder) throws {
    var row = try decoder.unkeyedContainer()
    timestamp = try row.decode(String.self)
    open = try row.decode(Decimal.self)
    high = try row.decode(Decimal.self)
    low = try row.decode(Decimal.self)
    close = try row.decode(Decimal.self)
    volume = try row.decode(Int64.self)
    openInterest = row.isAtEnd ? nil : try row.decode(Int64.self)
    guard row.isAtEnd, volume >= 0, openInterest.map({ $0 >= 0 }) ?? true else {
      throw HistoricalFailure("Expected six or seven candle fields with nonnegative volume and OI")
    }
  }
}
