# Benchmark Kite Connect v3 against the Rust SDK

Build the Kite Connect SDK as a standalone Swift package in the `swiftkiteconnect` repository. Its compatibility target is the documented Kite Connect v3 REST and WebSocket APIs, plus postback decoding and checksum verification. Publisher is a separate integration.

Use Zerodha's Rust SDK 1.0.1 (`fce212f`) as the primary implementation reference because it combines typed coverage of features such as Alerts and autoslice with tests for WebSocket decoding and subscription recovery. Use its pinned Zerodha fixtures to verify behavior and consult Go 4.4.3 when the public docs, fixtures, and Rust source leave a question open. The public API defines the scope, so the mutual-fund surface follows the five documented read operations.

[Kite Connect v3](https://kite.trade/docs/connect/v3/) · [Mutual funds](https://kite.trade/docs/connect/v3/mutual-funds/) · [Rust 1.0.1](https://github.com/zerodha/kiteconnect-rs/tree/1.0.1) · [Go 4.4.3](https://github.com/zerodha/gokiteconnect/tree/v4.4.3) · [Pinned fixtures](https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5)
