# Initial release snapshot and coverage checklist

This partial 0.x snapshot was captured on **2026-10-27** from official Kite
Connect v3 documentation. The [manifest](Snapshots/2026-10-27/manifest.json)
records source URLs and SHA-256 hashes for archived HTML. These pages are the
coverage authority; SDK route tables are not a completeness claim.
`Scripts/snapshot-docs.py` captures a new copy for review (network required).
The checked-in bytes and hashes identify this snapshot even if upstream changes.

Only ticket #4 REST behavior is implemented here. Rows marked pending are visible
release gaps, not supported APIs. Generic request execution does not constitute
typed endpoint coverage. Publisher guidance comes from the independently merged
#23 slice. Final qualification and endpoint review remain #24.

| Documentation page | Method | Route | Ticket | Coverage / evidence |
| --- | --- | --- | --- | --- |
| [user](Snapshots/2026-10-27/user.html) | POST | `/session/token` | #5 | Pending typed API, protocol tests and usage |
| [user](Snapshots/2026-10-27/user.html) | GET | `/user/profile` | #4 | `KiteClient.profile()`; `ProfileTests.swift`, `LocalHTTPTests.swift`; README example |
| [user](Snapshots/2026-10-27/user.html) | GET | `/user/margins/:segment` | #6 | Pending typed API, protocol tests and usage |
| [user](Snapshots/2026-10-27/user.html) | DELETE | `/session/token` | #5 | Pending typed API, protocol tests and usage |
| [user](Snapshots/2026-10-27/user.html) | GET | `/user/margins` | #6 | Pending typed API, protocol tests and usage |
| [orders](Snapshots/2026-10-27/orders.html) | POST | `/orders/:variety` | #11 | Pending typed API, protocol tests and usage |
| [orders](Snapshots/2026-10-27/orders.html) | PUT | `/orders/:variety/:order_id` | #11 | Pending typed API, protocol tests and usage |
| [orders](Snapshots/2026-10-27/orders.html) | DELETE | `/orders/:variety/:order_id` | #11 | Pending typed API, protocol tests and usage |
| [orders](Snapshots/2026-10-27/orders.html) | GET | `/orders` | #10 | Pending typed API, protocol tests and usage |
| [orders](Snapshots/2026-10-27/orders.html) | GET | `/orders/:order_id` | #10 | Pending typed API, protocol tests and usage |
| [orders](Snapshots/2026-10-27/orders.html) | GET | `/trades` | #10 | Pending typed API, protocol tests and usage |
| [orders](Snapshots/2026-10-27/orders.html) | GET | `/orders/:order_id/trades` | #10 | Pending typed API, protocol tests and usage |
| [gtt](Snapshots/2026-10-27/gtt.html) | POST | `/gtt/triggers` | #12 | Pending typed API, protocol tests and usage |
| [gtt](Snapshots/2026-10-27/gtt.html) | GET | `/gtt/triggers` | #12 | Pending typed API, protocol tests and usage |
| [gtt](Snapshots/2026-10-27/gtt.html) | GET | `/gtt/triggers/:id` | #12 | Pending typed API, protocol tests and usage |
| [gtt](Snapshots/2026-10-27/gtt.html) | PUT | `/gtt/triggers/:id` | #12 | Pending typed API, protocol tests and usage |
| [gtt](Snapshots/2026-10-27/gtt.html) | DELETE | `/gtt/triggers/:id` | #12 | Pending typed API, protocol tests and usage |
| [alerts](Snapshots/2026-10-27/alerts.html) | POST | `/alerts` | #13, 14 | Pending typed API, protocol tests and usage |
| [alerts](Snapshots/2026-10-27/alerts.html) | GET | `/alerts` | #13, 14 | Pending typed API, protocol tests and usage |
| [alerts](Snapshots/2026-10-27/alerts.html) | GET | `/alerts/{uuid}` | #13, 14 | Pending typed API, protocol tests and usage |
| [alerts](Snapshots/2026-10-27/alerts.html) | PUT | `/alerts/{uuid}` | #13, 14 | Pending typed API, protocol tests and usage |
| [alerts](Snapshots/2026-10-27/alerts.html) | DELETE | `/alerts?uuid={uuid}` | #13, 14 | Pending typed API, protocol tests and usage |
| [alerts](Snapshots/2026-10-27/alerts.html) | GET | `/alerts/{uuid}/history` | #13, 14 | Pending typed API, protocol tests and usage |
| [portfolio](Snapshots/2026-10-27/portfolio.html) | GET | `/portfolio/holdings` | #15 | Pending typed API, protocol tests and usage |
| [portfolio](Snapshots/2026-10-27/portfolio.html) | GET | `/portfolio/positions` | #15 | Pending typed API, protocol tests and usage |
| [portfolio](Snapshots/2026-10-27/portfolio.html) | PUT | `/portfolio/positions` | #15 | Pending typed API, protocol tests and usage |
| [portfolio](Snapshots/2026-10-27/portfolio.html) | GET | `/portfolio/holdings/auctions` | #15 | Pending typed API, protocol tests and usage |
| [market-quotes](Snapshots/2026-10-27/market-quotes.html) | GET | `/instruments` | #7, 8 | Pending typed API, protocol tests and usage |
| [market-quotes](Snapshots/2026-10-27/market-quotes.html) | GET | `/instruments/:exchange` | #7, 8 | Pending typed API, protocol tests and usage |
| [market-quotes](Snapshots/2026-10-27/market-quotes.html) | GET | `/quote` | #7, 8 | Pending typed API, protocol tests and usage |
| [market-quotes](Snapshots/2026-10-27/market-quotes.html) | GET | `/quote/ohlc` | #7, 8 | Pending typed API, protocol tests and usage |
| [market-quotes](Snapshots/2026-10-27/market-quotes.html) | GET | `/quote/ltp` | #7, 8 | Pending typed API, protocol tests and usage |
| [historical](Snapshots/2026-10-27/historical.html) | GET | `/instruments/historical/:instrument_token/:interval` | #9 | Pending typed API, protocol tests and usage |
| [mutual-funds](Snapshots/2026-10-27/mutual-funds.html) | GET | `/mf/orders` | #17 | Pending typed API, protocol tests and usage |
| [mutual-funds](Snapshots/2026-10-27/mutual-funds.html) | GET | `/mf/orders/:order_id` | #17 | Pending typed API, protocol tests and usage |
| [mutual-funds](Snapshots/2026-10-27/mutual-funds.html) | GET | `/mf/sips/` | #17 | Pending typed API, protocol tests and usage |
| [mutual-funds](Snapshots/2026-10-27/mutual-funds.html) | GET | `/mf/holdings` | #17 | Pending typed API, protocol tests and usage |
| [mutual-funds](Snapshots/2026-10-27/mutual-funds.html) | GET | `/mf/instruments` | #17 | Pending typed API, protocol tests and usage |
| [margins](Snapshots/2026-10-27/margins.html) | POST | `/margins/orders` | #16 | Pending typed API, protocol tests and usage |
| [margins](Snapshots/2026-10-27/margins.html) | POST | `/margins/basket` | #16 | Pending typed API, protocol tests and usage |
| [margins](Snapshots/2026-10-27/margins.html) | POST | `/charges/orders` | #16 | Pending typed API, protocol tests and usage |

