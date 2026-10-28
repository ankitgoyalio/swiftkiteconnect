# Read mutual-fund information

Retrieve mutual-fund orders, plans, holdings, and the scheme catalogue through the five supported read APIs.

## Retrieve orders and plans

```swift
import KiteConnect

func inspectFundActivity(client: KiteClient, orderID: String)
	async throws -> [KiteMutualFundSIP]
{
	_ = try await client.mutualFundOrders()
	_ = try await client.mutualFundOrder(orderID: orderID)
	return try await client.mutualFundSIPs()
}
```

Use the order list for the last seven days. Use individual order lookup for a known identifier regardless of its age. Pass a single nonempty order identifier without whitespace, control characters, path separators, query delimiters, or `..`.

Read active and paused SIPs with ``KiteClient/mutualFundSIPs()``. Retain the documented `-1` indefinite-plan sentinels in instalment counts. Preserve optional step-up data and unfamiliar statuses. The decoder accepts the documented SIP success envelope without a `status` field.

## Retrieve allotted units and scheme limits

```swift
func inspectFundInventory(client: KiteClient) async throws -> [KiteMutualFundInstrument] {
	let holdings = try await client.mutualFundHoldings()
	_ = holdings.first?.quantity
	return try await client.mutualFundInstruments()
}
```

Use holdings for allotted units in the user's demat account. Use the catalogue for purchase and redemption flags, amount limits, quantity increments, plan classification, and dated NAV values. See <doc:Financial-values-and-portfolio-views> for decimal and date semantics.

The catalogue is authenticated CSV and follows the configured API route, including sandbox `/oms`. Custom transports must supply decompressed bytes. URLSession handles gzip content encoding.

The selected snapshot exposes these five read routes. It disallows mutual-fund order placement because bank payment is required, supplies no SIP mutation or individual-SIP route, and excludes dividend reinvestment schemes. Catalogue permission flags do not add SDK mutation capabilities. Fixture checks do not establish live mutual-fund qualification.

Each request attempts once. Handle validation errors for malformed identifiers and the usual authentication, API, transport, cancellation, and decoding failures.

## Reference

- ``KiteMutualFundOrder``
- ``KiteMutualFundSIP``
- ``KiteMutualFundHolding``
- ``KiteMutualFundInstrument``
- ``KiteMutualFundVariety``
- ``KiteMutualFundFrequency``
- ``KiteMutualFundSIPStatus``
- ``KiteMutualFundDividendType``
- ``KiteMutualFundPurchaseType``
- ``KiteMutualFundSchemeType``
- ``KiteMutualFundPlan``

## Read all supported fund views

Supply a known order ID to read its details alongside the recent list, plans, holdings, and catalogue.

```swift
func mutualFundReads(client: KiteClient, orderID: String) async throws {
	_ = try await client.mutualFundOrders()
	_ = try await client.mutualFundOrder(orderID: orderID)
	_ = try await client.mutualFundSIPs()
	_ = try await client.mutualFundHoldings()
	_ = try await client.mutualFundInstruments()
}
```
