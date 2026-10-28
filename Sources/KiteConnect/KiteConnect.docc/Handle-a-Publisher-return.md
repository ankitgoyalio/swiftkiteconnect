# Handle a Publisher return

Validate a Publisher callback and inspect the authenticated order state before reporting a result.

The application owns redirect handling. See <doc:Publisher-integration> for browser ownership and uncertain-outcome constraints.

## Validate the redirect

The offsite page has inconsistent terminology: its note uses `redirect_url`
and `request_token`, while a later paragraph says `redirect_login` and
`request_key`. Follow the canonical [login contract](https://kite.trade/docs/connect/v3/user/#login-flow):
the registered redirect receives `request_token`. Do not invent a `request_key`
exchange parameter. Validate the actual callback during sandbox qualification.

Application callback handling must match the registered scheme, host, port and
path exactly, bind the attempt to the initiating application user, and reject
missing or duplicate token or status parameters. Preserve unfamiliar status text
as an unknown result; do not treat it as success. Ignore unrelated extra query
fields. The following pure JavaScript example illustrates URL validation only;
it does not exchange tokens or prove callback authenticity:

```javascript
function parsePublisherReturn(location, registeredRedirect) {
  let actual, expected;
  try {
    actual = new URL(location);
    expected = new URL(registeredRedirect);
  } catch { return null; }
  if (actual.origin !== expected.origin || actual.pathname !== expected.pathname ||
      actual.username || actual.password || actual.hash) return null;
  const tokens = actual.searchParams.getAll("request_token");
  const statuses = actual.searchParams.getAll("status");
  if (tokens.length !== 1 || !tokens[0] || statuses.length !== 1 || !statuses[0]) {
    return null;
  }
  return { requestToken: tokens[0], status: statuses[0] };
}
```

A browser token may be disregarded when no API session is needed. Otherwise,
send it promptly over the application's authenticated HTTPS channel to its
backend. The backend exchanges the one-time, short-lived `request_token` via
`POST /session/token`, with `api_key` and SHA-256 of
`api_key + request_token + api_secret`; see
[authentication](https://kite.trade/docs/connect/v3/user/#authentication-and-token-exchange).
Keep the secret on the backend and tokens out of logs, analytics and public
URLs after processing. The application owns storage and separate credentials
for each user. Never share a global mutable session between users. A Swift backend can use ``KiteClient/exchangeRequestToken(_:apiSecret:)``. The SDK does not supply the application's backend protocol or credential store.

## Reconcile through an authenticated session

Pass a ``KiteClient`` for the initiating user's session to this read-only example. It retrieves the current trading day's orders and executions without submitting or resubmitting a basket.

```swift
import KiteConnect

func inspectPublisherOutcome(client: KiteClient) async throws -> (
	orders: [KiteOrder], trades: [KiteTrade]
) {
	let orders = try await client.orders()
	let trades = try await client.trades()
	return (orders, trades)
}
```

The two reads are separate requests, not an atomic snapshot. Match the returned records to the application's pending basket and user. A callback status alone does not identify accepted entries or fills. Use ``KiteClient/orderHistory(orderID:)`` and ``KiteClient/orderTrades(orderID:)`` when an order ID is known.

The function propagates transport, API, decoding, and cancellation errors. An error leaves reconciliation incomplete. Closing the browser does not cancel a submitted order, and a missing callback does not justify automatic resubmission. See <doc:Create-a-client> for client construction.
