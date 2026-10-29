# Sandbox verification

Issue [#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27) tracks remote evidence separately from fixture tests.
The opt-in `authenticated sandbox verification` test uses only the SDK's sandbox configuration and sandbox WebSocket origin. It never falls back to production.

## Public smoke

CI runs the existing public NSE instrument test once on Ubuntu after the offline
suite. It uses the Swift SDK's sandbox configuration without credentials and
requires a nonempty catalogue with NSE exchange values. The step is nonblocking:
network, Cloudflare and sandbox outages are visible in the job summary and
`sandbox-public.txt` artifact, separately from deterministic qualification.

Run the same test locally:

```fish
env KITE_SANDBOX_INSTRUMENT_SMOKE=1 swift test --filter instrumentsPublicSandboxSmoke
```

Current results and authenticated-check outcomes are summarized in
[Verification](Verification.md); raw output belongs in CI artifacts or `.test-results/`.

## Authenticated checks

Supply a private JSON file outside this repository with `access_token` and `user_id` from a sandbox session. The demo API key is fixed to `sandboxdemo`. Tokens must never be committed, logged or posted to GitHub. When running through an agent, use the private secret input rather than chat.

Run from the repository root with a complete Swift 6.4 toolchain (on macOS, select full Xcode rather than a mismatched Command Line Tools installation). Fish-compatible:

```fish
env KITE_SANDBOX_SESSION_FILE=/absolute/private/session.json swift test --filter 'authenticated sandbox verification'
```

This checks profile, margins, portfolio reads, public NSE instruments, quote/OHLC/LTP, order/trade lists, alert/MF availability, historical availability and receipt of each equity tick mode. Calls are sequential with one-second spacing. Each WebSocket check disconnects after 30 seconds. HTTP requests retain the SDK timeout and single-attempt policy.

For the explicitly authorized simulated order lifecycle, additionally set `KITE_SANDBOX_ORDER_CHECK=1`. It places at most one quantity-one HDFCBANK MIS BUY LIMIT order about 2% below fetched LTP, reads history/trades, and modifies/cancels only after observing OPEN. Placement is never retried. Rejected, filled, uncertain or missing state is reported as a failed/unqualified check. The order may fill in the simulator; this runner does not submit an exit trade. A missing receipt requires separate tag-based reconciliation before any further placement.

The sanitized report is written to ignored `.test-results/sandbox-verification.json`. It contains check names, outcomes, HTTP statuses and time; no tokens, user details, raw responses or order identifiers. API failures are not automatically classified as unsupported. Inspect them privately before recording a sandbox limitation. The test fails when a check fails; an empty successful collection establishes endpoint access, not populated-model coverage.

Before placement, the runner creates a private attempt file beside the session file.
The file contains a unique tag and, after acknowledgement, the order identifier.
Files use mode `0600` from creation. An existing attempt file prevents another
placement, including after interruption before acknowledgement. Reconcile the tagged order
before starting another scenario. Keep attempt files private and outside Git.

## Exchange a browser request token

Save the callback's request token as `request_token` in a private JSON file outside
the repository. Set the file permissions to `0600`. Run only the exchange test:

```fish
env KITE_SANDBOX_EXCHANGE_FILE=/absolute/private/session.json swift test --filter 'sandbox SDK request token exchange'
```

The SDK exchanges the token once, replaces the file with private session fields,
and fetches the profile. The request token is short-lived and single-use.
An exchange failure requires inspecting its result before attempting another exchange.
Do not post a callback URL or token to GitHub or chat.

## Verify recovery and order updates

Run scenarios separately from the read checks:

```fish
env KITE_SANDBOX_SCENARIOS_FILE=/absolute/private/session.json swift test --filter 'sandbox remaining scenarios'
```

The recovery scenarios interrupt real authenticated sandbox sockets in each tick
mode. They require a gap notification, reconnection, and a new matching tick after
subscription restoration. Each scenario disconnects after at most 45 seconds.
The runner also checks holdings-authorisation initiation and position eligibility.

For credential replacement, additionally set `KITE_SANDBOX_REPLACEMENT_FILE` to
a different private authenticated session file. Two login callbacks can return
the same access token. That result leaves replacement untested.

To include one resting LIMIT lifecycle with streamed order observation, set
`KITE_SANDBOX_ORDER_CHECK=1`. The observer receives a real tick before placement
and waits at most 30 seconds for the matching cancellation notification. It records
message shapes without account or order values and reports decoder failures separately.
The observer disconnects after at most 60 seconds.

To run only that order scenario, set `KITE_SANDBOX_OBSERVED_ORDER_FILE` and filter
on `sandbox observed order lifecycle`. The same attempt-file protection applies.
`KITE_SANDBOX_ORDER_LEDGER` selects a different private attempt-file path only
after the previous attempt has been reconciled. Changing that path does not
authorize repeating an uncertain placement.

## Verify an eligible position

The position scenario creates one quantity-one HDFCBANK CNC BUY LIMIT about 2%
above LTP. A fill is intentional. The scenario requires no existing HDFCBANK
position, converts the filled position to MIS, and closes it with one SELL LIMIT
about 2% below fresh LTP. It verifies the resulting flat position.

```fish
env KITE_SANDBOX_POSITION_FILE=/absolute/private/session.json swift test --filter 'sandbox eligible position conversion'
```

Entry and exit each have a private attempt file. Neither placement is retried.
If an order stays OPEN for 30 seconds, the runner attempts cancellation once.
An uncertain conversion stops further mutations. Inspect orders and positions
before any later attempt. A failed cleanup can leave a simulated position open.

## Verify renewal and logout

Run these operations one at a time, after other scenarios:

```fish
env KITE_SANDBOX_RENEW_FILE=/absolute/private/session.json swift test --filter 'sandbox SDK session renewal'
env KITE_SANDBOX_LOGOUT_FILE=/absolute/private/session.json swift test --filter 'sandbox SDK session logout'
```

Renewal runs only when the session supplies a refresh token. The runner stores
the renewed token privately and fetches the profile. An HTTP error does not
establish refresh-token support. Logout requires a successful revocation response
and a server rejection when a new client tries the revoked token.

Find sanitized results in `.test-results/sandbox-*.json`. Routine tests leave all
remote scenarios disabled unless their corresponding file variable is set.

## Retain external qualification gaps

Browser holdings authorisation, Publisher, and delivered postbacks require
provider-supported sandbox configuration. The documented holdings browser URL and
Publisher form target production. Do not substitute those URLs for sandbox tests.
The shared demo app does not provide this runner with postback configuration.

GTT, calculation APIs, and MARKET orders are documented sandbox exclusions and
remain unverified. See the [official sandbox setup](https://kite.trade/docs/connect/v3/sandbox/)
and [current qualification](Verification.md).
