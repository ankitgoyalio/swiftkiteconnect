# Connect and consume streams

Create a ticker, register independent event consumers, and explicitly close the connection when your application finishes.

## Create the ticker

Supply the application's current credentials to ``KiteTicker``. The default endpoint is production. For sandbox streaming, supply the sandbox endpoint and `userID`. Sandbox WSS qualification remains incomplete in this partial 0.x package.

```swift
func makeDocumentationTicker(apiKey: String, accessToken: String) throws -> KiteTicker {
	try KiteTicker(
		apiKey: apiKey, accessToken: accessToken,
		transport: NIOKiteWebSocketTransport(),
		reconnectPolicy: .init(
			initialDelay: .seconds(1), maximumDelay: .seconds(30), maximumAttempts: 5))
}
```

## Register consumers before connecting

Call ``KiteTicker/marketTicks(bufferCapacity:)``, ``KiteTicker/orderUpdates(bufferCapacity:)``, and ``KiteTicker/lifecycleEvents(bufferCapacity:)`` before connecting so that initial events can enter their buffers. Run consumers in application-owned tasks. Handle each consumer's failure independently.

This function owns its supplied ticker's lifecycle. It consumes market data and order updates concurrently, reports recovery events, and disconnects when any consumer ends. Cancelling the parent task also closes the ticker through this cleanup path.

```swift
func runDocumentationStreams(ticker: KiteTicker, token: UInt32) async throws {
	let market = try await ticker.marketTicks(bufferCapacity: 256)
	let orders = try await ticker.orderUpdates(bufferCapacity: 256)
	let lifecycle = try await ticker.lifecycleEvents(bufferCapacity: 64)
	do {
		try await withThrowingTaskGroup(of: Void.self) { group in
			group.addTask {
				for try await tick in market {
					print(tick.instrumentToken, tick.lastPrice, tick.details)
				}
			}
			group.addTask {
				for try await event in orders {
					print(event.update.orderID, event.update.status as Any)
				}
			}
			group.addTask {
				for try await event in lifecycle {
					switch event {
					case .possibleDataGap:
						print("Refresh market state and reconcile orders through REST")
					case .authenticationRequired:
						print("Obtain fresh credentials through application authentication")
					case .recoveryExhausted:
						print("End this lifecycle and decide when to reconnect")
					default: print(event)
					}
				}
			}
			defer { group.cancelAll() }
			try await ticker.connect()
			try await ticker.subscribe([token], mode: .full)
			try await group.next()
		}
	} catch {
		await ticker.disconnect()
		throw error
	}
	await ticker.disconnect()
}
```

Expect market-data output only when the subscribed instrument receives an update. Order updates require order activity for the session. The printed recovery messages identify work for your application. They do not perform reconciliation or authenticate a new session.

## Change subscriptions or credentials

Serialize subscription commands. Use nonzero instrument tokens and at most 3000 unique desired subscriptions per ticker. Choose ``KiteTickerMode/ltp`` for last price, ``KiteTickerMode/quote`` for quote fields, or ``KiteTickerMode/full`` for available timestamps and depth. Inspect ``KiteMarketTick/details`` because packets already in flight can use the previous layout, and index layouts differ from tradable instruments.

```swift
func updateDocumentationStreams(
	ticker: KiteTicker, token: UInt32, apiKey: String, freshAccessToken: String
) async throws {
	try await ticker.setMode(.quote, for: [token])
	try await ticker.unsubscribe([token])
	try await ticker.replaceCredentials(apiKey: apiKey, accessToken: freshAccessToken)
}
```

Pass `userID` when replacing sandbox credentials. REST client credentials and ticker credentials do not update each other. After explicit disconnect, register new streams, call `connect()`, and subscribe again. See <doc:Streaming-recovery> before choosing how your application handles interrupted delivery.
