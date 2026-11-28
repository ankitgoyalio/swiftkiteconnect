# Target iOS and macOS with Swift concurrency

The Swift package supports iOS 16 and later and macOS 13 and later. Its REST API uses typed requests and responses with `async throws`. Its ticker delivers typed events through an `AsyncSequence`. These interfaces let Apple app developers use the SDK from Swift tasks.

Use Foundation's `URLSession` for HTTP and `URLSessionWebSocketTask` for streaming. Both transports are available on the supported platforms and let the package use the system networking stack.

The first implementation milestone exercises an authenticated profile request, historical candle decoding, and ticker reconnection with subscription restoration. Together these cover authenticated HTTP requests, structured response decoding, and the WebSocket lifecycle.

Milestone verification uses the pinned Zerodha fixtures and a local WebSocket test server. Live read-only checks are optional. Zerodha has no sandbox, and historical data and WebSocket market data require an entitled account.

[Apple WebSocket API](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask) · [Zerodha API FAQ](https://support.zerodha.com/category/trading-and-markets/general-kite/kite-api/articles/kite-connect-api-faqs)
