# Using KiteConnect

This guide describes the partial 0.x package at the pinned 2026-10-27 snapshot.
Every Swift block below is compiled as part of the test suite; see
[the generated example source](../Tests/KiteConnectTests/DocumentationExamples.swift).
Functions illustrate independent operations and send requests only if your app
calls them. Mutating examples are for controlled transports; no remote orders are
part of the routine suite. [Coverage](Coverage.md) maps every route to tests and usage.

## Authentication and sessions

Applications own browser presentation, exact registered callback validation,
request-token routing, credential storage and logout UI. Keep `apiSecret` on a
backend for distributed apps. The request token is short lived and exchanged once;
never put secrets or access tokens in logs or public browser payloads. The default
REST/login/ticker endpoints are production. Sandbox requires `.sandbox`, the
explicit sandbox login endpoint below, and `userID` on the sandbox ticker.
There is no implicit production fallback.

```swift
import Foundation
import KiteConnect

func sandboxClient() throws -> KiteClient {
  try KiteClient(apiKey: "sandboxdemo", configuration: .sandbox)
}

func sandboxLogin(client: KiteClient) throws -> URL {
  try client.loginURL(
    redirectParameters: "application_state=opaque-value",
    endpoint: URL(string: "https://sandbox.kite.trade/connect/login")!)
}

// Backend only. Installs credentials after a validated response.
func exchangeOnBackend(client: KiteClient, requestToken: String, apiSecret: String) async throws {
  let session = try await client.exchangeRequestToken(requestToken, apiSecret: apiSecret)
  print(session.profile.userID)  // Store tokens through your own credential store.
  _ = try await client.profile()
  _ = try await client.margins()
  _ = try await client.margins(segment: .equity)
}

// Additional SDK-reference operations; refresh permission requires Kite approval.
func approvedPlatformRenewal(client: KiteClient, refreshToken: String, apiSecret: String)
  async throws
{
  _ = try await client.renewSession(refreshToken: refreshToken, apiSecret: apiSecret)
  _ = try await client.invalidateRefreshToken(refreshToken)
}

func endSession(client: KiteClient) async throws {
  _ = try await client.invalidateSession()
}
```

A client represents one API key/user session. Share its actor across tasks; use
separate clients for separate users. `replaceAccessToken(nil)` clears credentials
locally without a remote logout. Await replacement before admitting new work;
requests already handed to the transport can finish with old credentials.
A late exchange/renewal/invalidation cannot overwrite a newer explicit session.
Ticker credentials are separate: update them explicitly with `replaceCredentials`.
Session expiry (including `TokenException`) requires application login handling;
the SDK does not automatically refresh or retry REST calls. The snapshot states
access tokens expire at 6 AM the next day unless invalidated sooner; refresh tokens
are restricted to approved platforms, not general perpetual login.

## REST, instruments and historical data

Each call has one transport attempt. Configure `KiteConfiguration(timeout:tradingTimeZone:)`
for deadlines and offsetless timestamp interpretation. Explicit offsets take
precedence; the default trading timezone is Asia/Kolkata. `KiteDateOnly` preserves
calendar dates; financial fields use `Decimal`. Unknown server enum values carry
their raw string. Additional fields are tolerated; malformed required values fail.

```swift
func marketReads(client: KiteClient, from: Date, to: Date) async throws {
  let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
  let instruments = try await client.instruments()
  _ = try await client.instruments(exchange: .nse)
  let quotes = try await client.quotes(instruments: [identity])
  _ = try await client.ohlc(instruments: [identity])
  _ = try await client.ltp(instruments: [identity])
  if let token = instruments.first(where: { $0.identity == identity })?.instrumentToken {
    _ = try await client.historicalCandles(
      instrumentToken: token, interval: .minute, from: from, to: to, oi: true)
  }
  print(quotes.count)
}
```

The snapshot suggests refreshing the large instrument dump daily around 08:30;
that schedule remains application-owned. Quote requests accept at most 500 identities for full quotes, 1000 for OHLC/LTP;
missing response keys mean an instrument was unavailable, not a zero quote.
Persist exchange/trading-symbol identities rather than reusable numeric tokens.
The instrument dump is daily, its `lastPrice` is not a live quote. Apps own caching,
refresh scheduling and expired-token retention. Continuous history uses a live
NFO/MCX futures token with `continuous: true` and `.day`; it is not an expired
options-token lookup. All eight documented historical intervals and optional OI
are supported. Sandbox historical access can vary by account; the sandbox page
describes an approximate 1900-day limit per day-candle request. Apps split larger
ranges rather than relying on hidden chunking. The shared HTTP transport supplies decompressed response bytes,
including CSV; the default URLSession adapter handles HTTP Content-Encoding.

