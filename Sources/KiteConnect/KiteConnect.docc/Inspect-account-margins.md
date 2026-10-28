# Inspect account funds and estimate margins

Read account funds or calculate hypothetical order costs without submitting a trade.

## Read account funds

Call ``KiteClient/margins()`` for both account segments, or ``KiteClient/margins(segment:)`` for one segment. Inspect `enabled` before treating a segment as available for trading.

```swift
import Foundation
import KiteConnect

func equityFunds(client: KiteClient) async throws -> Decimal? {
	let funds = try await client.margins(segment: .equity)
	return funds.enabled ? funds.net : nil
}
```

The result contains Kite's net balance, available components, and utilised components. Read <doc:Financial-values-and-portfolio-views> before combining amounts.

## Estimate hypothetical orders

Construct ``KiteMarginOrder`` values with positive quantities and nonnegative finite prices. Call the full or compact calculation method for the detail your application needs.

```swift
func estimatePortfolioCosts(client: KiteClient, instrument: KiteInstrumentIdentity)
	async throws -> KiteCalculatedBasketMargins
{
	let order = KiteMarginOrder(
		instrument: instrument, transactionType: .buy, product: .cnc,
		orderType: .limit, quantity: 1, price: Decimal(string: "125.50")!)
	let full = try await client.orderMargins([order])
	let compact = try await client.compactOrderMargins([order])
	_ = full.first?.charges
	_ = compact.first?.total
	_ = try await client.compactBasketMargins([order], considerPositions: false)
	return try await client.basketMargins([order], considerPositions: true)
}

func estimateContractNote(client: KiteClient, instrument: KiteInstrumentIdentity)
	async throws -> [KiteCalculatedOrderCharges]
{
	let input = KiteChargeOrder(
		orderID: "hypothetical-1", instrument: instrument, transactionType: .buy,
		product: .cnc, orderType: .limit, quantity: 1,
		averagePrice: Decimal(string: "125.50")!)
	return try await client.orderCharges([input])
}
```

Use `considerPositions` to choose whether existing positions enter a basket estimate. Read per-order charges when a basket mixes securities and commodities transaction taxes. Aggregate charges may omit those taxes.

Calculations do not place orders. The SDK checks request structure, while Kite decides current margin requirements and business eligibility. These APIs are excluded from remote sandbox qualification. Each request attempts once. Handle validation, API rejection, transport, cancellation, and decoding errors through the normal client error path.

## Reference

- ``KiteAccountMargins``
- ``KiteSegmentMargins``
- ``KiteCalculatedMargin``
- ``KiteCompactMargin``
- ``KiteCalculatedBasketMargins``
- ``KiteCompactBasketMargins``
- ``KiteCalculationCharges``
