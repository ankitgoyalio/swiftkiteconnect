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

func inspectTradingDay(client: KiteClient, orderID: String) async throws {
	let book = try await client.orders()
	let history = try await client.orderHistory(orderID: orderID)
	let trades = try await client.trades()
	let fills = try await client.orderTrades(orderID: orderID)
	print(book.count, history.count, trades.count, fills.count)
}

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
