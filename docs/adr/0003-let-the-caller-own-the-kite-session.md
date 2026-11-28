# Let the caller own the Kite session

The SDK accepts a caller-supplied access token and provides an explicit request-token exchange helper for trusted environments. The caller owns browser login and token storage. A distributed app uses a trusted backend to hold the API secret and perform token exchange, following Zerodha's guidance.

[Kite user and session API](https://kite.trade/docs/connect/v3/user/) · [Zerodha mobile and desktop guidance](https://kite.trade/docs/connect/v3/apps/)
