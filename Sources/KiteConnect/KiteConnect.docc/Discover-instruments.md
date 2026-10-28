# Discover instruments

Find an instrument's current token in the daily catalogue and keep its exchange and trading symbol as the persistent key.

Call ``KiteClient/instruments(exchange:)`` to download all instruments or restrict the download to one exchange. Supply your application's configured client.

```swift
import KiteConnect

func discoverINFY(client: KiteClient) async throws -> KiteInstrument? {
	let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
	let catalogue = try await client.instruments(exchange: .nse)
	let instrument = catalogue.first { $0.identity == identity }
	if let instrument {
		print(instrument.identity.description, instrument.instrumentToken)
	}
	return instrument
}
```

When the catalogue contains INFY, the function prints `NSE:INFY` and its current numeric token. If the instrument is absent, the function returns `nil`.

Store ``KiteInstrument/identity`` in watchlists. Use ``KiteInstrument/instrumentToken`` for subscriptions and historical requests. Do not use ``KiteInstrument/exchangeToken`` in its place. Kite can reuse numeric instrument tokens after derivative expiry, so retain dated catalogue mappings when your application needs expired contracts.

Refresh and cache the catalogue in your application. The pinned upstream guidance suggests a daily refresh around 08:30. The SDK does not schedule downloads or persist instruments. ``KiteInstrument/lastPrice`` is the price recorded in the daily dump. Use <doc:Request-quote-snapshots> for current snapshots.

Read expiry through ``KiteInstrument/expiry`` as a ``KiteDateOnly``, without assigning a time or time zone. Prices, strikes, and tick sizes use `Decimal`. Empty name, expiry, and strike fields become `nil`. Unfamiliar instrument types retain their original strings through ``KiteInstrumentType/unknown(_:)``.

Handle ``KiteError/validation(field:message:)`` for an invalid exchange filter and ``KiteError/decoding(statusCode:message:)`` for malformed CSV. API errors, transport failures, and cancellation propagate without automatic retry. Downloads use credentials when present and bypass the configured route prefix, including the sandbox's `/oms` prefix. Custom transports must return HTTP-decoded bytes.

## Topics

### Catalogue requests and entries

- ``KiteClient/instruments(exchange:)``
- ``KiteInstrument``
- ``KiteInstrumentType``

### Instrument identity and expiry

- ``KiteInstrumentIdentity``
- ``KiteDateOnly``
- ``KiteExchange``

## Combine catalogue and snapshot reads

Supply application-owned inputs and a configured client. These functions compile against the public SDK; routine verification does not call remote services.

```swift
func marketReads(client: KiteClient, from: Date, to: Date) async throws {
	let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
	let instruments = try await client.instruments()
	_ = try await client.instruments(exchange: .nse)
	let quotes = try await client.quotes(instruments: [identity])
	_ = try await client.ohlc(instruments: [identity])
	_ = try await client.ltp(instruments: [identity])
	if let token = instruments.first(where: { $0.identity == identity })?.instrumentToken {
		_ = try await client.historicalCandles(
			instrumentToken: token, interval: .minute, from: from, to: to, oi: true)
	}
	print(quotes.count)
}
```
