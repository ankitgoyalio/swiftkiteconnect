## Problem Statement

Swift developers need to integrate Zerodha's Kite Connect into Apple applications and Swift backends, but the official SDK list does not include Swift. They must otherwise build authentication, endpoint wrappers, request encoding, response models, instrument CSV parsing, binary market-data decoding, streaming recovery, and error handling themselves.

Developers need a Swift-native SDK whose documented coverage is verifiable, whose trading-request behavior is predictable, and whose Apple and Linux support is tested. Copying another language's SDK endpoint list is insufficient because its coverage can differ from the current Kite documentation.

## Solution

Build an unofficial SwiftPM library named `KiteConnect` for iOS 18+, macOS 15+, and Linux, retaining Swift 6.4 initially. Provide `KiteClient` for typed async REST operations and `KiteTicker` for typed asynchronous WebSocket events, with shared models and postback validation helpers.

Cover the complete Kite Connect v3 documentation snapshot selected for the release: all documented REST endpoints, WebSocket market data and order updates, incoming postback helpers, and guidance for browser-based Publisher integrations. Use the official documentation as the coverage authority and official SDKs as implementation references.

Version 1.0 requires complete agreed coverage, an endpoint/capability checklist, automated protocol tests across supported platforms, and usage documentation. Clearly documented partial 0.x releases are permitted. This specification synthesizes the 24 decisions agreed during the design interview; it does not claim the SDK is already implemented.

## User Stories

See the [58 user stories](sdk-spec-user-stories.md) covering the complete agreed scope.

## Implementation Decisions

- **Coverage authority:** Use the selected Kite Connect v3 documentation snapshot to audit every REST endpoint and non-REST capability in the agreed scope. Include authentication/user APIs, orders/trades, GTT, alerts, portfolio, quotes/instruments, historical data, mutual funds/SIPs, and margin/charge calculations. Official SDKs guide protocol handling and edge cases; their route tables do not establish completeness.
- **Package and platforms:** One SwiftPM product/module, `KiteConnect`, exposes `KiteClient`, `KiteTicker`, shared models, and postback helpers. Keep the repository name `swiftkiteconnect`. Support iOS 18+, macOS 15+, and Linux, with Swift 6.4 initially and Ubuntu 24.04 in the tested Linux matrix. Keep the core independent of UI frameworks.
- **Concurrency contract:** REST uses `async throws`; streaming uses typed `AsyncSequence` interfaces. Clients are safe to share across Swift tasks and support cancellation. Callback and Combine variants are deferred.
- **Authentication boundary:** Provide login-URL creation, token exchange, and authenticated API operations. Applications own browser presentation, redirect handling, credential storage, and their application/backend protocol. Secret-bearing exchange for distributed applications belongs on a backend.
- **Session isolation:** Each client represents one API key/user session without global credentials or shared mutable session state. Separate users require separate clients. Credential replacement must prevent queued work and reconnect attempts from accidentally using the previous session.
- **REST execution policy:** Send every REST request once, including reads; do not automatically retry or queue requests. Expose rate-limit errors and configurable timeouts. Distinguish uncertain mutation outcomes from confirmed API rejections; applications own scheduling, retries, and reconciliation.
- **Request validation:** Enforce documented structural requirements locally. Do not replicate changing broker/exchange rules such as current tradability or sufficient margin.
- **Response compatibility:** Expose known typed server values with an unknown case carrying the original string. Ignore extra JSON fields and clearly reject missing or malformed required data.
- **Financial models:** Use `Decimal` for prices, monetary amounts, and financial rates, including decoded WebSocket prices. Counts and quantities retain endpoint-appropriate numeric types.
- **Instrument identity:** Use separate Swift types for exchange/trading-symbol identity and instrument token. Persistent identities use exchange and trading symbol; subscriptions and historical requests use the identifier required by Kite. Download and parse instrument CSV; applications own persistent caching, refresh scheduling, and expired-contract retention.
- **Temporal models:** Use a date-only type for expiry and `Date` for timestamp instants. Honor explicit offsets. Interpret offsetless fields with a configurable trading timezone defaulting to `Asia/Kolkata`, never the device timezone implicitly. That default is an SDK policy, not an assertion that every offsetless field has an explicit documented timezone guarantee.
- **Errors:** Distinguish validation, transport, API, decoding, and streaming failures. Preserve HTTP status, Kite error type, and message where available, including unfamiliar error types. Cancellation remains recognizable; potentially accepted mutations have explicit uncertain outcomes.
- **Connection ownership:** Each ticker owns one WebSocket connection with explicit connect/disconnect. Disconnect cancels recovery and closes its event streams. Multiple connections require explicit ticker instances; no automatic subscription distribution or connection pool is included.
- **Recovery:** After transient failures, reconnect with configurable, bounded exponential backoff and restore subscriptions and modes. Notify callers of possible data gaps without implying replay. Authentication failures stop reconnecting until fresh credentials arrive. Applications reconcile missed order updates.
- **Event delivery:** Market-data and order-update streams have separate bounded buffering. Each independent subscriber gets its own copy of subscribed events and its own buffer. Overflow fails the affected subscriber explicitly while others continue. Cancelling a subscriber does not disconnect the ticker. The affected caller resubscribes or reconnects and reconciles as appropriate; no silent coalescing is included by default.
- **Postbacks and Publisher:** Provide incoming postback decoding/validation helpers without owning an HTTP server. Provide guidance for Publisher browser flows without implementing a browser plugin.
- **Transport and dependencies:** Allow maintained networking and cross-platform SHA-256 dependencies behind replaceable transport interfaces. Validate actual Linux WebSocket support in the supported environment before selecting the transport. Exact dependencies, internal concurrency mechanisms, method signatures, and configurable buffer/backoff defaults remain implementation choices within these contracts.
- **Release contract:** Require the full agreed scope, a reviewed documentation snapshot, an endpoint/capability checklist, automated supported-platform protocol tests, and usage documentation for 1.0. Allow clearly documented partial 0.x releases. New documentation capabilities enter subsequent releases and known gaps stay visible.

