# Streaming ownership and recovery

Each ticker owns one connection and bounded event delivery. Recovery restores subscriptions but cannot recover missed events.

## Explicit connection ownership

``KiteTicker`` opens one WebSocket through ``KiteWebSocketTransport``. Applications allocate additional tickers explicitly. There is no automatic connection pooling or distribution of subscriptions. The selected upstream snapshot permits three connections per API key and 3000 tokens per connection. The ticker enforces its token limit, but applications own the API-key-wide connection limit.

A new handshake waits for physical teardown of the preceding socket, including a late result from a cancelled handshake. Custom transports must honor cancellation and complete ``KiteWebSocketConnection/close()``. A transport that never settles holds subsequent connection admission.

``KiteTicker/disconnect()`` cancels recovery, clears desired subscriptions, and finishes all registered streams. Cancelling one subscriber removes that subscriber and leaves the connection and other subscribers running.

## Bounded recovery without replay

After a transient connection failure, the ticker emits ``KiteTickerLifecycleEvent/possibleDataGap``. ``KiteTickerReconnectPolicy`` bounds retries per interruption. Delay doubles from the initial delay up to the maximum delay. Zero attempts disables automatic retries. Recovery restores desired tokens and modes before emitting ``KiteTickerLifecycleEvent/reconnected``. Subscription changes made during recovery update that desired state.

The first ``KiteTicker/connect()`` call still throws its failure even if recovery starts. After ``KiteTickerLifecycleEvent/recoveryExhausted``, streams remain open and the ticker remains active. Applications can disconnect and explicitly start a new lifecycle. Repeated `connect()` calls while active fail with ``KiteTickerError/alreadyConnected``.

Handshake rejection with status 401 or 403 and recognized credential or session errors stop automatic recovery. ``KiteTickerLifecycleEvent/authenticationRequired`` requests application-owned authentication. ``KiteTicker/replaceCredentials(apiKey:accessToken:userID:)`` clears that block, closes the old socket, and reconnects if the ticker is active. Stale work cannot publish into the replacement session.

Malformed text, malformed binary framing, unsupported packet lengths, and invalid configuration end streams with an error rather than retrying indefinitely. Binary heartbeats produce no ticks. Binary messages and text payloads are validated before delivery.

## Independent bounded subscribers

Each call to a stream-registration method creates a separate bounded buffer. Subscribers receive their own copies of events in that event family. They do not compete for a shared iterator. Market-data ticks, order updates, broker notices, and lifecycle events use separate subscriber registries, so quote traffic cannot consume an order-update subscriber's capacity.

A nonpositive capacity throws during registration. When a buffer fills, the incoming event is dropped and the affected stream finishes with ``KiteTickerError/bufferOverflow``. Already buffered events can drain before the consumer observes the error. Other subscribers continue. Applications must register a replacement subscriber and reconcile any gap as appropriate.

``NIOKiteWebSocketTransport`` also has a separate bounded ingress buffer before ticker decoding. Its overflow fails the connection and can trigger recovery and a possible gap for all subscribers. Increasing a subscriber buffer does not change ingress capacity.

## Market-data ticks and order updates

``KiteMarketTick`` describes a quote update for an instrument token. Packet length determines whether ``KiteMarketTick/Details`` contains LTP, tradable quote or full fields, or index fields. ``KiteLTPTick`` is the last-price projection of every supported market-data layout. An instrument token can be reused after derivative expiry. Persistent instrument identity uses exchange and trading symbol.

``KiteOrderUpdateEvent`` describes an order's state through ``KiteOrderUpdate``. It is separate from a market-data tick. A postback delivers an order update to a registered HTTP callback URL. A streamed order update does not authenticate an HTTP postback, and its optional checksum is only preserved during decoding. ``KiteBrokerEvent`` carries informational messages, error strings, and unknown text-event types separately.

There is no missed-event replay and no automatic order reconciliation. After a possible gap, subscriber overflow, or reconnect, applications refresh market state and reconcile missed order updates with REST order history and trades. A notification alone does not establish execution. The task guide <doc:Connect-and-consume-streams> shows where to attach application handling. These contracts describe the development API and do not establish live trading qualification for the partial 0.x package.
