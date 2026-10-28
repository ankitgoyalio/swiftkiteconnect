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

// Backend only. The caller supplies the secret from backend configuration.
// Authenticate the application request and validate its login flow before calling.
func doccBackendExchange(
	apiKey: String, requestToken: String, backendAPISecret: String
) async throws -> KiteSessionCredentials {
	let client = try KiteClient(apiKey: apiKey)
	let session = try await client.exchangeRequestToken(
		requestToken, apiSecret: backendAPISecret)
	return KiteSessionCredentials(apiKey: session.apiKey, accessToken: session.accessToken)
}

func doccSandboxAuthentication(apiKey: String) throws -> (KiteClient, URL) {
	let client = try KiteClient(apiKey: apiKey, configuration: .sandbox)
	let login = try client.loginURL(
		endpoint: URL(string: "https://sandbox.kite.trade/connect/login")!)
	return (client, login)
}

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

func makeDocumentationTicker(apiKey: String, accessToken: String) throws -> KiteTicker {
	try KiteTicker(
		apiKey: apiKey, accessToken: accessToken,
		transport: NIOKiteWebSocketTransport(),
		reconnectPolicy: .init(
			initialDelay: .seconds(1), maximumDelay: .seconds(30), maximumAttempts: 5))
}

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

func updateDocumentationStreams(
	ticker: KiteTicker, token: UInt32, apiKey: String, freshAccessToken: String
) async throws {
	try await ticker.setMode(.quote, for: [token])
	try await ticker.unsubscribe([token])
	try await ticker.replaceCredentials(apiKey: apiKey, accessToken: freshAccessToken)
}

func configuredSandboxClient(accessToken: String) throws -> KiteClient {
	try KiteClient(
		apiKey: "sandboxdemo",
		accessToken: accessToken,
		configuration: .sandbox)
}

func discoverINFY(client: KiteClient) async throws -> KiteInstrument? {
	let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
	let catalogue = try await client.instruments(exchange: .nse)
	let instrument = catalogue.first { $0.identity == identity }
	if let instrument {
		print(instrument.identity.description, instrument.instrumentToken)
	}
	return instrument
}

func inspectPublisherOutcome(client: KiteClient) async throws -> (
	orders: [KiteOrder], trades: [KiteTrade]
) {
	let orders = try await client.orders()
	let trades = try await client.trades()
	return (orders, trades)
}

func equityFunds(client: KiteClient) async throws -> Decimal? {
	let funds = try await client.margins(segment: .equity)
	return funds.enabled ? funds.net : nil
}

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

func inspectEquityPortfolio(client: KiteClient) async throws -> KitePositions {
	let holdings = try await client.holdings()
	let auctions = try await client.auctionHoldings()
	_ = holdings.first?.identity
	_ = auctions.first?.auctionNumber
	return try await client.positions()
}

func convertPortfolioProduct(client: KiteClient, instrument: KiteInstrumentIdentity)
	async throws -> Bool
{
	let conversion = KitePositionConversion(
		instrument: instrument, transactionType: .buy, positionType: .day,
		quantity: 1, oldProduct: .mis, newProduct: .cnc)
	return try await client.convertPosition(conversion)
}

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

func inspectFundActivity(client: KiteClient, orderID: String)
	async throws -> [KiteMutualFundSIP]
{
	_ = try await client.mutualFundOrders()
	_ = try await client.mutualFundOrder(orderID: orderID)
	return try await client.mutualFundSIPs()
}

func inspectFundInventory(client: KiteClient) async throws -> [KiteMutualFundInstrument] {
	let holdings = try await client.mutualFundHoldings()
	_ = holdings.first?.quantity
	return try await client.mutualFundInstruments()
}

func decodeIncomingHTTPPostback(body: Data, backendSecret: String) throws -> KitePostback {
	try KitePostbacks.decode(body, apiSecret: backendSecret)
}

func offlineHTTPPostbackBody() -> Data {
	Data(#"""
	{
	"user_id": "AB1234",
	"unfilled_quantity": 0,
	"app_id": 1234,
	"checksum": "d6b6e7d40302670c95e8b74da93e29b86ca66b85adbe056363af4191178fd21c",
	"placed_by": "AB1234",
	"order_id": "220303000308932",
	"exchange_order_id": "1000000001482421",
	"parent_order_id": null,
	"status": "COMPLETE",
	"status_message": null,
	"status_message_raw": null,
	"order_timestamp": "2022-03-03 09:24:25",
	"exchange_update_timestamp": "2022-03-03 09:24:25",
	"exchange_timestamp": "2022-03-03 09:24:25",
	"variety": "regular",
	"exchange": "NSE",
	"tradingsymbol": "SBIN",
	"instrument_token": 779521,
	"order_type": "MARKET",
	"transaction_type": "BUY",
	"validity": "DAY",
	"product": "CNC",
	"quantity": 1,
	"disclosed_quantity": 0,
	"price": 0,
	"trigger_price": 0,
	"average_price": 470,
	"filled_quantity": 1,
	"pending_quantity": 0,
	"cancelled_quantity": 0,
	"market_protection": 0,
	"meta": {},
	"tag": null,
	"guid": "XXXXXX"
	}
	"""#.utf8)
}

func readHistoricalCandles(
	client: KiteClient, instrumentToken: UInt32, from: Date, to: Date
) async throws -> [KiteHistoricalCandle] {
	let candles = try await client.historicalCandles(
		instrumentToken: instrumentToken, interval: .minute,
		from: from, to: to, oi: true)
	for candle in candles {
		print(candle.timestamp, candle.close, candle.volume, candle.openInterest as Any)
	}
	return candles
}

func readContinuousFuturesDays(
	client: KiteClient, liveFuturesToken: UInt32, from: Date, to: Date
) async throws -> [KiteHistoricalCandle] {
	try await client.historicalCandles(
		instrumentToken: liveFuturesToken, interval: .day,
		from: from, to: to, continuous: true)
}

func readINFYSnapshots(client: KiteClient) async throws {
	let identity = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
	let full = try await client.quotes(instruments: [identity])
	if let quote = full[identity] {
		print(quote.lastPrice, quote.timestamp, quote.depth.buy.count)
	} else {
		print("Full quote unavailable for", identity.description)
	}
	let summaries = try await client.ohlc(instruments: [identity])
	if let summary = summaries[identity] {
		print(summary.lastPrice, summary.ohlc.close)
	}
	let prices = try await client.ltp(instruments: [identity])
	if let price = prices[identity] {
		print(price.instrumentToken, price.lastPrice)
	}
}

//
//  FirstRequest-Install.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.


func tutorialClient(apiKey: String) throws -> KiteClient {
    try KiteClient(apiKey: apiKey)
}

//
//  FirstRequest-Login.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.


func tutorialLoginURL(client: KiteClient) throws -> URL {
    try client.loginURL()
}

//
//  FirstRequest-Profile.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.


func tutorialFetchProfile(client: KiteClient) async throws -> KiteUserProfile {
    let profile = try await client.profile()
    print(profile.userID)
    return profile
}

//
//  FirstRequest-Session.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.


func tutorialInstallAccessToken(client: KiteClient, accessToken: String) async throws {
    try await client.replaceAccessToken(accessToken)
}