## Testing Decisions

- **Prior agreement:** Controlled transports, fixtures, replaceable networking interfaces, and supported-platform protocol tests were agreed during the interview. Carry that testing approach forward rather than opening another interview.
- **Highest practical seam:** Exercise the public `KiteConnect` library API, principally `KiteClient` and `KiteTicker`, against controlled HTTP/WebSocket transports. Treat transport injection as the shared boundary rather than creating test seams throughout endpoint wrappers, parsers, and internal state. Test public postback helpers through their public inputs and results.
- **Good tests:** Assert externally observable request encoding, returned models, errors, cancellation, event delivery, and connection behavior. Avoid assertions about private helpers, actor layout, internal collection choices, or implementation call order that is not part of a public contract.
- **Baseline when specified (2026-10-26):** The repository had a Swift Testing scaffold without an SDK implementation or transport seam. For the current implementation and test entry points, read the [development guide](development.md).
- **REST coverage:** Map each audited endpoint/capability to meaningful tests covering its method, route, authentication/version headers, documented parameter encoding, response decoding, and relevant failure behavior. Include non-JSON instrument responses, errors with unfamiliar server values, malformed required fields, and additional JSON fields.
- **Request and session behavior:** Verify one attempt per REST request, including transport failures and rate-limit responses; no automatic trading mutation resubmission; explicit uncertain outcomes; configurable timeouts; cancellation; structural validation; user-session isolation; and credential replacement preventing stale queued/recovery work from using the previous session accidentally.
- **Model behavior:** Verify decimal values are preserved, instrument identity is distinct from reusable tokens, expiry stays date-only, explicit offsets determine instants, offsetless fields use the configured trading timezone, and device timezone changes do not alter results.
- **Streaming protocol behavior:** Feed controlled binary and text messages through the public ticker interface, covering documented subscription modes, instrument/index layouts, multi-packet messages, heartbeats, order updates, and other documented messages. Verify malformed input yields defined observable behavior without crashes or silent corruption.
- **Streaming lifecycle and recovery:** Verify explicit connect/disconnect, bounded reconnect behavior, subscription/mode restoration, gap notification, authentication-stop behavior, credential replacement, and cancellation of recovery after disconnect. Control failures and time so these tests do not rely on market hours or nondeterministic sleeps.
- **Subscriber behavior:** Verify independent delivery to multiple subscribers; separate quote/order buffering; bounded overflow failing only the affected subscriber; independent cancellation; and disconnect closing streams. Include a slow consumer alongside a healthy consumer to exercise the actual isolation contract.
- **Postbacks:** Verify valid payload decoding and checksum acceptance, rejection of altered or invalid checksums, and preservation of documented order-update data through the public helpers.
- **Real transport evidence:** In addition to controlled protocol tests, verify the selected transport can actually establish HTTP/WebSocket communication in Ubuntu 24.04 and supported Apple environments using controlled local services. Mock transport success alone is not evidence that a deployed Linux WebSocket stack works.
- **Platform matrix and credentials:** Run automated checks on macOS, iOS Simulator, and Ubuntu 24.04. Routine tests require neither Kite credentials nor live trading. Optional credentialed smoke tests are read-only and are not a prerequisite for contributors to run the suite.
- **Completeness evidence:** Before 1.0, review the release's documentation snapshot against the endpoint/capability checklist and tests, and document usage plus all known gaps. This spec does not substitute for that audit or claim it is already complete.