## Orders, uncertain outcomes and reconciliation

```swift
func inspectOrder(client: KiteClient, orderID: String) async throws {
  _ = try await client.orders()
  _ = try await client.orderHistory(orderID: orderID)
  _ = try await client.trades()
  _ = try await client.orderTrades(orderID: orderID)
}

func controlledOrderLifecycle(client: KiteClient, price: Decimal, orderID: String) async throws {
  var order = KiteOrderPlacement(
    tradingSymbol: "INFY", exchange: .nse, transactionType: .buy,
    orderType: .limit, quantity: 1, product: .cnc)
  order.price = price
  order.tag = "example24"
  let result = try await client.placeOrder(order)
  switch result {
  case .order(let receipt): print(receipt.orderID)
  case .slices(let slices): print(slices)  // Inspect every placed/rejected slice.
  }
  var changes = KiteOrderModification()
  changes.price = price
  _ = try await client.modifyOrder(orderID: orderID, changes: changes)
  _ = try await client.cancelOrder(orderID: orderID)
}
```

The order book and trade list are daily transient views; persist any longer-lived
application record yourself. One order may produce multiple partial-fill trades.
The lifecycle function shows separate calls, not an automatic strategy. Only call
modify/cancel after inspecting current state. `variety` supports regular, AMO, CO,
iceberg and auction. Placement exposes TTL, disclosed quantity, iceberg legs and
quantity, auction number, market protection, auto-slice and tag. Parent IDs are
available for CO child modification/cancellation. Canceling a CO second leg can
exit its position. Auto-slice responses can contain both placed slices and
rejections; successful receipts and GTT/ATO acknowledgements do not prove fills.

Handle `KiteError.validation`, `.transport`, `.api`, `.decoding` and
`.uncertainOutcome`. API failures retain HTTP status, raw error type, message and
headers (including 429). Apps own scheduling within current broker limits.
A valid Kite error envelope is a confirmed rejection; a lost response, gateway
failure or malformed mutation receipt can mean the action reached Kite.
`CancellationError` remains recognizable, including after dispatch, and likewise
does not prove nonacceptance. Before another mutation, inspect order history,
trades, portfolio and updates as appropriate. Compare app-owned intent/tag and
order identifiers; do not blindly repeat the submission or assume a tag is an
idempotency key. Use `KiteHTTPTransport` for controlled tests; custom transports
must honor one attempt, cancellation, timeout and response decompression.
The default HTTP adapter refuses redirects.

## GTT and alerts

```swift
func controlledGTTLifecycle(client: KiteClient, definition: KiteGTTRequest) async throws {
  let receipt = try await client.createGTT(definition)
  _ = try await client.gttTriggers()
  _ = try await client.gttTrigger(id: receipt.triggerID)
  _ = try await client.modifyGTT(id: receipt.triggerID, trigger: definition)
  _ = try await client.deleteGTT(id: receipt.triggerID)
}

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

The GTT list includes active triggers and other states from the previous seven
days; individual lookup is independent of age/status.
Fetch before modifying and supply the complete desired definition. Single GTT
uses one trigger/order; two-leg OCO uses two. GTT lifecycle states and nested
execution results remain inspectable. Alerts support constant or instrument RHS,
all five documented comparison operators, status/page filtering, history, repeated
UUID deletion and ATO JSON baskets inside a form field. Basket models preserve
basket-specific order parameters and optional nested GTT fields; standalone order
rules are not applied to their zero-valued TTL/iceberg examples. Kite enforces
account eligibility, active-alert limits and exchange rules. The examples above construct each variant;
[Contracts](Contracts.md) describes validation and compatibility.
GTT is explicitly unavailable in sandbox; remote alert/ATO behavior is unverified.

## Portfolio, exits and depository authorisation

```swift
func portfolioReads(client: KiteClient) async throws {
  _ = try await client.holdings()
  _ = try await client.auctionHoldings()
  _ = try await client.positions()
}

func controlledConversion(client: KiteClient, conversion: KitePositionConversion) async throws {
  _ = try await client.convertPosition(conversion)
}

