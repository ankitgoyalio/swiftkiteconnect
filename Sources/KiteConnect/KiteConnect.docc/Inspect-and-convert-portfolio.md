# Inspect and convert a portfolio

Read equity holdings and position views, then submit an application-selected product conversion when appropriate.

## Read holdings and positions

```swift
import KiteConnect

func inspectEquityPortfolio(client: KiteClient) async throws -> KitePositions {
	let holdings = try await client.holdings()
	let auctions = try await client.auctionHoldings()
	_ = holdings.first?.identity
	_ = auctions.first?.auctionNumber
	return try await client.positions()
}
```

Use holdings for long-term equity inventory. Use `net` and `day` in ``KitePositions`` for their separate position views. Do not add those arrays together. See <doc:Financial-values-and-portfolio-views> for quantity and valuation semantics.

## Convert a position product

Choose the instrument, side, position view, and quantity from application-owned intent and the current account state.

```swift
func convertPortfolioProduct(client: KiteClient, instrument: KiteInstrumentIdentity)
	async throws -> Bool
{
	let conversion = KitePositionConversion(
		instrument: instrument, transactionType: .buy, positionType: .day,
		quantity: 1, oldProduct: .mis, newProduct: .cnc)
	return try await client.convertPosition(conversion)
}
```

The example constructs a request, not a promise that the account permits the conversion. Kite checks eligibility. A conversion changes the margin product and does not exit a position.

If a mutation loses its response after submission, reconcile the account state before another action. The SDK sends once and does not retry automatically. Cancellation remains recognizable, but does not prove that the server rejected the action.

## Submit an exit order

There is no dedicated exit endpoint. To exit a position, submit the opposite side for the same instrument and product after selecting the quantity in your application.

```swift
import Foundation

func exitPortfolioPosition(client: KiteClient, position: KitePosition, price: Decimal)
	async throws -> KiteOrderPlacementResult?
{
	guard let quantity = Int64(exactly: position.quantity.magnitude), quantity > 0 else {
		return nil
	}
	var order = KiteOrderPlacement(
		tradingSymbol: position.tradingSymbol, exchange: position.exchange,
		transactionType: position.quantity > 0 ? .sell : .buy,
		orderType: .limit, quantity: quantity, product: position.product)
	order.price = price
	return try await client.placeOrder(order)
}
```

For a holding sale, use SELL and the application-selected available quantity. A limit order can remain unfilled. MARKET is unavailable in sandbox, and no order type guarantees execution. Reconcile orders, trades, and portfolio state before reporting an exit. If Kite confirms HTTP 428, follow <doc:Authorise-holding-sales>.

## Reference

- ``KiteHolding``
- ``KiteHoldingMTF``
- ``KiteAuctionHolding``
- ``KitePosition``
- ``KitePositionConversion``
