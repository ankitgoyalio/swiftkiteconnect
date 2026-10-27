import Foundation

/// The persistent exchange/trading-symbol key. Numeric instrument tokens can be reused.
public struct KiteInstrumentIdentity: Sendable, Hashable, CustomStringConvertible {
  public let exchange: KiteExchange
  public let tradingSymbol: String
  public var description: String { exchange.rawValue + ":" + tradingSymbol }

  public init(exchange: KiteExchange, tradingSymbol: String) throws {
    for (field, value) in [("exchange", exchange.rawValue), ("tradingSymbol", tradingSymbol)] {
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !value.contains(":"),
        !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
      else {
        throw KiteError.validation(
          field: field, message: "Expected a nonempty identity component without colons or controls"
        )
      }
    }
    self.exchange = exchange
    self.tradingSymbol = tradingSymbol
  }
}
