// Generated from Markdown, KiteConnect.docc, and tutorial resources; run python3 Scripts/check-documentation-examples.py --write.
import Foundation
import KiteConnect

func readProfile(accessToken: String) async throws -> KiteUserProfile {
  let client = try KiteClient(
    apiKey: "sandboxdemo", accessToken: accessToken, configuration: .sandbox)
  return try await client.profile()
}

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

// Backend HTTP handler: your server supplies the raw JSON body and stored secret.
func validatePostback(body: Data, apiSecret: String) throws -> KitePostback {
  try KitePostbacks.decode(body, apiSecret: apiSecret)
}

func configuredSandboxClient(accessToken: String) throws -> KiteClient {
	try KiteClient(
		apiKey: "sandboxdemo",
		accessToken: accessToken,
		configuration: .sandbox)
}

func inspectPublisherOutcome(client: KiteClient) async throws -> (
	orders: [KiteOrder], trades: [KiteTrade]
) {
	let orders = try await client.orders()
	let trades = try await client.trades()
	return (orders, trades)
}
