# Unofficial Kite Connect Swift SDK design

The 24 interview decisions below are agreed individually and have been synthesized, at the user's request, into [specification issue #3](https://github.com/ankitgoyalio/swiftkiteconnect/issues/3), labeled `ready-for-agent`. A [local specification](sdk-spec.md) preserves the published content. The repository remains a Swift package scaffold; these documents describe intended behavior, not implemented capabilities.

## Scope and release contract

- **Q1:** Cover every documented Kite Connect v3 REST endpoint, WebSocket market data and order updates, and incoming postback validation helpers. Provide integration guidance for Publisher browser flows.
- **Q19:** Version 1.0 requires the complete agreed scope, a documentation-to-implementation checklist, automated protocol tests across supported platforms, and usage documentation. Clearly documented partial 0.x releases are allowed. Routine tests use fixtures and controlled transports; credentialed read-only smoke tests are optional, and live trading is not a test-suite requirement.
- **Q24:** Each release identifies its reviewed documentation snapshot and endpoint/capability checklist. Newly documented capabilities enter subsequent releases; known gaps remain visible. The interview's documentation research is not yet a completed endpoint audit.

The [Kite Connect v3 documentation](https://kite.trade/docs/connect/v3/) is the coverage authority. [Official SDKs](https://kite.trade/docs/connect/v3/sdks/) are implementation references, not a substitute for a documentation audit. This design does not establish that the current scaffold covers any endpoint.

## Platforms and package

- **Q2, Q4:** Support iOS 18+, macOS 15+, and Linux. Retain Swift 6.4 initially. Test macOS, iOS Simulator, and Ubuntu 24.04; defer tvOS, watchOS, and visionOS.
- **Q3, Q6:** Use native Swift design, typed requests and responses, `async throws` REST operations, typed `AsyncSequence` streaming, task-safe clients, and cancellation. Callback and Combine APIs are outside the first release.
- **Q17:** Expose one SwiftPM library/module named `KiteConnect`, with `KiteClient` for REST and `KiteTicker` for streaming. Shared models and postback helpers initially live in that module. Keep the repository name `swiftkiteconnect`.
- **Q18:** Allow maintained networking and SHA-256 dependencies behind replaceable transport interfaces. Validate actual Linux WebSocket operation in the supported environment before selecting its implementation.

## Authentication and request behavior

- **Q5:** Provide login-URL creation, token exchange, and authenticated requests. Applications own browser presentation, redirect handling, and credential storage. Secret-bearing exchange for distributed applications belongs on their backend; the SDK does not prescribe the application/backend protocol.
- **Q20:** Each client represents one API key/user session, with no global credentials or shared mutable session state. Separate users have separate clients. Credential replacement must prevent queued work and reconnect attempts from accidentally using the previous session.
- **Q7:** Never automatically resubmit trading mutations. Distinguish transport failures from confirmed API rejections and communicate uncertain outcomes when a request may have been accepted. Applications own reconciliation.
- **Q12:** Validate documented request structure locally; leave changing broker/exchange business rules to Kite.
- **Q13:** Send each REST request once, including reads. Expose rate-limit errors, support configurable timeouts, and leave scheduling to callers. Automatic REST retries and request queuing are deferred.
- **Q16:** Distinguish validation, transport, API, decoding, and streaming errors. Preserve HTTP status, Kite error type (including unfamiliar values), and message where available. Preserve recognizable cancellation and explicit uncertain mutation outcomes.

## Data models

- **Q8:** Use `Decimal` for public prices, monetary amounts, and financial rates, including decoded WebSocket prices. Use endpoint-appropriate numeric types for counts and quantities.
- **Q11:** Model known server values with typed cases while preserving unfamiliar values in an unknown case containing the original string. Ignore additional JSON fields; fail clearly on malformed or missing required fields.
- **Q14:** Distinguish exchange/trading-symbol instrument identity from numeric instrument tokens using separate Swift types. Persistent watchlists use exchange and trading symbol; requests use the identifiers required by Kite.
- **Q15:** Represent expiry as a date-only value and timestamp instants as `Date`. Interpret explicit offsets; use a configurable trading timezone, defaulting to `Asia/Kolkata`, for offsetless fields. This default is an SDK policy, not a claim of a documented timezone guarantee for every field. Do not inherit the device timezone implicitly.
- **Q23:** Download and parse instrument CSV into typed instruments. Applications own persistent caching, refresh scheduling, and retention of expired-contract mappings.

Domain vocabulary is defined in [GLOSSARY.md](../GLOSSARY.md).

## Streaming behavior

- **Q9:** Reconnect after transient failures with configurable, bounded exponential backoff, restoring subscriptions and modes. Notify callers of possible gaps; do not imply missed-event replay. Stop recovery on authentication failures until fresh credentials arrive. Applications reconcile missed order updates.
- **Q10:** Bound buffering and fail explicitly on overflow. Keep market-data and order-update buffering separate. A latest-quote-per-instrument policy is deferred.
- **Q21:** Each ticker explicitly connects and disconnects one WebSocket. Disconnect cancels reconnection and closes its event streams. Multiple connections require explicit ticker instances; subscriptions are not automatically distributed across connections.
- **Q22:** Broadcast subscribed events to independent subscribers with separate bounded buffers. Overflow fails the affected subscriber while others continue. Cancelling one subscriber does not implicitly disconnect the ticker; the affected caller resubscribes or reconnects and reconciles as appropriate.

## Implementation work remaining

The interview leaves dependency selection, exact method signatures, internal concurrency mechanisms, configurable buffer/backoff defaults, and the endpoint audit to implementation within these agreed contracts. In particular, Linux transport compatibility still requires empirical verification; it has not been established by this design session.

Supporting decisions and their trade-offs are recorded in [docs/adr](adr/). The user requested specification publication after the interview; no SDK implementation has begun.
