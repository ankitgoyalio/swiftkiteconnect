# Receive HTTP postbacks

Validate an incoming order notification in your application's backend HTTP handler.

1. Configure the application's callback URL in Kite Connect and supply an HTTPS handler in your server.
2. Read the raw JSON request body. Select the API secret from trusted backend configuration.
3. Pass the body and secret to ``KitePostbacks/decode(_:apiSecret:tradingTimeZone:)`` before processing the notification.

```swift
import Foundation
import KiteConnect

func decodeIncomingHTTPPostback(body: Data, backendSecret: String) throws -> KitePostback {
	try KitePostbacks.decode(body, apiSecret: backendSecret)
}
```

4. Handle ``KitePostbackError/invalidSecret`` as a backend configuration failure. Handle ``KitePostbackError/invalidChecksum`` as a failed checksum check. Reject malformed bodies that throw `DecodingError`. Choose HTTP responses and logging in your server without exposing the secret or full body.
5. Check the expected app and user route. Deduplicate notifications against stored order state and reconcile with REST order history and trades as needed.

The SDK supplies no HTTP server, response policy, replay protection, or automatic reconciliation. Read <doc:Postbacks-and-order-updates> before using checksum success to make a trust decision.

## Check the handler offline

Use this controlled body without a callback server or live credentials. It matches the existing postback test fixture, derived from the pinned upstream sample with a checksum for the synthetic secret `fixture-secret`.

```swift
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
```

Pass `offlineHTTPPostbackBody()` and `fixture-secret` to `decodeIncomingHTTPPostback`. The result has user ID `AB1234`, app ID `1234`, order ID `220303000308932`, status `.complete`, and average price `470`. Its original order timestamp is `2022-03-03 09:24:25`. With the default trading timezone, the decoded instant is `2022-03-03T03:54:25Z`.

An empty secret throws `.invalidSecret` before body decoding. A wrong secret throws `.invalidChecksum`. Changing the order ID or original timestamp without a matching checksum also fails. Changing another structurally valid field can still pass the checksum because that field is outside its inputs.

The repository's fixture-backed postback checks exercise these limits, malformed payloads, unknown values, decimal precision, and timezone handling. The article examples compile against the public SDK and run offline checks. No example places an order. Offline checks do not verify live delivery.

## See also

- <doc:Postbacks-and-order-updates>
- ``KitePostbacks``
- ``KitePostback``
- ``KitePostbackError``
