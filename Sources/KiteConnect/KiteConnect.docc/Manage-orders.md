# Manage orders

Submit, inspect, modify, and cancel supported orders with application-owned reconciliation.

## Inspect orders and trades

Use the daily order book for order states and the trade list for individual exchange executions. An order can produce multiple partial-fill trades. A cancelled or rejected order can still have earlier fills. Persist records in your application if you need history beyond the trading day.

```swift
func inspectTradingDay(client: KiteClient, orderID: String) async throws {
	let book = try await client.orders()
	let history = try await client.orderHistory(orderID: orderID)
	let trades = try await client.trades()
	let fills = try await client.orderTrades(orderID: orderID)
	print(book.count, history.count, trades.count, fills.count)
}
```

Supply the opaque order ID directly. No prior placement through this client is required. History retains server ordering. Empty history does not disprove an uncertain submission.

## Submit one placement

Construct a ``KiteOrderPlacement`` and set the fields required for its order type and variety. The SDK checks request structure. Kite owns market hours, margin, lot sizes, tradability, and exchange eligibility.

```swift
func submitControlledLimit(client: KiteClient, limitPrice: Decimal) async throws
	-> KiteOrderPlacementResult
{
	var request = KiteOrderPlacement(
		tradingSymbol: "INFY", exchange: .nse, transactionType: .buy,
		orderType: .limit, quantity: 1, product: .cnc)
	request.price = limitPrice
	request.tag = "example34"
	return try await client.placeOrder(request)
}

func inspectPlacementReceipt(_ result: KiteOrderPlacementResult) {
	switch result {
	case .order(let receipt):
		print("Submitted order", receipt.orderID)
		for child in receipt.children ?? [] { print(child) }
	case .slices(let slices):
		for slice in slices {
			switch slice {
			case .placed(let receipt): print("Submitted slice", receipt.orderID)
			case .rejected(let failure): print(failure.code, failure.errorType, failure.message)
			}
		}
	}
}
```

Use mutation examples only with a controlled ``KiteHTTPTransport`` during verification. Extraction compiles these functions without calling them. Connecting the functions to a production client can place live orders.

Placement supports regular, AMO, cover, iceberg, and auction varieties. LIMIT and SL require `price`. Stop-loss orders require `triggerPrice`. TTL requires positive `validityTTL` minutes. Iceberg requires 2 through 50 legs and a positive per-leg quantity. Auction requires `auctionNumber`. Optional fields include disclosed quantity, market protection, autoslice, and an ASCII alphanumeric tag of at most 20 characters. A tag is not an idempotency key.

Inspect every auto-slice result. Kite can return an array of placed and rejected slices or an object receipt with child results. A receipt acknowledges submission, not exchange acceptance or execution. Malformed or ambiguous mutation receipts produce uncertainty without invented partial results.

## Modify or cancel an inspected order

Fetch current state before choosing the next action. Pass only the desired changes to ``KiteOrderModification``. Omitted fields remain unchanged. The following functions are independent actions, not a sequence to run after every placement.

```swift
func changeControlledLimit(client: KiteClient, orderID: String, newPrice: Decimal) async throws {
	var changes = KiteOrderModification()
	changes.price = newPrice
	let receipt = try await client.modifyOrder(orderID: orderID, changes: changes)
	print("Modification submitted", receipt.orderID)
}

func requestControlledCancellation(
	client: KiteClient, orderID: String, variety: KiteOrderMutationVariety,
	parentOrderID: String? = nil
) async throws {
	let receipt = try await client.cancelOrder(
		orderID: orderID, variety: variety, parentOrderID: parentOrderID)
	print("Cancellation submitted", receipt.orderID)
}
```

Match the original order variety. For cover-order child modification or cancellation, supply `parentOrderID` when required. Modification sends the parent ID in the body. Cancellation sends it in the query. Cancelling a cover-order second leg can exit its position. A cancellation receipt does not confirm the final cancelled quantity. Inspect state and trades after the request.

## Classify a failed submission

Keep confirmed API rejection separate from uncertainty. This example returns a message for the application to record. It does not submit a second request.

```swift
func submitControlledOrderWithOutcome(
	client: KiteClient, request: KiteOrderPlacement
) async throws -> String {
	do {
		let result = try await client.placeOrder(request)
		inspectPlacementReceipt(result)
		return "Submission acknowledged; reconcile order state and trades"
	} catch is CancellationError {
		return "Local task cancelled; reconcile before another mutation"
	} catch let error as KiteError {
		switch error {
		case .validation(let field, let message):
			return "Local validation failed for \(field): \(message)"
		case .api(let failure):
			return "API rejected request: \(failure.statusCode), \(failure.errorType ?? "unknown"), \(failure.message)"
		case .uncertainOutcome:
			return "Outcome uncertain; reconcile before another mutation"
		default:
			throw error
		}
	}
}
```

See <doc:Trading-mutation-outcomes> before deciding whether to act after an error or task cancellation.

## Topics

### Order state and executions

- ``KiteOrder``
- ``KiteOrderUpdate``
- ``KiteTrade``
- ``KiteTradeOrderTimestamp``
- ``KiteOrderStatus``
- ``KiteOrderMetadata``
- ``KiteTransactionType``
- ``KiteOrderValidity``
- ``KiteOrderVariety``

### Standalone mutations

- ``KiteOrderPlacement``
- ``KiteOrderModification``
- ``KiteOrderMutationVariety``
- ``KiteOrderMutationSide``
- ``KiteOrderMutationValidity``
- ``KiteOrderPlacementResult``
- ``KiteOrderMutationReceipt``
- ``KiteOrderSliceResult``
- ``KiteOrderSliceRejection``
- ``KiteOrderMutationJSONValue``
