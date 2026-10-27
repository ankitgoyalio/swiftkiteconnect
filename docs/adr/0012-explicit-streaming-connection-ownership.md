# Give each ticker explicit ownership of one connection

Each `KiteTicker` owns one WebSocket connection with explicit connect and disconnect operations. Disconnect cancels reconnection and closes its event streams; applications create multiple ticker instances when they need multiple connections.

The SDK will not automatically distribute subscriptions across connections. This keeps connection use and lifecycle under application control rather than introducing a hidden connection pool.
