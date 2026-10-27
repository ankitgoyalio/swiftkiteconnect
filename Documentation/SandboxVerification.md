# Authenticated sandbox verification

Issue [#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27) tracks remote evidence separately from fixture tests.
The opt-in `authenticated sandbox verification` test uses only the SDK's sandbox configuration and sandbox WebSocket origin. It never falls back to production.

Supply a private JSON file outside this repository with `access_token` and `user_id` from a sandbox session. The demo API key is fixed to `sandboxdemo`. Tokens must never be committed, logged or posted to GitHub. When running through an agent, use the private secret input rather than chat.

Run from the repository root with a complete Swift 6.4 toolchain (on macOS, select full Xcode rather than a mismatched Command Line Tools installation). Fish-compatible:

```fish
env KITE_SANDBOX_SESSION_FILE=/absolute/private/session.json swift test --filter 'authenticated sandbox verification'
```

This checks profile, margins, portfolio reads, public NSE instruments, quote/OHLC/LTP, order/trade lists, alert/MF availability, historical availability and receipt of each equity tick mode. Calls are sequential with one-second spacing. Each WebSocket check disconnects after 30 seconds. HTTP requests retain the SDK timeout and single-attempt policy.

For the explicitly authorized simulated order lifecycle, additionally set `KITE_SANDBOX_ORDER_CHECK=1`. It places at most one quantity-one HDFCBANK MIS BUY LIMIT order about 2% below fetched LTP, reads history/trades, and modifies/cancels only after observing OPEN. Placement is never retried. Rejected, filled, uncertain or missing state is reported as a failed/unqualified check. The order may fill in the simulator; this runner does not submit an exit trade. A missing receipt requires separate tag-based reconciliation before any further placement.

The sanitized report is written to ignored `.test-results/sandbox-verification.json`. It contains check names, outcomes, HTTP statuses and time; no tokens, user details, raw responses or order identifiers. API failures are not automatically classified as unsupported. Inspect them privately before recording a sandbox limitation. The test fails when a check fails; an empty successful collection establishes endpoint access, not populated-model coverage.

This is a first-pass runner, not complete qualification. Browser authorisation/Publisher, delivered postbacks, eligible position conversion, streaming order-update delivery, forced recovery and replacement with a different authenticated session need separate scenarios. Session-token exchange and renewal are not verified by importing an existing access token. GTT, calculation APIs and MARKET orders are documented sandbox exclusions and remain unverified. See the [official sandbox setup](https://kite.trade/docs/connect/v3/sandbox/).