func prepareHoldingsAuthorisation(client: KiteClient, isin: String, quantity: Int64) async throws
  -> KiteHoldingsAuthorisationFlow
{
  let receipt = try await client.authoriseHoldings(instruments: [
    .init(isin: isin, quantity: quantity)
  ])
  return try client.holdingsAuthorisationFlow(requestID: receipt.requestID)
}

func submitPositionExit(client: KiteClient, position: KitePosition, limitPrice: Decimal)
  async throws -> KiteOrderPlacementResult?
{
  guard let quantity = Int64(exactly: position.quantity.magnitude), quantity > 0 else { return nil }
  var order = KiteOrderPlacement(
    tradingSymbol: position.tradingSymbol, exchange: position.exchange,
    transactionType: position.quantity > 0 ? .sell : .buy,
    orderType: .limit, quantity: quantity, product: position.product)
  order.price = limitPrice
  return try await client.placeOrder(order)
}
```

There is no dedicated exit route. Exit a position with the opposite side and the
same product/identity; a holding exit uses SELL for the application-selected
available quantity. A LIMIT order can remain unfilled; MARKET is unavailable in
sandbox. Snapshot prose suggests MARKET for immediate exits but does not guarantee
execution. Reconcile after submission before reporting an exit.

A confirmed 428 can require depository authorisation. `authoriseHoldings()` with no
items presents all holdings; explicit items encode repeated ISIN/quantity pairs.
Present the returned flow's `url` in the app's chosen browser and feed navigation
URLs into `completionStatus(for:)`. Only the exact HTTPS origin/path and matching
API key/request ID finish URL are recognized; preserve unfamiliar statuses.
Browser success is not independent proof of authorisation or of an order fill.
The depository owns the PIN. The SDK owns neither browser UI nor PIN handling.
The documented browser origin is `kite.zerodha.com`; no sandbox equivalent is
specified, so this flow has not been exercised remotely. See [portfolio details](Contracts.md).

## Margin calculations and mutual funds

```swift
func estimates(client: KiteClient, orders: [KiteMarginOrder], charges: [KiteChargeOrder])
  async throws
{
  _ = try await client.orderMargins(orders)
  _ = try await client.compactOrderMargins(orders)
  _ = try await client.basketMargins(orders, considerPositions: true)
  _ = try await client.compactBasketMargins(orders, considerPositions: false)
  _ = try await client.orderCharges(charges)
}

func mutualFundReads(client: KiteClient, orderID: String) async throws {
  _ = try await client.mutualFundOrders()
  _ = try await client.mutualFundOrder(orderID: orderID)
  _ = try await client.mutualFundSIPs()
  _ = try await client.mutualFundHoldings()
  _ = try await client.mutualFundInstruments()
}
```

Calculations estimate hypothetical orders; they do not submit trades. Basket aggregate charges may omit transaction-tax amounts for mixed STT/CTT
segments; prefer the per-order charge breakdown. Full and
compact basket modes retain their distinct response shapes and `consider_positions`
choice. Remote calculation APIs are sandbox-excluded. Mutual-fund coverage follows
the five selected read routes: the snapshot explicitly disallows order placement
because bank payment is required. It provides no SIP mutation or individual SIP
route. The order list covers seven days; individual order lookup is not age-limited.
SIPs include active/paused plans and documented -1 instalment sentinels. The
snapshot excludes dividend reinvestment schemes. Fractional
fund units and financial values use Decimal. MF CSV is authenticated and uses the
sandbox `/oms` prefix, unlike the equity dump. See [Contracts](Contracts.md) for calculation and mutual-fund response semantics.

## Streaming and recovery

```swift
func sandboxTicker(apiKey: String, accessToken: String, userID: String) throws -> KiteTicker {
  try KiteTicker(
    apiKey: apiKey, accessToken: accessToken, userID: userID,
    endpoint: URL(string: "wss://ws-sandbox.kite.trade")!,
    transport: NIOKiteWebSocketTransport(),
    reconnectPolicy: .init(
      initialDelay: .seconds(1), maximumDelay: .seconds(30), maximumAttempts: 5))
}

func consumeMarket(ticker: KiteTicker, token: UInt32) async throws {
  let stream = try await ticker.marketTicks(bufferCapacity: 256)
  try await ticker.connect()
  try await ticker.subscribe([token], mode: .full)
  do {
    for try await tick in stream { print(tick.instrumentToken, tick.lastPrice, tick.details) }
  } catch {
    await ticker.disconnect()
    throw error
  }
  await ticker.disconnect()
}

