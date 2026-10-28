//
//  KiteInstrumentIdentity.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// The persistent exchange and trading-symbol key for an instrument.
///
/// Use this key for watchlists and quote requests. Numeric instrument tokens can be reused
/// after derivative expiry. Identity construction does not verify that Kite lists the instrument.
public struct KiteInstrumentIdentity: Sendable, Hashable, CustomStringConvertible {
    /// The exchange within which the trading symbol identifies the instrument.
    public let exchange: KiteExchange
    /// The exchange-local trading symbol, preserving the supplied spelling and spaces.
    public let tradingSymbol: String
    /// The `EXCHANGE:TRADINGSYMBOL` identity used in quote request parameters and response keys.
    public var description: String {
        exchange.rawValue + ":" + tradingSymbol
    }

    /// Creates an identity without consulting the instrument catalogue.
    ///
    /// Components retain their original text. Internal spaces, such as in `NIFTY 50`, are allowed.
    ///
    /// - Parameters:
    ///   - exchange: The exchange, including an unfamiliar raw value.
    ///   - tradingSymbol: A symbol within that exchange.
    /// - Throws: ``KiteError/validation(field:message:)`` if either component is empty after trimming
    ///   whitespace, contains a colon, or contains a control character.
    public init(exchange: KiteExchange, tradingSymbol: String) throws {
        for (field, value) in [("exchange", exchange.rawValue), ("tradingSymbol", tradingSymbol)] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !value.contains(":"),
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            else {
                throw KiteError.validation(
                    field: field, message: "Expected a nonempty identity component without colons or controls",
                )
            }
        }
        self.exchange = exchange
        self.tradingSymbol = tradingSymbol
    }
}
