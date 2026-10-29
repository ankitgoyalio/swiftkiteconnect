# Official SDK parity reference

Inspected 2026-10-28 for all eight official language SDKs linked from the
[Kite homepage](https://kite.trade/). Each row below pins the inspected revision.
The [42-contract matrix](Coverage.md) maps every documented REST contract to a
typed Swift operation, a named public-client protocol test, and compiled usage.
[Capability coverage](CapabilityCoverage.md) records prose and streaming behavior
separately. Query variants and prose capabilities do not increase endpoint counts.

## Evidence boundaries

A wrapper match means a public callable method constructs the documented HTTP
method and route. Generic request APIs, route constants without public call sites,
and fixtures without wrappers do not count. These are static source comparisons.
The official SDKs were not built or exercised against Kite for this comparison.

Controlled compatibility means an independent response fixture passes through
Swift's public `KiteClient` with an injected HTTP transport and observable value
and request assertions. It does not establish live-service availability.
[Verification](Verification.md) records platform qualification. Remote qualification
remains under [issue #27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27).
This reference makes no 1.0 qualification claim.

## Documented callable wrappers

All source pins and wrapper counts below use the 2026-10-28 inspection date.
A listed omission identifies every missing contract from the 42-contract matrix.
Every other row in that matrix has a native wrapper at the pinned revision.

| SDK | Matching documented wrappers | Documented wrapper omissions | Pinned source |
| --- | ---: | --- | --- |
| Swift (this repository) | 42/42 | None | [`dd9ff70527e94c9db4edd68cf6e61c4bc28673d2`](https://github.com/ankitgoyalio/swiftkiteconnect/tree/dd9ff70527e94c9db4edd68cf6e61c4bc28673d2) |
| Python | 35/42 | Alerts (6); holdings authorisation (1) | [2f67c46ead68](https://github.com/zerodha/pykiteconnect/blob/2f67c46ead6864425744abe5ec386979ee39c69f/kiteconnect/connect.py) |
| Go | 36/42 | Alerts (6) | [20bb18610cd9](https://github.com/zerodha/gokiteconnect/blob/20bb18610cd91f95e04de81472571d07b29d15ca/connect.go) |
| Java | 35/42 | Alerts (6); holdings authorisation (1) | [e9a148e1949a](https://github.com/zerodha/javakiteconnect/blob/e9a148e1949a17bd432e4c589185b72e03ec53ab/kiteconnect/src/com/zerodhatech/kiteconnect/Routes.java) |
| PHP | 34/42 | Alerts (6); holdings authorisation (1); basket margins (1) | [34107a327473](https://github.com/zerodha/phpkiteconnect/blob/34107a327473c0ce0fac2bdad121afa2ee05f76b/src/KiteConnect.php) |
| Node.js / TypeScript | 35/42 | Alerts (6); holdings authorisation (1) | [795128916c5e](https://github.com/zerodha/kiteconnectjs/blob/795128916c5e48118b781fe8535b58b872fdc45a/constants/index.ts) |
| .NET / C# | 35/42 | Alerts (6); holdings authorisation (1) | [bb842fe8a7b3](https://github.com/zerodha/dotnetkiteconnect/blob/bb842fe8a7b3d9f13bae72f87c20455c40b63d25/KiteConnect/Routes.cs) |
| Rust | 42/42 | None | [6b6b238596a1](https://github.com/zerodha/kiteconnect-rs/tree/6b6b238596a136e87029b57d5d5507f925e82fbe/src) |
| C++ | 33/42 | Alerts (6); holdings authorisation (1); auctions (1); order charges (1) | [d437b35300bf](https://github.com/zerodha/cppkiteconnect/blob/d437b35300bfd13f9de10632aeb19410720c8ad7/include/kitepp/kite.hpp) |

Source comparison covered the route declarations and their public call sites. The PHP repository includes newer alert fixtures but has no corresponding alert wrappers in the inspected client. A fixture alone is not a callable endpoint.

## SDK-only callable operations

The following 12 method/route contracts are exposed as callable methods by at least one inspected official SDK, but are outside the current documented REST checklist:

| Contracts | Official reference | Classification |
| --- | --- | --- |
| POST `/mf/orders`; DELETE `/mf/orders/:order_id`; POST `/mf/sips`; PUT and DELETE `/mf/sips/:sip_id` | [Python client](https://github.com/zerodha/pykiteconnect/blob/2f67c46ead6864425744abe5ec386979ee39c69f/kiteconnect/connect.py) and other SDKs | Five legacy mutation wrappers; current documentation explicitly excludes order placement. Do not infer that the other undocumented mutations work remotely. |
| GET `/mf/sips/:sip_id` | [Python client](https://github.com/zerodha/pykiteconnect/blob/2f67c46ead6864425744abe5ec386979ee39c69f/kiteconnect/connect.py) and other SDKs | SDK-only individual SIP retrieval; remote availability unqualified. |
| GET `/user/profile/full` | [Go user client](https://github.com/zerodha/gokiteconnect/blob/20bb18610cd91f95e04de81472571d07b29d15ca/user.go), Rust | SDK-only read; remote availability unqualified. |
| GET `/portfolio/holdings/summary`; GET `/portfolio/holdings/compact` | [Go portfolio client](https://github.com/zerodha/gokiteconnect/blob/20bb18610cd91f95e04de81472571d07b29d15ca/portfolio.go), Rust | Two SDK-only reads; remote availability unqualified. |
| GET `/mf/holdings/:isin`; GET `/mf/allotments` | [Go mutual-fund client](https://github.com/zerodha/gokiteconnect/blob/20bb18610cd91f95e04de81472571d07b29d15ca/mutualfunds.go), Rust | Two SDK-only reads; remote availability unqualified. |
| GET `/instruments/trigger_range/:transaction_type` | [Python client](https://github.com/zerodha/pykiteconnect/blob/2f67c46ead6864425744abe5ec386979ee39c69f/kiteconnect/connect.py), PHP | SDK-only trigger-range retrieval; remote availability unqualified. |

Unused entries such as `/parameters`, `/margins/:segment`, and older trigger-range spellings occur in some route maps. They are not proof of callable or supported service contracts. Swift already provides provisional refresh-token renewal and revocation, explicitly identified as official-SDK references rather than fully documented public contracts.

Current [mutual-fund documentation](https://kite.trade/docs/connect/v3/mutual-funds/) states that order placement cannot be performed through these APIs. Therefore adding every method from another SDK would conflict with the existing documentation-first boundary. Swift retains its documentation-first boundary.

## Other source categories

Swift's `renewSession(refreshToken:apiSecret:)` and
`invalidateRefreshToken(_:)` are supported provisional SDK-reference operations.
They are outside the 42 documented contracts. See the
[authentication source](../Sources/KiteConnect/Authentication.swift) and
[controlled authentication tests](../Tests/KiteConnectTests/AuthenticationTests.swift).
They do not establish parity for the SDK-only operations above.

Swift's `response(for:)` accepts `KiteRequest` as a generic request API. Other
SDKs also expose generic request helpers. Such escape hatches do not provide a
typed model or qualified wrapper for every arbitrary route they can construct.

## Reproduce the source comparison

The linked commits identify immutable source, rather than a moving branch or
release label. For each SDK, check out the full revision from its link in a
separate directory. Inspect route definitions and public call sites together.
For each of the 42 method/route rows in Coverage.md, trace a callable wrapper to
its HTTP method and constructed route. A route declaration alone does not pass.
Record omissions as set differences against that matrix. Inspect SDK-only public
methods separately, without adding them to the documented denominator.

Python uses `kiteconnect/connect.py`; Go splits methods across `connect.go`,
`user.go`, `orders.go`, `portfolio.go`, `mutualfunds.go`, `market.go`, and
`margins.go`. Java uses `Routes.java` and `KiteConnect.java` under
`kiteconnect/src/com/zerodhatech/kiteconnect/`. PHP uses `src/KiteConnect.php`.
Node.js uses `constants/index.ts` and `lib/connect.ts`. C# uses
`KiteConnect/Routes.cs` and `KiteConnect/Kite.cs`. Rust uses `src/`, and C++ uses
`include/kitepp/kite.hpp`. Search for the route strings when source organization
differs. Count callable wrappers, not declarations or generic HTTP helpers.

The current documentation and homepage can change. The selected 17-page
[documentation snapshot](Snapshots/2026-10-27/manifest.json) fixes the denominator.
`python3 Scripts/audit-snapshot.py` checks its hashes and route mappings.
Rechecking a new upstream revision requires a new inspection date and source pin.

## Retained independent responses

The [fixture manifest](../Tests/KiteConnectTests/Fixtures/OfficialPHP/manifest.json)
pins 29 unmodified JSON files from the official PHP SDK, their upstream paths,
and SHA-256 hashes. The adjacent [fixture reference](../Tests/KiteConnectTests/Fixtures/OfficialPHP/README.md)
records attribution, license, case mapping, and offline commands.
[Compatibility tests](../Tests/KiteConnectTests/OfficialSDKCompatibilityTests.swift)
assert typed values and outgoing routes through public APIs for account, orders,
trades, GTT, portfolio, mutual funds, market data, margins, charges, alerts, and
mixed auto-slice outcomes. This is a representative independent fixture set, not
independent fixture coverage of every contract or every response variant.

The [existing order-mutation tests](../Tests/KiteConnectTests/OrderMutationsTests.swift)
also cover ordinary receipts and parent receipts with mixed children.
The retained compatibility suite additionally adapts the pinned slice data into
parent receipts, empty parent children, and rejection-only arrays. Those locally authored protocol cases are
separate from upstream fixture provenance. Passing fixtures do not qualify
legacy mutual-fund mutations or any other SDK-only route remotely.
