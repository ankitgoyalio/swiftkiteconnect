# Request historical candles

Fetch candles for a current instrument token with optional open interest.

Resolve the token through <doc:Discover-instruments> or an application-owned catalogue mapping. Supply an authenticated client and the `Date` bounds for your requested range.

```swift
import Foundation
import KiteConnect

func readHistoricalCandles(
	client: KiteClient, instrumentToken: UInt32, from: Date, to: Date
) async throws -> [KiteHistoricalCandle] {
	let candles = try await client.historicalCandles(
		instrumentToken: instrumentToken, interval: .minute,
		from: from, to: to, oi: true)
	for candle in candles {
		print(candle.timestamp, candle.close, candle.volume, candle.openInterest as Any)
	}
	return candles
}

func readContinuousFuturesDays(
	client: KiteClient, liveFuturesToken: UInt32, from: Date, to: Date
) async throws -> [KiteHistoricalCandle] {
	try await client.historicalCandles(
		instrumentToken: liveFuturesToken, interval: .day,
		from: from, to: to, continuous: true)
}
```

The first function prints each candle's instant, closing price, volume, and requested open interest. Empty results return an empty array and print nothing. The second function requests continuous daily futures history. Use a live NFO or MCX futures token for that documented capability. Kite decides contract eligibility. Continuous history does not discover expired options tokens.

Choose one of the eight ``KiteHistoricalInterval`` cases. Use a positive token and finite, ordered bounds. Equal bounds are allowed. The configured trading time zone must represent both bounds with Gregorian years from 1 through 9999. Requests format bounds to whole seconds in ``KiteConfiguration/tradingTimeZone``. The default is `Asia/Kolkata`.

Treat each ``KiteHistoricalCandle/timestamp`` as an instant. An explicit response offset overrides the configured zone. Offsetless response text uses the configured zone, never the device time zone.

Keep candle prices as `Decimal`. Volume and open interest are nonnegative `Int64` counts. The SDK accepts exactly six or seven positional fields per candle and rejects null, fractional, negative, or overflowing counts. It does not apply price-plausibility checks. When `oi: true`, every returned row must contain open interest. When `oi: false`, supplied open interest is still retained.

Split large date ranges in your application. The SDK does not split requests, retain expired tokens, or enforce changing server range limits. Sandbox historical access varies by account. The pinned sandbox guidance describes an approximate 1900-day limit per daily-candle request. An offline fixture check does not establish account eligibility or live historical access.

Handle ``KiteError/validation(field:message:)`` for invalid local arguments or missing access token. Malformed candles, timestamps, or missing requested OI fail the whole response with ``KiteError/decoding(statusCode:message:)``. API and transport errors propagate, as does cancellation. Requests attempt once without automatic retry.

## Topics

### Candle requests and results

- ``KiteClient/historicalCandles(instrumentToken:interval:from:to:continuous:oi:)``
- ``KiteHistoricalInterval``
- ``KiteHistoricalCandle``
