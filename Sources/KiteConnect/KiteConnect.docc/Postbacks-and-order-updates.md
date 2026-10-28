# Postbacks and order updates

An HTTP postback delivers an order update to your application's registered HTTP callback URL.

## Delivery channels

Kite sends a raw JSON HTTP POST body when an order's status changes. HTTP postbacks cover orders placed using the application's API key. Delivery can continue while the user is logged out. The application supplies the HTTP server. The SDK's ``KitePostbacks`` helpers decode and validate a received body without opening a listener or making a request.

A streamed order update arrives over the user's WebSocket connection and can include orders placed through other platforms. ``KiteOrderUpdateEvent`` contains delivery metadata and a ``KiteOrderUpdate``. Its checksum field is preserved, without backend-secret verification. An HTTP postback contains the same order-state model inside ``KitePostback`` after checksum validation.

A market-data tick is a streamed quote update for an instrument. ``KiteMarketTick`` describes market data, not an order's state or a trade execution. A notification that an order changed is not itself proof of execution.

## Checksum limits

``KitePostbacks/decode(_:apiSecret:tradingTimeZone:)`` compares the received checksum with the lowercase SHA-256 digest of the UTF-8 text `order_id + order_timestamp + api_secret`, without separators. The original timestamp text is used before any date formatting. Equivalent timestamp spellings produce different checksum inputs. Explicit offsets determine the instant. Offsetless timestamps use the supplied trading timezone, which defaults to `Asia/Kolkata`, never the device timezone.

The checksum binds the order ID and timestamp to the secret. It does not bind the remaining fields, including the user ID, app ID, status, quantities, or prices. Checksum success establishes neither freshness nor execution. The decoder checks required payload structure, but does not provide replay protection or establish that a notification belongs to the user and application your handler expects.

## Application responsibilities

The backend owns HTTPS ingress, secret storage, app and user routing, deduplication, processing, and reconciliation. Keep the API secret on that backend, outside publicly distributed applications. Select the expected secret using your server's configuration, rather than trusting an incoming app ID.

Deduplicate and reconcile by observed order state rather than delivery count. Neither postback decoding nor streaming automatically reconciles orders. Missed streaming events are not replayed. Use REST order history and trades when your application needs to reconcile state or establish fills.

These contracts describe the partial 0.x development SDK. Offline fixtures verify local decoding and validation. They do not qualify live callback delivery or live trading.

## See also

- <doc:Receive-HTTP-postbacks>
- ``KitePostback``
- ``KitePostbackError``
- ``KitePostbacks``

See <doc:Request-and-response-contracts> for the shared reference and <doc:First-request> for the introductory read-only tutorial.
