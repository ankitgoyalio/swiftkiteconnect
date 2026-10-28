# Authorise holding sales

Prepare the browser workflow when Kite requires depository authorisation for a holding sale.

## Initiate authorisation

Supply explicit ISIN and quantity pairs, or call ``KiteClient/authoriseHoldings(instruments:)`` with an empty array to present all holdings.

```swift
import Foundation
import KiteConnect

func initiatePortfolioAuthorisation(client: KiteClient, isin: String, quantity: Int64)
	async throws -> KiteHoldingsAuthorisationFlow
{
	let receipt = try await client.authoriseHoldings(instruments: [
		KiteHoldingsAuthorisationItem(isin: isin, quantity: quantity)
	])
	return try client.holdingsAuthorisationFlow(requestID: receipt.requestID)
}

func inspectPortfolioRedirect(flow: KiteHoldingsAuthorisationFlow, redirect: URL)
	-> KiteHoldingsAuthorisationStatus?
{
	flow.completionStatus(for: redirect)
}
```

The receipt confirms initiation only. If the initiation outcome is uncertain, reconcile before resubmitting. Requests are never automatically retried.

## Present the browser flow

Present the flow's `url` with your application's browser. The depository owns PIN entry. The SDK supplies no browser UI or PIN handling.

Feed navigation URLs into ``KiteHoldingsAuthorisationFlow/completionStatus(for:)``. The matcher accepts only the exact HTTPS origin, API key, request identifier, and finish path, with one nonempty `status` query value. It rejects credentials, ports, and fragments. Unfamiliar status strings remain available as `unknown` values.

Treat browser success as a navigation hint. Confirm account authorisation state before submitting a subsequent sell order, and reconcile execution separately. Authorisation does not place an order or prove a fill.

The flow always uses the documented `kite.zerodha.com` browser origin, independently of the REST configuration. No sandbox browser equivalent is specified. This flow has not been exercised remotely.

## Reference

- ``KiteHoldingsAuthorisationItem``
- ``KiteHoldingsAuthorisationReceipt``
- ``KiteHoldingsAuthorisationFlow``
- ``KiteHoldingsAuthorisationStatus``
