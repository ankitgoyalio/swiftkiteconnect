# Manage GTT triggers

Create, inspect, replace, and delete single-leg or two-leg OCO trigger definitions.

## Construct a complete definition

Use ``KiteGTTConditionRequest`` for the exchange, trading symbol, trigger prices, and last traded price. Associate each trigger value with the order at the same array index. Single requires one trigger and one order. Two-leg OCO requires two of each. Preserve that order when replacing a fetched definition.

```swift
func makeSingleTrigger() throws -> KiteGTTRequest {
	let instrument = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
	let condition = KiteGTTConditionRequest(
		instrument: instrument, triggerValues: [1500], lastPrice: 1450)
	let order = KiteGTTOrderRequest(
		instrument: instrument, transactionType: .buy, quantity: 1, product: .cnc, price: 1501)
	return KiteGTTRequest(type: .single, condition: condition, orders: [order])
}

func makeOCOTrigger() throws -> KiteGTTRequest {
	let instrument = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
	let condition = KiteGTTConditionRequest(
		instrument: instrument, triggerValues: [1400, 1600], lastPrice: 1500)
	let stop = KiteGTTOrderRequest(
		instrument: instrument, transactionType: .sell, quantity: 1, product: .cnc, price: 1399)
	let target = KiteGTTOrderRequest(
		instrument: instrument, transactionType: .sell, quantity: 1, product: .cnc, price: 1600)
	return KiteGTTRequest(type: .twoLeg, condition: condition, orders: [stop, target])
}
```

GTT embedded orders use LIMIT with a positive quantity and BUY or SELL direction. The SDK validates leg counts and finite decimal values. Broker eligibility and exchange rules remain Kite's responsibility. The embedded definitions are distinct from ``KiteOrderPlacement``.

## Read and submit trigger changes

Use ``KiteClient/gttTriggers()`` for active triggers and other states retained from the previous seven days. Use ``KiteClient/gttTrigger(id:)`` for individual lookup independently of age or status.

```swift
func inspectStoredTriggers(client: KiteClient, triggerID: Int64) async throws {
	let recent = try await client.gttTriggers()
	let trigger = try await client.gttTrigger(id: triggerID)
	print(recent.count, trigger.status)
	for order in trigger.orders {
		print(order.result?.orderResult as Any)
	}
}

func createControlledTrigger(client: KiteClient, definition: KiteGTTRequest) async throws -> Int64 {
	let receipt = try await client.createGTT(definition)
	return receipt.triggerID
}

func replaceControlledTrigger(
	client: KiteClient, triggerID: Int64, completeDefinition: KiteGTTRequest
) async throws {
	_ = try await client.modifyGTT(id: triggerID, trigger: completeDefinition)
}

func deleteControlledTrigger(client: KiteClient, triggerID: Int64) async throws {
	_ = try await client.deleteGTT(id: triggerID)
}
```

Fetch current state before constructing a replacement. Modification submits the complete desired definition, rather than merging omitted fields. Supply positive trigger IDs for lookup, modification, and deletion. Use mutation examples with controlled transports. Verification compiles them without issuing requests. GTT is unavailable in the documented sandbox.

Inspect ``KiteGTTTrigger/status`` separately from each embedded ``KiteGTTOrder/result``. A triggered condition can produce a failed order submission. A successful submission still does not prove a fill. Optional result fields can be missing or null, and failed attempts can have an empty order ID. Execution metadata retains the server's JSON-encoded string verbatim.

Every mutation attempts once. A malformed acknowledgement, including a nonpositive trigger ID, can indicate an uncertain outcome after server acceptance. See <doc:Trading-mutation-outcomes> before another mutation.

## Topics

### Stored triggers

- ``KiteGTTTrigger``
- ``KiteGTTType``
- ``KiteGTTStatus``
- ``KiteGTTCondition``
- ``KiteGTTOrder``
- ``KiteGTTExecution``
- ``KiteGTTOrderResult``
- ``KiteGTTOrderResultStatus``

### Trigger mutations

- ``KiteGTTRequest``
- ``KiteGTTConditionRequest``
- ``KiteGTTOrderRequest``
- ``KiteGTTReceipt``
