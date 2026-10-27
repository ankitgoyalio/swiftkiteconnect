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
  let required = [
    "instrument_token", "exchange_token", "tradingsymbol", "name", "last_price", "expiry", "strike",
    "tick_size", "lot_size", "instrument_type", "segment", "exchange",
  ]
  let table = try KiteCSV.Table(data, required: required)
  return try table.rows.enumerated().map { offset, values in
    let row = try table.row(values, record: offset + 2)
    let identity: KiteInstrumentIdentity
    do {
      identity = try KiteInstrumentIdentity(
        exchange: KiteExchange(rawValue: row.nonempty("exchange")),
        tradingSymbol: row.nonempty("tradingsymbol"))
    } catch { throw row.failure("exchange/tradingsymbol") }
    let expiry: KiteDateOnly?
    do { expiry = try row.value("expiry").nilIfEmpty.map { try KiteDateOnly($0) } } catch {
      throw row.failure("expiry")
    }
    return try KiteInstrument(
      instrumentToken: row.integer("instrument_token", UInt32.init),
      exchangeToken: row.integer("exchange_token", UInt32.init),
      identity: identity, name: row.value("name").nilIfEmpty,
      lastPrice: row.decimal("last_price"), expiry: expiry,
      strike: row.value("strike").isEmpty ? nil : row.decimal("strike"),
      tickSize: row.decimal("tick_size"), lotSize: row.integer("lot_size", Int64.init),
      instrumentType: KiteInstrumentType(rawValue: row.nonempty("instrument_type")),
      segment: row.nonempty("segment"))
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
