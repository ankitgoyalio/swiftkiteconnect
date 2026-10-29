# Prose and streaming capability coverage

Companion to the [42-contract REST coverage matrix](Coverage.md), audited against
the same 2026-10-27 official documentation snapshot.

## Prose and non-REST capability audit

All 178 heading entries (including response/parameter subheadings) in the inventory
were reviewed as part of their page below. This table records the substantive
prose capabilities separately so a route-table match cannot hide a scope gap.
SDK policy choices are distinguished from server guarantees.
Dated execution results belong to [Verification](Verification.md);
[#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27) tracks pending work
and unmerged remote evidence. This matrix records contracts and controlled tests.

| Snapshot page / prose capability | Implementation and independent public evidence | Guidance / remaining qualification |
| --- | --- | --- |
| Introduction: account prerequisites, app registration, unofficial status | Package is one `KiteConnect` library; Swift 6.4, iOS 18+, macOS 15+ in Package.swift; no UI frameworks | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Create-a-client.md). Application registration remains external. |
| User: login URL, redirect params, checksum exchange, signed requests, logout | `Authentication.swift`, `AuthenticationTests`; checksum literal and late-session fences, isolated clients | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Authenticate-a-session.md). Refresh and revoke operations below exceed the snapshot route scope. |
| Response structure: form/query/envelope, explicit JSON exceptions, IST timestamps | `KiteClient`, `HTTP`, CSV/model adapters; `ProfileTests`, `LocalHTTPTests`; injected transport returns decompressed bytes | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Request-and-response-contracts.md). Margins use JSON; CSV responses contain raw bytes. MF SIP envelopes can omit status. |
| Exceptions: raw exception names, HTTP codes, rate limits, expired session | `KiteAPIError`, single-attempt and cancellation tests across endpoint families; unfamiliar errors and 429 retained | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Request-and-response-contracts.md). Applications own scheduling and login. REST requests have no automatic retry or queue. |
| Orders: varieties, sides/products/types/validity, TTL, iceberg, auction, market protection, tags, auto-slice mixed results | `OrderMutationsTests`: all options and varieties, child parent IDs, mixed results, malformed receipt uncertainty; `OrdersTests`: interim states, tags/meta, partial fills, large quantities | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Manage-orders.md). A receipt does not establish execution. Exchange limits remain broker-owned. |
| GTT: single/OCO forms, conditions/orders JSON, lifecycle statuses, nested execution | `GTTTests`: independent snapshot fixtures, one/two leg validation, Decimal prices, optional results, unknown enums, dates and errors | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Manage-GTT-triggers.md). No replay or resubmission. Lists cover active triggers and the previous seven days of other states; detail is age-independent. |
| Alerts: simple/ATO, operators, constant/instrument RHS, pagination/status/history, repeated deletion | `AlertsTests`, `ATOAlertsTests`: full wire forms and sparse basket responses, basket-only parameters, optional nested GTT, unknown metadata and year-one history timestamp | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Manage-alerts.md). The 500-active-alert limit is broker policy. |
| Portfolio: holdings/MTF, signed net/day positions, auctions, conversion | `PortfolioTests`, `PortfolioContractsTests`: independent official samples, precise money, product/identity, 162 required-field corruptions, cancellation and uncertain mutations | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Inspect-and-convert-portfolio.md). Authorisations are trading-session scoped. |
| Portfolio: opposite-side same-product exits, no exit endpoint | Ordinary `placeOrder`; compiled `submitPositionExit`, plus existing mutation wire tests | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Inspect-and-convert-portfolio.md). Exits use opposite-side orders with matching identity and product, followed by reconciliation. |
| Portfolio: authorisation, optional repeated ISIN/quantity, 428, browser finish, depository PIN | `authoriseHoldings`, `holdingsAuthorisationFlow`; portfolio public tests cover pairs, empty selection, exact URL recognition and unknown status | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Authorise-holding-sales.md). Browser and depository completion belong to the application. |
| Instruments: daily gzipped CSV, symbol/token distinction, reused tokens, date-only expiry | `InstrumentsTests`: quoted/escaped/multiline/BOM/reordered CSV, exact Decimal, date-only across zones, unknown fields/types; transport decompresses | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Discover-instruments.md). Applications own persistence, refresh, and expired-token mappings. |
| Quotes: repeated `i`, 500/1000 limits, missing instruments, OHLC/depth/OI/timestamps | `QuoteSnapshotsTests`: supplied identities without catalogue, missing map entries, nullable values, malformed fields, exact Decimal and timezone policy | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Request-quote-snapshots.md). Missing instruments can be absent from the response. |
| Historical: all eight intervals, granular range, continuous futures/day, optional OI, expired tokens | `HistoricalCandlesTests`: every interval, six/seven fields, configured/explicit time, Decimal, request validation and policy errors | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Request-historical-candles.md). Continuous NFO/MCX requests use a live token. Applications retain expired mappings. |
| MF: last-seven-day/all-age order reads, active/paused SIPs, fractional holdings/NAV, independent CSV | `MutualFundsTests`: literal official JSON/CSV, -1 sentinels, date-only exchange/NAV/next-instalment, step-up, optional price, status-less SIP envelope | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Read-mutual-fund-information.md). The snapshot excludes placement and dividend reinvestment. |
| Margins: full/compact, existing-position flag, spread totals/per-order charges, imaginary-order virtual note | `MarginCalculationsTests`: independent JSON bodies and tax/GST breakdowns, Decimal, compact-only shape, imaginary IDs, no order submission; aggregate mixed STT/CTT charges are not authoritative per-order tax totals | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Inspect-account-margins.md). Aggregate mixed STT/CTT charges are not authoritative per-order tax totals. |
| WebSocket: handshake params, three connections/key, 3000 tokens/connection, subscribe/unsubscribe/modes | `TickerTests`, `TickerBinaryTests`: public commands, sandbox `user_id`, limits and one explicit connection owner | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Connect-and-consume-streams.md). Applications allocate separate tickers; there is no connection pool. |
| WebSocket: binary count/length framing, heartbeat, LTP/quote/full/index, 5+5 depth, scaling and epoch time | `TickerBinaryTests`, `TickerTests`: independent literal packet layouts, multipackets, malformed/truncated frames, signed index change, Decimal prices and currency/segment divisors | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Connect-and-consume-streams.md). Supplementary segment divisors come from official SDK references. |
| WebSocket: text order/error/message and forward compatibility | `TickerTextTests`: shared order model, typed broker events, unknown JSON, malformed data and required fields | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Postbacks-and-order-updates.md). Authentication-string recognition is SDK policy, not a documented typed authentication schema. |
| Spec streaming policy: recovery, gaps, auth stop, session fencing, desired-state restore, bounded independent subscribers | `TickerRecoveryTests`: controlled time/handshake/write/physical-close gates; all five packet layouts plus text after recovery; `TickerTextTests`: quote/order overflow and cancellation isolation | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Streaming-recovery.md). There is no replay. Applications reconcile gaps; adapter ingress overflow fails the connection. |
| Postback: raw JSON, checksum, notifications vs execution, app scope vs user-wide WebSocket | `PostbacksTests`: known SHA-256, original UTF-8 timestamp, invalid/tampered input; `CrossChannelIntegrationTests`: REST/WS/postback agreement with unknown status, precise money and configured time | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Receive-HTTP-postbacks.md). The backend owns routing and deduplication. The checksum binds the ID and timestamp, not every field. |
| Offsite basket: user browser form POST, optional session, readonly, order parameters | `Publisher.md`, `Tests/Publisher.test.cjs`: preparation/callback checks, no network | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Prepare-a-Publisher-handoff.md). Offsite callback terminology differs from canonical login; the guide records the distinction. |
| Publisher: ready/static/custom/dynamic buttons, add/render/link, options/redirect, callbacks and authorisation | `Publisher.md`, offline JS tests: ten-entry limit, app ownership, callback validation | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Use-the-Publisher-plugin.md). iOS WebView cookie restrictions favor offsite integration. JS tags allow eight characters; offsite tags allow twenty. |
| Sandbox: login, /oms routing exceptions, user_id, supported snippets/exclusions | Config and family protocol tests independently assert sandbox paths; equity dumps bypass /oms, MF does not | [Task guide](../Sources/KiteConnect/KiteConnect.docc/Create-a-client.md). Use sandbox configuration for external API verification. Documented exclusions remain explicit in Verification. |

## SDK-reference additions and scope boundaries

`renewSession(refreshToken:apiSecret:)` POSTs `/session/refresh_token` and
`invalidateRefreshToken(_:)` DELETEs `/session/token` with refresh-token parameters.
They follow the [official Python SDK reference](https://github.com/zerodha/pykiteconnect/blob/master/kiteconnect/connect.py), with protocol tests
`renewalInstallsTokenUsingRefreshChecksumWithoutSendingSecret` and
`refreshInvalidationIsIndependentOfInstalledAccessToken`, and the compiled
`approvedPlatformRenewal` example. The selected user page mentions restricted
refresh permissions but does not specify these full wire contracts; these are
**additional provisional SDK-reference APIs**, not two newly discovered snapshot
endpoints or remote-qualified features.

No missing typed snapshot route was found in the audit. Controlled tests cover
physical WebSocket teardown admission, write/close completion fencing and invalid
GTT receipt uncertainty. See [request and response contracts](../Sources/KiteConnect/KiteConnect.docc/Request-and-response-contracts.md) for durable behavior and
[Verification](Verification.md) for executed checks and remaining qualification.
The package remains partial 0.x. Release and issue status belong to Verification.