// Run independent consumers in application-owned tasks on the same ticker.
func consumeOrders(ticker: KiteTicker) async throws {
  for try await event in try await ticker.orderUpdates(bufferCapacity: 256) {
    print(event.update.orderID, event.update.status as Any)
  }
}

func consumeLifecycle(ticker: KiteTicker) async throws {
  for try await event in try await ticker.lifecycleEvents() {
    switch event {
    case .possibleDataGap: print("Reconcile orders and refresh application state")
    case .authenticationRequired: print("Fresh credentials are required")
    default: print(event)
    }
  }
}

func streamingControls(ticker: KiteTicker, token: UInt32, accessToken: String, userID: String)
  async throws
{
  try await ticker.setMode(.quote, for: [token])
  try await ticker.unsubscribe([token])
  try await ticker.replaceCredentials(
    apiKey: "sandboxdemo", accessToken: accessToken, userID: userID)
  await ticker.disconnect()
}
```

Create streams before connecting. `ticks()` is the LTP projection of all market
layouts; `marketTicks()` includes LTP, quote/full, index quote/full, depth and epoch
timestamps. Heartbeats are ignored, multi-packet messages decoded, malformed
binary/text messages fail explicitly. `brokerEvents()` delivers message/error and
unknown JSON types separately from `orderUpdates()`.

Each stream registration has an independent bounded buffer. Overflow throws
`KiteTickerError.bufferOverflow` for that subscriber; a healthy subscriber and
other event families continue. Canceling a subscriber does not disconnect the
ticker. The adapter's separate bounded ingress overflow is a connection failure
and may cause a gap/recovery for everyone. Lifecycle streams are also bounded.

One ticker owns one connection. Apps allocate additional tickers explicitly and
respect the snapshot's three connections per key and 3000 tokens per connection;
there is no pooling. Recovery uses configurable bounded backoff, restores desired
subscriptions/modes, and emits a possible gap. There is no missed-event replay.
Authentication rejection stops recovery until fresh credentials arrive; replacing
credentials fences stale handshakes/writes. A new handshake waits for physical
teardown of the preceding socket, including cleanup of a late canceled handshake
result. Recovery delay alone does not release that fence. Custom transports must
honor cancellation and complete close; an uncooperative transport holds admission
until its handshake/close settles. Disconnect cancels recovery and closes streams. Register new streams after disconnect if connecting again. REST and ticker
credentials do not update each other. Reconcile missed orders through REST.
`NIOKiteWebSocketTransport` passed real Ubuntu HTTP/WebSocket tests. Local trusted
TLS/WSS, hostname rejection and IP-address handling pass on macOS and iOS Simulator; the latest
transport changes await hosted matrix confirmation. TLS verifies certificates and
hostnames with no insecure switch. By default it uses system trust roots. For a
private origin, `trustRootsPEM` accepts PEM certificates and replaces system roots
for that transport instance only; it does not install certificates into the OS.
Do not use the public test fixture CA outside loopback tests. Sandbox WSS remains
unverified under #27.

## Incoming postbacks and Publisher

```swift
// Backend HTTP handler: your server supplies the raw JSON body and stored secret.
func validatePostback(body: Data, apiSecret: String) throws -> KitePostback {
  try KitePostbacks.decode(body, apiSecret: apiSecret)
}
```

The backend owns HTTPS ingress, app/user routing, replay protection and processing.
The checksum binds the order ID and original timestamp text plus the API secret;
it does not cryptographically bind every payload field. Validation is not proof
of execution or freshness. WebSocket updates use the same order model but do not
perform backend-secret checksum verification. HTTP postbacks can arrive while a user is logged out and cover orders placed
by the app API key; user WebSocket updates can include orders placed elsewhere.
Deduplicate and reconcile by observed order state rather than delivery count.
See [postback details](Contracts.md).

[Publisher guidance](Publisher.md) covers offsite browser form POST, static branded
and custom buttons, dynamic baskets, ready/add/render/link/redirect/callback APIs,
and `authHoldings`. These are browser integrations, not Swift REST endpoints.
Apps own the browser and callbacks. The JS plugin has a ten-item basket limit and
an iOS WebView cookie-policy restriction; the snapshot recommends offsite flows.
Its tag limit differs from the offsite page; use the stricter documented limit
when sharing baskets. Neither flow has been remotely qualified in sandbox.
