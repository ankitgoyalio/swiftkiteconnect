# Manage alerts

Create, inspect, replace, and soft-delete simple alerts and alert-triggered order baskets.

## Define a comparison

Use ``KiteAlertCondition`` to compare an instrument attribute against a decimal constant or another instrument attribute. Attribute names are server-owned strings. The supported operators are less than, less than or equal, greater than, greater than or equal, and equal.

```swift
func makeSimplePriceAlert() -> KiteSimpleAlertRequest {
	let instrument = KiteAlertInstrument(
		exchange: .nse, tradingSymbol: "INFY", attribute: "LastTradedPrice")
	let condition = KiteAlertCondition(
		lhs: instrument, comparison: .greaterThanOrEqual, rhs: .constant(1500))
	return KiteSimpleAlertRequest(name: "INFY price", condition: condition)
}

func makeRelativePriceAlert() -> KiteSimpleAlertRequest {
	let left = KiteAlertInstrument(
		exchange: .nse, tradingSymbol: "INFY", attribute: "LastTradedPrice")
	let right = KiteAlertInstrument(
		exchange: .nse, tradingSymbol: "TCS", attribute: "LastTradedPrice")
	return KiteSimpleAlertRequest(
		name: "Relative price",
		condition: KiteAlertCondition(lhs: left, comparison: .lessThan, rhs: .instrument(right)))
}
```

## Define an order-triggering basket

Use ``KiteATOAlertRequest`` for an alert-triggered order basket, also called ATO. The basket has its own wire parameters. Standalone order placement rules do not apply to its documented zero TTL and iceberg values.

```swift
func makeBasketPriceAlert() -> KiteATOAlertRequest {
	let instrument = KiteAlertInstrument(
		exchange: .nse, tradingSymbol: "INFY", attribute: "LastTradedPrice")
	let condition = KiteAlertCondition(
		lhs: instrument, comparison: .greaterThan, rhs: .constant(1500))
	var parameters = KiteAlertOrderParameters(
		transactionType: .buy, product: .cnc, orderType: .limit, quantity: 1)
	parameters.price = 1501
	parameters.validityTTL = 0
	parameters.icebergLegs = 0
	parameters.tags = ["example34"]
	parameters.gtt = KiteAlertBasketGTT(target: 1600, stoploss: 1400)
	let item = KiteAlertBasketItem(tradingSymbol: "INFY", exchange: .nse, params: parameters)
	let basket = KiteAlertBasket(name: "INFY basket", items: [item])
	return KiteATOAlertRequest(name: "INFY basket alert", condition: condition, basket: basket)
}
```

The SDK sends the basket as JSON in a form field. It validates a nonempty basket, positive quantities, finite numeric values, and supplied text. Kite owns account eligibility, active-alert limits, and exchange rules. Retrieved baskets can omit name, type, tags, and item action fields. Preserve those absences when modifying a fetched basket instead of inventing metadata.

## Read and submit alert changes

Use status and positive page filters for listing. The SDK does not automatically request subsequent pages. Fetch current state before submitting a complete replacement definition for either alert kind.

```swift
func inspectPriceAlerts(client: KiteClient, uuid: String) async throws {
	let page = try await client.alerts(status: .enabled, page: 1, pageSize: 10)
	let alert = try await client.alert(uuid: uuid)
	let history = try await client.alertHistory(uuid: uuid)
	print(page.count, alert.status, history.count)
	for entry in history { print(entry.orderMetadata) }
}

func createControlledPriceAlerts(
	client: KiteClient, simple: KiteSimpleAlertRequest, basket: KiteATOAlertRequest
) async throws {
	let simpleReceipt = try await client.createAlert(simple)
	print("Created simple alert", simpleReceipt.uuid)
	let basketReceipt = try await client.createAlert(basket)
	print("Created basket alert", basketReceipt.uuid)
}

func replaceControlledSimpleAlert(
	client: KiteClient, uuid: String, completeDefinition: KiteSimpleAlertRequest
) async throws {
	_ = try await client.modifyAlert(uuid: uuid, alert: completeDefinition)
}

func replaceControlledBasketAlert(
	client: KiteClient, uuid: String, completeDefinition: KiteATOAlertRequest
) async throws {
	_ = try await client.modifyAlert(uuid: uuid, alert: completeDefinition)
}

func deleteControlledPriceAlert(client: KiteClient, uuid: String) async throws {
	try await client.deleteAlert(uuid: uuid)
}

func deleteControlledPriceAlerts(client: KiteClient, uuids: [String]) async throws {
	try await client.deleteAlerts(uuids: uuids)
}
```

Supply nonempty UUIDs containing only ASCII letters, digits, hyphens, or underscores. Bulk deletion requires at least one UUID and sends repeated query fields in input order. Deletion is soft deletion. Use these independent mutation examples with controlled transports. Verification compiles them without executing trading requests. Remote alert and ATO behavior remains unverified.

An ATO creation receipt can omit the basket. Alert history preserves trigger-time market data and unknown non-null `order_meta` as JSON. The documented schema specifies only null order metadata. Do not interpret an undocumented value as a standalone order or proof of execution.

Every mutation attempts once. See <doc:Trading-mutation-outcomes> for confirmed rejection, cancellation, and reconciliation before another action.

## Topics

### Alert state and comparisons

- ``KiteAlert``
- ``KiteAlertType``
- ``KiteAlertStatus``
- ``KiteAlertOperator``
- ``KiteAlertOperandType``
- ``KiteAlertInstrument``
- ``KiteAlertOperand``
- ``KiteAlertCondition``
- ``KiteAlertHistoryEntry``
- ``KiteAlertMarketData``
- ``KiteAlertOrderMetadata``

### Alert definitions

- ``KiteSimpleAlertRequest``
- ``KiteATOAlertRequest``
- ``KiteAlertBasket``
- ``KiteAlertBasketItem``
- ``KiteAlertOrderParameters``
- ``KiteAlertBasketGTT``

## Inspect a controlled alert lifecycle

Use these calls only with a controlled transport. Each mutation requires a separate application decision after inspecting current state.

```swift
func controlledAlertLifecycle(
	client: KiteClient, simple: KiteSimpleAlertRequest, ato: KiteATOAlertRequest, uuid: String
) async throws {
	_ = try await client.createAlert(simple)
	_ = try await client.createAlert(ato)
	_ = try await client.alerts(status: .enabled, page: 1, pageSize: 10)
	_ = try await client.alert(uuid: uuid)
	_ = try await client.alertHistory(uuid: uuid)
	_ = try await client.modifyAlert(uuid: uuid, alert: simple)
	_ = try await client.modifyAlert(uuid: uuid, alert: ato)
	try await client.deleteAlert(uuid: uuid)
	try await client.deleteAlerts(uuids: [uuid, "another-uuid"])
}
```
