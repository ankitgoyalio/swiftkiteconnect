# Restore ticker subscriptions after transient failures

The ticker reconnects after transient failures using capped exponential backoff, then sends the current subscription set and modes. Subscription changes made during backoff apply on the next connection. Explicit close and definitive authentication or permission rejections end the stream.

Each ticker has one event iterator. A bounded buffer preserves the order of received events, including order updates. When the buffer fills, the ticker pauses reads until the consumer makes room.

The ticker emits connection-state events so callers can detect interruptions. Subscription restoration resumes live delivery. The caller owns reconciliation for the gap and can retrieve the order book to recover current order state.

[Zerodha WebSocket API](https://kite.trade/docs/connect/v3/websocket/) · [Zerodha orders API](https://kite.trade/docs/connect/v3/orders/) · [Rust ticker reference](https://github.com/zerodha/kiteconnect-rs/tree/1.0.1#ticker)
