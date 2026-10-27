import Foundation

/// A catalogue entry. Tokens can be reused after expiry and are not persistent identities.
public struct KiteInstrument: Sendable, Equatable {
  public let instrumentToken: UInt32
  public let exchangeToken: UInt32
  public var tradingSymbol: String { identity.tradingSymbol }
  public let identity: KiteInstrumentIdentity
  public let name: String?
  public let lastPrice: Decimal
  public let expiry: KiteDateOnly?
  public let strike: Decimal?
  public let tickSize: Decimal
  public let lotSize: Int64
  /// Known instrument types preserve unfamiliar server values through `.unknown`.
  public let instrumentType: KiteInstrumentType
  public let segment: String
  public var exchange: KiteExchange { identity.exchange }
}

extension KiteClient {
  /// Download the daily catalogue, optionally filtered by exchange.
  /// Persistence and refresh schedules belong to the application; lastPrice is not real time.
  /// Uses session credentials when present. Instrument dumps bypass the configured route prefix.
  /// Injected transports must return HTTP-decoded bytes (URLSession handles Content-Encoding gzip).
  public func instruments(exchange: KiteExchange? = nil) async throws -> [KiteInstrument] {
    if let exchange = exchange?.rawValue {
      guard !exchange.isEmpty,
        exchange.utf8.allSatisfy({
          (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45
            || $0 == 95
        })
      else {
        throw KiteError.validation(
          field: "exchange", message: "Expected a single exchange identifier")
      }
    }
    let response = try await response(
      for: KiteRequest(
        path: "/instruments" + (exchange.map { "/" + $0.rawValue } ?? ""),
        authenticated: accessToken != nil,
        isInstrumentDump: true))
    do { return try parseInstruments(response.body) } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw KiteError.decoding(statusCode: response.statusCode, message: String(describing: error))
    }
  }
}

private func parseInstruments(_ data: Data) throws -> [KiteInstrument] {
  let rows = try KiteCSV.records(data)
  guard let rawHeader = rows.first else { throw KiteCSV.Failure("Missing CSV header") }
  let header = rawHeader.map { $0.trimmingCharacters(in: .whitespaces) }
  guard Set(header).count == header.count, !header.contains("") else {
    throw KiteCSV.Failure("Duplicate or empty CSV column")
  }
  let required = [
    "instrument_token", "exchange_token", "tradingsymbol", "name", "last_price", "expiry", "strike",
    "tick_size", "lot_size", "instrument_type", "segment", "exchange",
  ]
  for key in required where !header.contains(key) { throw KiteCSV.Failure("Missing column \(key)") }
  let indices = Dictionary(
    uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })
  return try rows.dropFirst().enumerated().map { offset, row in
    try Task.checkCancellation()
    let record = offset + 2
    guard row.count == header.count else {
      throw KiteCSV.Failure("Wrong field count in CSV record \(record)")
    }
    func value(_ key: String) -> String { row[indices[key]!] }
    func failure(_ key: String) -> KiteCSV.Failure {
      KiteCSV.Failure("Invalid \(key) in CSV record \(record)")
    }
    func nonempty(_ key: String) throws -> String {
      let result = value(key)
      guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw failure(key)
      }
      return result
    }
    func integer<T>(_ key: String, _ parse: (String) -> T?) throws -> T {
      let raw = value(key)
      guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }), let result = parse(raw)
      else { throw failure(key) }
      return result
    }
    func decimal(_ key: String) throws -> Decimal {
      let raw = value(key)
      let mantissa = raw.split(whereSeparator: { $0 == "e" || $0 == "E" }).first ?? ""
      let digits = mantissa.utf8.filter { (48...57).contains($0) }
      let significant = digits.drop(while: { $0 == 48 }).reversed().drop(while: { $0 == 48 })
      // Decimal guarantees 38 significant decimal digits. Reject rather than silently round.
      guard significant.count <= 38,
        raw.range(
          of: #"^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression)
          != nil,
        let result = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), !result.isNaN
      else { throw failure(key) }
      return result
    }
    let identity: KiteInstrumentIdentity
    do {
      identity = try KiteInstrumentIdentity(
        exchange: KiteExchange(rawValue: nonempty("exchange")),
        tradingSymbol: nonempty("tradingsymbol"))
    } catch { throw failure("exchange/tradingsymbol") }
    let expiry: KiteDateOnly?
    do { expiry = try value("expiry").nilIfEmpty.map { try KiteDateOnly($0) } } catch {
      throw failure("expiry")
    }
    return try KiteInstrument(
      instrumentToken: integer("instrument_token", UInt32.init),
      exchangeToken: integer("exchange_token", UInt32.init),
      identity: identity, name: value("name").nilIfEmpty,
      lastPrice: decimal("last_price"), expiry: expiry,
      strike: value("strike").isEmpty ? nil : decimal("strike"),
      tickSize: decimal("tick_size"), lotSize: integer("lot_size", Int64.init),
      instrumentType: KiteInstrumentType(rawValue: nonempty("instrument_type")),
      segment: nonempty("segment"))
  }
}
extension String { fileprivate var nilIfEmpty: String? { isEmpty ? nil : self } }

/// Documented catalogue types, retaining future server additions.
public enum KiteInstrumentType: KiteStringValue {
  case equity, future, call, put
  case unknown(String)
  public init(rawValue: String) {
    switch rawValue {
    case "EQ": self = .equity
    case "FUT": self = .future
    case "CE": self = .call
    case "PE": self = .put
    default: self = .unknown(rawValue)
    }
  }
  public var rawValue: String {
    switch self {
    case .equity: "EQ"
    case .future: "FUT"
    case .call: "CE"
    case .put: "PE"
    case .unknown(let value): value
    }
  }
}
