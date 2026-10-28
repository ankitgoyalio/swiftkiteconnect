# Request quote snapshots

Request full quotes, trading-day OHLC summaries, or last-traded prices by exchange and trading symbol.

Construct ``KiteInstrumentIdentity`` values directly. Quote requests do not require a catalogue lookup. Use an authenticated client and choose the response that contains the fields your application needs.

```swift
import KiteConnect

func readINFYSnapshots(client: KiteClient) async throws {
	let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
	let full = try await client.quotes(instruments: [identity])
	if let quote = full[identity] {
		print(quote.lastPrice, quote.timestamp, quote.depth.buy.count)
	} else {
		print("Full quote unavailable for", identity.description)
	}
	let summaries = try await client.ohlc(instruments: [identity])
	if let summary = summaries[identity] {
		print(summary.lastPrice, summary.ohlc.close)
	}
	let prices = try await client.ltp(instruments: [identity])
	if let price = prices[identity] {
		print(price.instrumentToken, price.lastPrice)
	}
}
```

A successful full quote prints its last price, timestamp, and number of buy-side depth levels. A missing response key prints the unavailable message. Missing keys mean unavailable data. Keep that state separate from a price of zero.

Limit each ``KiteClient/quotes(instruments:)`` request to 1 through 500 identities. ``KiteClient/ohlc(instruments:)`` and ``KiteClient/ltp(instruments:)`` accept 1 through 1000. Split larger lists in your application. Repeated identities count toward these limits. The SDK preserves input query order and duplicates without batching or deduplication.

Use ``KiteOHLC/close`` as the previous trading day's closing price. It is different from a historical candle's close for its own interval. Keep prices as `Decimal` when calculating financial values.

Read depth arrays without assuming five entries. Either side can be empty or have a variable length. Keep ``KiteQuoteSnapshot/openInterest`` separate from ``KiteQuoteSnapshot/oi``. The optional `open_interest` attribute does not substitute for required `oi`.

Interpret quote and last-trade timestamps as `Date` instants. Explicit offsets determine the instant. Offsetless text uses ``KiteConfiguration/tradingTimeZone``, defaulting to `Asia/Kolkata`, rather than the device time zone. This default is SDK policy. A missing or null last-trade timestamp becomes `nil`.

Handle ``KiteError/validation(field:message:)`` for an invalid identity count or missing access token. Malformed required data fails the whole response with ``KiteError/decoding(statusCode:message:)``. API and transport errors propagate, as does cancellation. Requests attempt once without automatic retry.

## Topics

### Snapshot requests

- ``KiteClient/quotes(instruments:)``
- ``KiteClient/ohlc(instruments:)``
- ``KiteClient/ltp(instruments:)``

### Prices and trading-day summaries

- ``KiteQuoteSnapshot``
- ``KiteOHLCSnapshot``
- ``KiteLTPSnapshot``
- ``KiteOHLC``

### Order-book depth

- ``KiteMarketDepth``
- ``KiteDepthLevel``
