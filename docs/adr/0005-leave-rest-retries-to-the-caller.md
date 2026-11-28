# Leave REST retries to the caller

REST methods surface typed failures, including invalid or expired sessions, and leave retry decisions to the caller. For example, if order placement times out after Kite receives the request, the caller can reconcile against the order book before deciding whether to submit again.

[Kite errors](https://kite.trade/docs/connect/v3/exceptions/) · [Kite order API](https://kite.trade/docs/connect/v3/orders/)