Supplementary capabilities require reviewing prose and examples as well as tables:

| Capability | Ticket | Status |
| --- | --- | --- |
| Login URL, backend SHA-256 exchange, session invalidation | #5 | Pending; local access-token replacement is available |
| Portfolio holdings authorisation POST and browser handoff | #15 | Pending; absent from portfolio summary table |
| Repeated alert deletion UUIDs, filtering/history, ATO baskets | #13, #14 | Pending |
| Order auto-slice/mixed outcomes, varieties, market protection, parent identifiers | #11 | Pending |
| Instrument CSV, distinct persistent identity/token, date-only expiry | #7 | Pending |
| Decimal financial fields; explicit/configured offsetless timestamps | #6–#22 | Pending where applicable; profile has no financial/date fields |
| LTP binary frames, independent bounded subscribers, real WebSocket transport | #18 | Pending transport selection and Apple/Ubuntu evidence |
| Quote/full/index modes and depth | #19 | Pending |
| Text order updates, broker messages, isolated order buffers | #20 | Pending |
| Recovery, possible gaps, authentication stop, credential replacement | #21 | Pending |
| Postback checksum validation and typed decoding | #22 | Pending |
| Publisher offsite/JS browser flows | #23 | [Guidance and offline tests](Publisher.md); no endpoint wrapper |
| Cross-platform complete capability audit | #24 | Pending; no 1.0 qualification claim |

Foundation coverage includes session isolation/replacement, headers, single
attempts, timeout propagation, cancellation, structural validation, open enum
values, additional fields, malformed data, form/JSON/repeated-query encoding,
HTTP/API/decoding/transport failures, and uncertain mutation outcomes. No trading
endpoint is implemented or submitted by these tests.

[Verification](Verification.md) distinguishes executed local Apple checks from
configured Ubuntu CI. Successful authenticated sandbox execution is excluded
without user credentials and tracked in
[verification issue #27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27).
Sandbox GTT/margin calculations and MARKET orders have documented exclusions.
All external API tests must remain sandbox-only. Local controlled success is
not proof that a sandbox endpoint or a production account works.
