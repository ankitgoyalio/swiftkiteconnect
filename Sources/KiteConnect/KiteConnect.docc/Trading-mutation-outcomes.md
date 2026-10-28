# Trading mutation outcomes

A request acknowledgement and a final trading outcome describe different events.

## Submission and execution

An order receipt identifies a submission. A trade records an exchange execution, including a partial fill. A GTT receipt acknowledges a stored trigger mutation. An alert acknowledgement describes the alert lifecycle. None of those acknowledgements proves that an order filled.

An order update describes order state through WebSocket streaming or an HTTP postback. A postback is an incoming notification to the application's registered callback URL. A market-data tick is a quote update. Neither notification delivery nor a quote establishes an order's final outcome.

## Failures and uncertainty

Each REST operation attempts once. The SDK does not automatically retry reads or trading mutations. Applications own scheduling under broker limits. Automatically retrying a trading mutation is prohibited because the first attempt may already have reached Kite.

``KiteError/validation(field:message:)`` reports a local structural failure before dispatch. A valid Kite error envelope is a confirmed API rejection. ``KiteError/api(_:)`` retains the HTTP status, raw error type, message, and response headers, including rate-limit responses. Transport and decoding failures remain distinct. For a trading mutation, a lost response, gateway failure, or malformed success receipt can become ``KiteError/uncertainOutcome(_:)`` because Kite may already have accepted the action.

`CancellationError` remains recognizable. Cancelling a Swift task stops local waiting and transport work. Cancellation after dispatch does not establish that Kite rejected or reversed the request. Cancelling a task and calling the order cancellation endpoint are different operations.

## Application-owned reconciliation

Before another mutation, reconcile the observed state with the application's saved intent. For orders, inspect order history, trades, portfolio state, and order updates as appropriate. For GTT, inspect stored triggers and embedded submission results. For alerts, inspect alert state and history. Empty order history does not prove nonacceptance, and an application tag is not an idempotency key.

Recovery does not automatically reconcile orders. Missed streaming events are not replayed. The application must decide what evidence establishes an outcome before authorizing another action. Fixture-backed verification checks protocol handling without live credentials or trading requests. It does not qualify this partial 0.x package for live trading.

See <doc:Request-and-response-contracts> for the shared reference and <doc:First-request> for the introductory read-only tutorial.
