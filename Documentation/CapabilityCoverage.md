# Prose and streaming capability coverage

Companion to the [42-contract REST coverage matrix](Coverage.md), audited against
the same 2026-10-27 official documentation snapshot.

## Prose and non-REST capability audit

All 178 heading entries (including response/parameter subheadings) in the inventory
were reviewed as part of their page below. This table records the substantive
prose capabilities separately so a route-table match cannot hide a scope gap.
SDK policy choices are distinguished from server guarantees.

| Snapshot page / prose capability | Implementation and independent public evidence | Guidance / remaining qualification |
| --- | --- | --- |
| Introduction: account prerequisites, app registration, unofficial status | Package is one `KiteConnect` library; Swift 6.4, iOS 18+, macOS 15+ in Package.swift; no UI frameworks | README and Usage; app/account setup remains external; hosted Ubuntu HTTP/WebSocket tests passed; local trusted WSS passed on macOS and iOS Simulator; hosted Apple/Ubuntu passed; see Verification |
| User: login URL, redirect params, checksum exchange, signed requests, logout | `Authentication.swift`, `AuthenticationTests`; checksum literal and late-session fences, isolated clients | Usage authentication; approved refresh/revoke operations below exceed snapshot route scope; sandbox profile passed; SDK exchange/logout remain unverified #27 |
| Response structure: form/query/envelope, explicit JSON exceptions, IST timestamps | `KiteClient`, `HTTP`, CSV/model adapters; `ProfileTests`, `LocalHTTPTests`; injected transport returns decompressed bytes | Usage REST; margins explicitly use JSON per their page, CSV raw bytes; MF SIP missing-status example handled explicitly |
| Exceptions: raw exception names, HTTP codes, rate limits, expired session | `KiteAPIError`, single-attempt and cancellation tests across endpoint families; unfamiliar errors and 429 retained | App scheduling/relogin; no automatic REST retry or queue; limits are dated server policy, not hardcoded business eligibility |
| Orders: varieties, sides/products/types/validity, TTL, iceberg, auction, market protection, tags, auto-slice mixed results | `OrderMutationsTests`: all options and varieties, child parent IDs, mixed results, malformed receipt uncertainty; `OrdersTests`: interim states, tags/meta, partial fills, large quantities | Usage orders; receipt != execution; max ten auto-slices and other exchange limits remain broker-owned; all remote mutations unverified #27 |
| GTT: single/OCO forms, conditions/orders JSON, lifecycle statuses, nested execution | `GTTTests`: independent snapshot fixtures, one/two leg validation, Decimal prices, optional results, unknown enums, dates and errors | Usage and Contracts; no replay/resubmit; list covers active + previous-seven-day other states, detail is age-independent; snapshot typo documented above; sandbox excludes remote GTT #27 |
| Alerts: simple/ATO, operators, constant/instrument RHS, pagination/status/history, repeated deletion | `AlertsTests`, `ATOAlertsTests`: full wire forms and sparse basket responses, basket-only parameters, optional nested GTT, unknown metadata and year-one history timestamp | Usage and Contracts; 500 active alerts is broker policy; remote trigger/order execution unverified #27 |
| Portfolio: holdings/MTF, signed net/day positions, auctions, conversion | `PortfolioTests`, `PortfolioContractsTests`: independent official samples, precise money, product/identity, 162 required-field corruptions, cancellation and uncertain mutations | Usage portfolio; sandbox holdings/positions reads passed; conversion unverified #27; authorisations are trading-session scoped per the snapshot |
| Portfolio: opposite-side same-product exits, no exit endpoint | Ordinary `placeOrder`; compiled `submitPositionExit`, plus existing mutation wire tests | Usage explains LIMIT nonfill, matching identity/product and post-submit reconciliation; no synthetic exit API or live exit claim |
| Portfolio: authorisation, optional repeated ISIN/quantity, 428, browser finish, depository PIN | `authoriseHoldings`, `holdingsAuthorisationFlow`; portfolio public tests cover pairs, empty selection, exact URL recognition and unknown status | Usage and Publisher `authHoldings`; no documented sandbox browser origin, no remote completion #27 |
| Instruments: daily gzipped CSV, symbol/token distinction, reused tokens, date-only expiry | `InstrumentsTests`: quoted/escaped/multiline/BOM/reordered CSV, exact Decimal, date-only across zones, unknown fields/types; transport decompresses | App owns persistence, refresh and expired-token mappings; prior public sandbox NSE smoke succeeded; optional rerun recorded in Verification |
| Quotes: repeated `i`, 500/1000 limits, missing instruments, OHLC/depth/OI/timestamps | `QuoteSnapshotsTests`: supplied identities without catalogue, missing map entries, nullable values, malformed fields, exact Decimal and timezone policy | Usage; sandbox quotes/OHLC/LTP passed; see Verification |
| Historical: all eight intervals, granular range, continuous futures/day, optional OI, expired tokens | `HistoricalCandlesTests`: every interval, six/seven fields, configured/explicit time, Decimal, request validation and policy errors | Usage; continuous NFO/MCX uses live token; app retains expired mappings; sandbox day candles passed; broader remote variants unverified #27 |
| MF: last-seven-day/all-age order reads, active/paused SIPs, fractional holdings/NAV, independent CSV | `MutualFundsTests`: literal official JSON/CSV, -1 sentinels, date-only exchange/NAV/next-instalment, step-up, optional price, status-less SIP envelope | Usage and Contracts; no placement or dividend reinvestment per snapshot; sandbox MF orders/SIPs/holdings returned 504 and MF CSV returned 404; see Verification |
| Margins: full/compact, existing-position flag, spread totals/per-order charges, imaginary-order virtual note | `MarginCalculationsTests`: independent JSON bodies and tax/GST breakdowns, Decimal, compact-only shape, imaginary IDs, no order submission; aggregate mixed STT/CTT charges are not authoritative per-order tax totals | Usage and Contracts; calculations explicitly excluded from sandbox #27 |
| WebSocket: handshake params, three connections/key, 3000 tokens/connection, subscribe/unsubscribe/modes | `TickerTests`, `TickerBinaryTests`: public commands, sandbox `user_id`, limits and one explicit connection owner | Usage; app allocates separate tickers; no pool; sandbox LTP/quote/full ticks passed; see Verification |
| WebSocket: binary count/length framing, heartbeat, LTP/quote/full/index, 5+5 depth, scaling and epoch time | `TickerBinaryTests`, `TickerTests`: independent literal packet layouts, multipackets, malformed/truncated frames, signed index change, Decimal prices and currency/segment divisors | Usage; supplementary segment divisors are official-SDK references, not a broader prose completeness claim |
| WebSocket: text order/error/message and forward compatibility | `TickerTextTests`: shared order model, typed broker events, unknown JSON, malformed data and required fields | Usage; authentication-string recognition is narrow SDK policy, not a documented typed auth schema |
| Spec streaming policy: recovery, gaps, auth stop, session fencing, desired-state restore, bounded independent subscribers | `TickerRecoveryTests`: controlled time/handshake/write/physical-close gates; all five packet layouts plus text after recovery; `TickerTextTests`: quote/order overflow and cancellation isolation | Usage; no replay; app reconciles; adapter ingress overflow is a connection-level failure; Linux HTTP/WebSocket passed; hosted trusted-WSS matrix passed; see Verification |
| Postback: raw JSON, checksum, notifications vs execution, app scope vs user-wide WebSocket | `PostbacksTests`: known SHA-256, original UTF-8 timestamp, invalid/tampered input; `CrossChannelIntegrationTests`: REST/WS/postback agreement with unknown status, precise money and configured time | Usage; backend owns server, routing, deduplication/replay handling; checksum binds ID/timestamp, not every field; actual delivery unverified #27 |
| Offsite basket: user browser form POST, optional session, readonly, order parameters | `Publisher.md`, `Tests/Publisher.test.cjs`: preparation/callback checks, no network | Offsite callback terminology conflicts with canonical login; guide records it; no production fallback or remote browser completion #27 |
| Publisher: ready/static/custom/dynamic buttons, add/render/link, options/redirect, callbacks and authorisation | `Publisher.md`, offline JS tests: ten-entry limit, app ownership, callback validation | iOS WebView cookie restriction; prefer offsite; JS tag max eight differs from offsite max twenty; no Swift plugin implementation |
| Sandbox: login, /oms routing exceptions, user_id, supported snippets/exclusions | Config and family protocol tests independently assert sandbox paths; equity dumps bypass /oms, MF does not | Sandbox only for external API verification; GTT/calculations/MARKET unavailable; authenticated first-pass results recorded in Verification; remaining cases #27 |

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
GTT receipt uncertainty. See [Contracts](Contracts.md) for durable behavior and
[Verification](Verification.md) for executed checks and remaining qualification.
The package remains partial 0.x; #24 and parent #3 remain open.
