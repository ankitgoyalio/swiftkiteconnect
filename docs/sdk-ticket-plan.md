# Published tickets for the unofficial Kite Connect Swift SDK

Source: [specification #3](https://github.com/ankitgoyalio/swiftkiteconnect/issues/3).

Status: approved and published. Numbers in the breakdown are plan identifiers; the publication table maps them to GitHub issues. All 21 issues are native sub-issues of specification #3, labeled `ready-for-agent`, with verified native blocking relationships.

Each feature slice includes its public API, request/response or event models, required protocol handling, externally observable tests, a usage example, and entries in the release-snapshot coverage checklist. Apply the parent specification's decimal, time, unknown-value, cancellation, session-isolation, single-attempt REST, and structural-validation contracts wherever relevant. Use public SDK behavior through controlled transports as the test seam; add real transport checks where specified. No routine test requires Kite credentials or live trading.

There is no substantive existing implementation to prefactor. The package naming/platform adjustment and transport seam belong to the first working profile request rather than a separate setup-only ticket. Each endpoint family audits its documented routes/options against the selected snapshot before declaring its slice complete. Shared types should be reused as they emerge; conceptual similarity alone does not create a blocking edge.

## 1. Fetch a user profile through the cross-platform Swift client

**Blocked by:** None.

**Delivers:** A consumer can import `KiteConnect`, construct an isolated `KiteClient` with supplied session credentials, and retrieve a typed user profile on supported platforms.

**Acceptance:** Rename the starter library/module, declare agreed deployment targets, establish replaceable HTTP transport, and verify actual controlled-service HTTP operation on macOS, iOS Simulator, and Ubuntu 24.04. Exercise authentication/version headers, task-safe request behavior, one attempt per request, configurable timeout, cancellation, structured errors (including unfamiliar Kite error types), and malformed/extended responses through this real public operation. Establish the platform test matrix and initial documentation snapshot/checklist.

## 2. Complete login, token exchange, and session invalidation

**Blocked by:** 1.

**Delivers:** Applications can create a login URL, exchange a request token on a backend, replace credentials safely, and invalidate a session.

**Acceptance:** Verify documented exchange/checksum behavior on Apple and Linux, independent user sessions, credential replacement preventing stale queued requests from using old credentials accidentally, and public cancellation/errors. Document application-owned UI, redirects, storage, and secret-bearing backend exchange. Streaming credential replacement is completed with ticket 18.

## 3. Retrieve account funds and margins

**Blocked by:** 1.

**Delivers:** Consumers can retrieve all documented user funds/margin variants as typed financial data.

**Acceptance:** Cover documented segment selection and optional/required fields, decimal financial values, API failures, and forward-compatible decoding through public calls.

## 4. Download and parse the instrument catalogue

**Blocked by:** 1.

**Delivers:** Consumers can retrieve documented full/exchange instrument CSV data as typed instruments and distinguish persistent exchange/trading-symbol identities from numeric tokens.

**Acceptance:** Cover documented CSV columns, compression/transport behavior, expiry as a date-only value, decimal prices, malformed data, and identity/token distinction. Document application-owned caching, refresh schedules, and expired-contract mappings.

## 5. Retrieve quote, OHLC, and last-traded-price snapshots

**Blocked by:** 1.

**Delivers:** Consumers can request all documented snapshot quote variants for supplied exchange/trading-symbol identifiers.

**Acceptance:** Cover documented multi-instrument query encoding, typed results and missing entries as documented, decimal financial values, market-depth data where returned, and timestamp policy. Accept caller-supplied identities; downloading a catalogue is not a prerequisite.

## 6. Retrieve historical candles

**Blocked by:** 1.

**Delivers:** Consumers can retrieve typed candles using supplied tokens, intervals, date bounds, and every documented option.

**Acceptance:** Cover request-bound formatting, optional response fields, explicit timestamp offsets, configurable timezone behavior for offsetless fields, and decimal financial values. Document continuous/expired-contract constraints from the selected snapshot without adding SDK-owned token retention.

## 7. Inspect orders, order history, and trades

**Blocked by:** 1.

**Delivers:** Consumers can retrieve the order book, an order's history, all trades, and an order's trades.

**Acceptance:** Preserve unknown/interim statuses, nullable identifiers, documented financial/quantity fields, and timestamp semantics. Provide a reconciliation example distinguishing order submission from actual execution; no write API is required to inspect an externally supplied order ID.

## 8. Place, modify, and cancel trading orders

**Blocked by:** 1.

**Delivers:** Consumers can perform every documented trading-order mutation and represent successful, rejected, and uncertain outcomes correctly.

**Acceptance:** Audit and cover documented varieties/options, modification/cancellation semantics, parent/child identifiers, market protection, and auto-slice response shapes including mixed results. Validate structure, never retry mutations, and make possible acceptance after transport failure explicit. Demonstrate behavior using controlled transports rather than live trades. Caller-owned reconciliation remains in scope as guidance, not automated behavior.

## 9. Manage GTT triggers

**Blocked by:** 1.

**Delivers:** Consumers can create, retrieve, modify, and delete the documented GTT trigger variants.

**Acceptance:** Cover documented trigger/order structures, validation, request encoding, decimal values, status handling, and single-attempt uncertain mutation behavior. The server executes embedded orders; this slice does not require the standalone order-mutation client methods.

## 10. Manage simple alerts and their history

**Blocked by:** 1.

**Delivers:** Consumers can create, list, retrieve, modify, and delete simple alerts and inspect their history.

**Acceptance:** Cover documented operators/conditions, filters, single/bulk deletion, status/history models, decimal thresholds, timezone policy, and mutation error contracts. Establish reusable alert lifecycle interfaces/models for ticket 11.

## 11. Manage order-triggering alerts

**Blocked by:** 10.

**Delivers:** Consumers can create and manage documented ATO alerts through the existing alert lifecycle.

**Acceptance:** Extend the alert interfaces/models with documented basket structures and order parameters, structural validation, and encoding/decoding tests. Preserve unknown statuses and single-attempt uncertain mutation behavior. Reuse the alert lifecycle from ticket 10; standalone order placement is not a prerequisite.

## 12. Inspect and manage portfolio state

**Blocked by:** 1.

**Delivers:** Consumers can retrieve holdings, auction holdings, and positions; convert position products; and initiate documented holdings-authorisation flows.

**Acceptance:** Cover all portfolio endpoints/capabilities in the selected snapshot, including authorisation behavior even when omitted from a summary route table. Verify documented financial/quantity fields, timestamp policy, structural validation, and uncertain mutation outcomes. Keep authorisation browser presentation application-owned. Document exits as ordinary order operations rather than inventing a portfolio-exit endpoint; a combined exit example is part of final qualification once ticket 8 is available.

## 13. Calculate margins and charges

**Blocked by:** 1.

**Delivers:** Consumers can use every documented order/basket margin and charge-calculation operation with typed inputs and outputs.

**Acceptance:** Cover documented JSON/body shapes and options, per-order/aggregate results, decimal amounts/rates, and public error behavior. These calculations accept supplied order descriptions and do not require placing an order.

## 14. Retrieve mutual-fund orders, SIPs, holdings, and instruments

**Blocked by:** 1.

**Delivers:** Consumers can retrieve all documented mutual-fund data, including individual orders, SIP listings, holdings, and parsed instrument CSV.

**Acceptance:** Audit the snapshot's actual supported operations; do not copy obsolete mutation routes from another SDK. Cover mutual-fund-specific quantities, financial fields, date-only/timestamp fields, and CSV behavior through public calls. Reuse shared CSV/model utilities where available without requiring the equities catalogue API.

## 15. Stream last-traded-price ticks with explicit connection ownership

**Blocked by:** 1.

**Delivers:** Consumers can create a `KiteTicker` using supplied credentials, explicitly connect one WebSocket, subscribe/unsubscribe, receive typed LTP ticks, and disconnect.

**Acceptance:** Validate the chosen real WebSocket transport with controlled services on Apple and Ubuntu 24.04 before committing to it. Expose a replaceable WebSocket boundary, handle documented binary framing/multi-packet messages and heartbeats for this mode, and enforce task/session isolation. Support independent subscribers with bounded buffers, isolated overflow/cancellation, explicit disconnect closing streams, and no hidden connection pool. Reconnection and richer message types follow in later slices; partial coverage is explicit.

## 16. Stream quote/full modes, indices, and market depth

**Blocked by:** 15.

**Delivers:** Consumers can select all documented streaming modes and receive typed quote/full/index data including market depth where applicable.

**Acceptance:** Extend the public ticker with mode changes and all remaining documented binary layouts, packet lengths, price scales, timestamps, and financial precision. Verify mixed multi-packet frames, malformed input, forward compatibility where applicable, and independent subscriber behavior through controlled frames.

## 17. Stream order updates and broker messages independently of quotes

**Blocked by:** 15.

**Delivers:** Consumers can receive documented text order updates, broker messages, and server errors alongside market data.

**Acceptance:** Expose typed events with unknown statuses preserved and separate bounded order-update/market-data buffering. Verify quote saturation cannot consume order-update buffers; each subscriber receives its own events and only an overflowing subscriber fails. Handle malformed text messages explicitly. Supplied message fixtures make REST order reads and binary quote/full modes unnecessary prerequisites.

## 18. Recover streaming sessions without hiding gaps

**Blocked by:** 15.

**Delivers:** Consumers recover from transient connection failures with restored desired subscriptions/modes and explicit possible-gap notifications.

**Acceptance:** Implement configurable, bounded exponential backoff; stop on authentication failures until fresh credentials arrive; prevent old-session reconnect attempts from using replaced credentials; cancel recovery and close streams on explicit disconnect. Test recovery with controlled failures/time, including subscription changes during interruption. Never imply replay or perform automatic order reconciliation. Mode-specific and text-event integration checks accompany tickets 16/17 or final qualification; their decoding is not a prerequisite for implementing recovery.

## 19. Decode and validate incoming order postbacks

**Blocked by:** 1.

**Delivers:** A Swift backend can supply a postback payload to public helpers and receive validated, typed order-update data.

**Acceptance:** Verify documented SHA-256 checksum inputs on Apple and Linux, reject tampering/invalid checksums, preserve relevant timestamp text for validation, and decode required/optional/unknown values correctly. Do not start or supply an HTTP server. Use shared order data models where appropriate; WebSocket decoding is not a prerequisite.

## 20. Document Publisher browser integration

**Blocked by:** None.

**Delivers:** A consumer has a complete documented recipe for the Publisher browser flows within the agreed guidance-only scope.

**Acceptance:** Map the selected documentation snapshot's Publisher capabilities to integration guidance, examples, and application/browser ownership boundaries. Make the unofficial SDK's role explicit without adding a browser plugin, bundled UI, or undocumented SDK endpoint. This guidance does not require the Swift client to be implemented.

## 21. Qualify complete version 1.0 coverage and integrations

**Blocked by:** 2–9, 11–14, 16–20. Tickets 1, 10, and 15 are transitive prerequisites and need no additional blocking edge.

**Delivers:** Maintainers can demonstrate the complete agreed SDK against its reviewed Kite v3 documentation snapshot, with supported-platform evidence and usable integration guidance.

**Acceptance:** Verify every endpoint/capability maps to an implemented public API or the agreed guidance-only treatment, tests, and usage documentation. Record and resolve gaps before declaring 1.0 completeness. Run the full macOS/iOS Simulator/Ubuntu matrix and real HTTP/WebSocket checks. Verify combined binary/text streaming, recovery across supported modes, session changes, slow-subscriber isolation, and Decimal/time/unknown-value contracts across families. Complete examples for authentication boundaries, order reconciliation, portfolio exits, streaming, and postbacks. Document partial 0.x status as needed. Actual version tagging, release publication, and live trading are not required by this qualification ticket.

## Published issues

| Plan | GitHub issue | Blocked by |
| --- | --- | --- |
| 1 | [#4: Fetch a user profile through the cross-platform Swift client](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) | None |
| 2 | [#5: Complete login, token exchange, and session invalidation](https://github.com/ankitgoyalio/swiftkiteconnect/issues/5) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 3 | [#6: Retrieve account funds and margins](https://github.com/ankitgoyalio/swiftkiteconnect/issues/6) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 4 | [#7: Download and parse the instrument catalogue](https://github.com/ankitgoyalio/swiftkiteconnect/issues/7) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 5 | [#8: Retrieve quote, OHLC, and last-traded-price snapshots](https://github.com/ankitgoyalio/swiftkiteconnect/issues/8) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 6 | [#9: Retrieve historical candles](https://github.com/ankitgoyalio/swiftkiteconnect/issues/9) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 7 | [#10: Inspect orders, order history, and trades](https://github.com/ankitgoyalio/swiftkiteconnect/issues/10) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 8 | [#11: Place, modify, and cancel trading orders](https://github.com/ankitgoyalio/swiftkiteconnect/issues/11) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 9 | [#12: Manage GTT triggers](https://github.com/ankitgoyalio/swiftkiteconnect/issues/12) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 10 | [#13: Manage simple alerts and their history](https://github.com/ankitgoyalio/swiftkiteconnect/issues/13) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 11 | [#14: Manage order-triggering alerts](https://github.com/ankitgoyalio/swiftkiteconnect/issues/14) | [#13](https://github.com/ankitgoyalio/swiftkiteconnect/issues/13) |
| 12 | [#15: Inspect and manage portfolio state](https://github.com/ankitgoyalio/swiftkiteconnect/issues/15) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 13 | [#16: Calculate margins and charges](https://github.com/ankitgoyalio/swiftkiteconnect/issues/16) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 14 | [#17: Retrieve mutual-fund orders, SIPs, holdings, and instruments](https://github.com/ankitgoyalio/swiftkiteconnect/issues/17) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 15 | [#18: Stream last-traded-price ticks with explicit connection ownership](https://github.com/ankitgoyalio/swiftkiteconnect/issues/18) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 16 | [#19: Stream quote/full modes, indices, and market depth](https://github.com/ankitgoyalio/swiftkiteconnect/issues/19) | [#18](https://github.com/ankitgoyalio/swiftkiteconnect/issues/18) |
| 17 | [#20: Stream order updates and broker messages independently of quotes](https://github.com/ankitgoyalio/swiftkiteconnect/issues/20) | [#18](https://github.com/ankitgoyalio/swiftkiteconnect/issues/18) |
| 18 | [#21: Recover streaming sessions without hiding gaps](https://github.com/ankitgoyalio/swiftkiteconnect/issues/21) | [#18](https://github.com/ankitgoyalio/swiftkiteconnect/issues/18) |
| 19 | [#22: Decode and validate incoming order postbacks](https://github.com/ankitgoyalio/swiftkiteconnect/issues/22) | [#4](https://github.com/ankitgoyalio/swiftkiteconnect/issues/4) |
| 20 | [#23: Document Publisher browser integration](https://github.com/ankitgoyalio/swiftkiteconnect/issues/23) | None |
| 21 | [#24: Qualify complete version 1.0 coverage and integrations](https://github.com/ankitgoyalio/swiftkiteconnect/issues/24) | [#5](https://github.com/ankitgoyalio/swiftkiteconnect/issues/5), [#6](https://github.com/ankitgoyalio/swiftkiteconnect/issues/6), [#7](https://github.com/ankitgoyalio/swiftkiteconnect/issues/7), [#8](https://github.com/ankitgoyalio/swiftkiteconnect/issues/8), [#9](https://github.com/ankitgoyalio/swiftkiteconnect/issues/9), [#10](https://github.com/ankitgoyalio/swiftkiteconnect/issues/10), [#11](https://github.com/ankitgoyalio/swiftkiteconnect/issues/11), [#12](https://github.com/ankitgoyalio/swiftkiteconnect/issues/12), [#14](https://github.com/ankitgoyalio/swiftkiteconnect/issues/14), [#15](https://github.com/ankitgoyalio/swiftkiteconnect/issues/15), [#16](https://github.com/ankitgoyalio/swiftkiteconnect/issues/16), [#17](https://github.com/ankitgoyalio/swiftkiteconnect/issues/17), [#19](https://github.com/ankitgoyalio/swiftkiteconnect/issues/19), [#20](https://github.com/ankitgoyalio/swiftkiteconnect/issues/20), [#21](https://github.com/ankitgoyalio/swiftkiteconnect/issues/21), [#22](https://github.com/ankitgoyalio/swiftkiteconnect/issues/22), [#23](https://github.com/ankitgoyalio/swiftkiteconnect/issues/23) |

The parent specification’s body, labels, and open state were preserved. No SDK implementation was started during publication.