## Out of Scope

- Official Zerodha endorsement or an official SDK designation.
- tvOS, watchOS, visionOS, and older iOS/macOS deployment targets in the first release.
- Callback or Combine APIs in the first release.
- Application login UI, browser ownership, redirect handling, credential persistence, an application-specific backend protocol, or a supplied authentication backend.
- Hosting a postback HTTP server or implementing a Publisher browser plugin; validation helpers and integration guidance remain in scope.
- Automatic REST retries, request queuing, hidden rate-limit scheduling, or trading mutation resubmission.
- Automatic reconciliation of uncertain mutations or missed order updates; applications own those decisions.
- WebSocket missed-event replay guarantees, automatic multi-connection subscription distribution, or a hidden connection pool.
- Unlimited event buffers, silent event loss, or a latest-quote-per-instrument coalescing policy in the first release.
- Persistent instrument databases, automatic background refresh, and SDK-owned retention of expired-contract mappings.
- Duplicating changing broker/exchange business rules locally.
- A zero-dependency requirement or a promise that untested Linux Foundation WebSocket configurations work.
- Requiring credentials or executing live trades as part of routine automated testing.
- A timeless claim of completeness against future documentation; coverage is release-snapshot specific.

## Further Notes

- The repository currently contains a SwiftPM scaffold, a greeting function, and an empty Swift Testing example. No endpoint implementation or actual Linux transport validation has been completed.
- The design interview established 24 decisions, recorded in the project's glossary, architecture decision records, and consolidated design summary. Use the established meanings of instrument, instrument token, trading symbol, postback, order update, and market-data tick consistently.
- The implementation must perform the detailed documentation audit and select validated dependencies. These are bounded implementation tasks, not permission to narrow the agreed 1.0 scope.
- A successful order-submission response must not be presented as proof of execution; callers inspect subsequent order state through the supported APIs and events.
- Primary references: [Kite Connect v3 documentation](https://kite.trade/docs/connect/v3/), [official SDK references](https://kite.trade/docs/connect/v3/sdks/), [authentication](https://kite.trade/docs/connect/v3/user/), [orders](https://kite.trade/docs/connect/v3/orders/), [instruments](https://kite.trade/docs/connect/v3/market-quotes/), [WebSocket protocol](https://kite.trade/docs/connect/v3/websocket/), [postbacks](https://kite.trade/docs/connect/v3/postbacks/), and [errors and rate limits](https://kite.trade/docs/connect/v3/exceptions/).
