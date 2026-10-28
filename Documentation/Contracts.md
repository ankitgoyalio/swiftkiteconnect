# API behavior and compatibility

[Usage](Usage.md) provides compiled examples; [Coverage](Coverage.md) maps the
pinned protocol to public APIs and tests. These contracts describe SDK behavior,
not broker acceptance, execution guarantees or remote qualification.

## Requests, errors and sessions

REST performs one transport attempt. There is no automatic retry, rate-limit queue,
batching, credential refresh or reconciliation. API error types remain open values.
A valid Kite rejection differs from an uncertain mutation outcome: transport loss,
non-Kite gateway responses and malformed acknowledgements may follow server
acceptance. Cancellation after dispatch does not prove rejection. Reconcile state
before another mutation; an order tag is not an idempotency key.

Clients isolate credentials per actor. A late exchange, renewal or invalidation
cannot overwrite a newer explicit replacement. In-flight requests can finish with
old credentials. Tickers own separate credentials and require explicit replacement.
Refresh APIs require broker approval and are provisional SDK-reference additions.
Applications own browser callbacks, credential storage, user interaction and servers.

## Financial values, timestamps and response validation

Financial fields decode directly as Decimal. CSV numbers use strict grammar and
reject values requiring more than 38 significant digits rather than silently round.
Unknown response enum values retain their raw strings. Extra object fields are
ignored; missing, null or malformed required fields fail the response. Optional
fields accept absence/null but reject malformed present values. Arbitrary metadata
preserves JSON values, including Decimal numbers. No partial decoded response is
returned after malformed required data.

Full timestamps are Date instants. Explicit offsets override configuration;
offsetless timestamps use configuration.tradingTimeZone (Asia/Kolkata by default),
not the device timezone. Space/T separators, Z and signed offsets, and up to nine
fractional digits are accepted, subject to Date precision. Invalid dates, clocks,
offsets, trailing text and DST gaps fail. Ambiguous DST overlaps follow Foundation
calendar resolution; explicit offsets disambiguate. KiteDateOnly retains calendar
dates. Trade order timestamps containing only HH:mm:ss retain a time-of-day enum
rather than an invented date. Raw order timestamp text remains available for checksums.

## Catalogue, snapshots and candles

Persistent instrument identity is exchange plus trading symbol; numeric tokens can
be reused after expiry. Applications own catalogue refresh, storage and expired-token
mappings. CSV readers support reordered columns, BOM, quoted commas/newlines and
escaped quotes, while enforcing required unique columns and consistent row widths.
The default URLSession transport decompresses HTTP Content-Encoding.

Quote identities require no catalogue lookup. Repeated input query values and order
are preserved; requests are not deduplicated or batched. Full quotes accept 1–500
identities, OHLC/LTP 1–1000. Missing response map keys represent unavailable data;
no zero snapshot is synthesized. Depth arrays can be empty or variable length.
Optional openInterest is distinct from oi and is never substituted for it.

Historical bounds require a positive token and finite ordered dates; equal bounds
are allowed. Requests use whole-second trading-timezone text. Continuous requests
require day intervals; contract eligibility is server-owned. Candles have exactly
six or seven positional values. Requested OI must be present in every nonempty row;
unrequested supplied OI is retained. Empty lists are valid. Null, negative,
fractional or overflowing volume/OI fails. Prices are not subject to plausibility
checks. Continuous futures history does not supply expired options-token discovery.

## Orders and triggers

Order/trade IDs are opaque nonempty safe path components, not numeric identifiers.
History retains server ordering. Daily order books and fills require application
archival storage. Cancelled/rejected orders may have earlier partial fills; inspect
trades and filled quantities. Empty history does not disprove an uncertain submission.
Integer quantities are validated without recomputing balances. Instrument tokens
accept documented numeric/string forms if exactly representable as UInt32. Trade
quantity accepts the documented quantity/filled spellings; supplied quantity takes
precedence and each present value is validated. Shared KiteOrderUpdate allows
notification-specific optional fields; REST KiteOrder enforces its stricter schema.

Mutation validation checks structure and supplied fields, not market hours, margin,
lot sizes, tradability or exchange eligibility. Modification does not require
resending existing state. Cover-order second legs use parentOrderID in the modify
body or cancellation query. Autoslice supports both the documented array and the
object/children acknowledgement shapes, preserving mixed placed/rejected outcomes.
Malformed/ambiguous receipts are uncertain, without invented partial results.

GTT single/OCO trigger values associate with orders by array index. Receipt IDs
must be positive; unusable mutation IDs are uncertain decoding outcomes because
server acceptance may already have occurred. GTT acknowledgement is not execution.
Simple alerts and order-triggering baskets share lifecycle decoding; unknown
history metadata remains lossless JSON. Server limits and eligibility remain
broker policy, not locally inferred business rules.

## Portfolio, calculations and mutual funds

Positions retain signed quantities and supplied financial values. Exits use an
opposite-side order with matching instrument/product; there is no synthetic exit
endpoint or execution guarantee. Holdings authorisation remains a browser/depository
workflow; supplied ISIN/quantity pairs and exact callback recognition are validated.

Calculation APIs do not place orders. Compact responses can contain totals alone;
full responses require their documented breakdown. Mixed basket STT/CTT totals
are not authoritative per-order tax allocations.

Mutual-fund APIs cover the five documented read operations only. No undocumented
SIP-detail or obsolete mutation route is supplied. Date-only NAV/instalment values,
fractional holdings, step-up data, unknown statuses and documented sentinel values
are retained. A status-less SIP success envelope is accepted as documented.

## Streaming and postbacks

Each ticker owns one physical WebSocket connection. Physical teardown, including
late handshake cleanup, gates new admission. Transport write submission and its
completion callback are admitted before event-loop shutdown; close submission
also completes before the loop is retired. Transports must finish cancellation
and close for subsequent connection admission to proceed.

Subscribers have independent bounded buffers. Subscriber overflow/cancellation
removes that subscriber; transport ingress overflow fails the connection. Binary
and text messages are validated atomically. Malformed frames fail explicitly.
Recovery uses bounded backoff, restores desired tokens/modes, emits gaps and stops
on authentication failure until credentials change. There is no missed-event replay
or automatic order reconciliation. Applications allocate separate tickers rather
than relying on a hidden connection pool.

Postback validation uses original timestamp text. The documented checksum binds
order ID and timestamp plus the secret; it does not authenticate every payload
field. Backends own HTTPS delivery, routing, deduplication and reconciliation.
A valid notification or subscription update does not establish order execution.
