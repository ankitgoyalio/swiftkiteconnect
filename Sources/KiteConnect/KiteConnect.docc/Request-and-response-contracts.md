# Request and response contracts

These contracts describe the partial 0.x SDK. They do not establish broker acceptance, execution guarantees, or remote qualification.

The [coverage record](https://github.com/ankitgoyalio/swiftkiteconnect/blob/main/Documentation/Coverage.md) maps the pinned protocol to APIs and tests. Start with <doc:First-request> for the introductory tutorial.

## Requests, errors, and sessions

REST performs one transport attempt. There is no automatic retry, rate-limit queue, batching, credential refresh, or reconciliation. ``KiteAPIError`` retains the HTTP status, raw server error type, message, and headers. Unfamiliar error types remain available to the caller.

A valid Kite rejection differs from an uncertain mutation outcome. Transport loss, non-Kite gateway responses, and malformed acknowledgements can follow server acceptance. Cancellation after dispatch does not prove rejection. An order tag is not an idempotency key. See <doc:Trading-mutation-outcomes> for reconciliation responsibilities.

Clients isolate credentials per actor. A late exchange, renewal, or invalidation cannot overwrite a newer explicit replacement. In-flight requests can finish with old credentials. Tickers own separate credentials and require explicit replacement. Refresh APIs require broker approval and are provisional SDK-reference additions. Applications own browser callbacks, credential storage, user interaction, and servers. See <doc:Authentication-ownership>.

## Financial values and response validation

Financial fields decode directly as `Decimal`. CSV numbers use strict grammar and reject values requiring more than 38 significant digits rather than silently rounding. Unknown response classifications retain their raw strings. Additional object fields are ignored. Missing, null, or malformed required fields fail the response without returning partial decoded data.

Optional model fields generally accept absence and null, but reject malformed present values. Specific acknowledgement schemas can be stricter. For example, ``KiteOrderMutationReceipt/children`` can be absent, but a present field must contain an array rather than null. Arbitrary metadata preserves JSON structure, including decimal numbers.

## Timestamps and dates

Full timestamps are `Date` instants. Explicit offsets override configuration. Offsetless timestamps use ``KiteConfiguration/tradingTimeZone``, which defaults to `Asia/Kolkata`, independently of the device time zone.

The timestamp parser accepts a space or `T` separator, `Z` or signed offsets, and up to nine fractional digits, subject to `Date` precision. Invalid dates, clocks, offsets, trailing text, and daylight-saving gaps fail. Ambiguous daylight-saving overlaps follow Foundation calendar resolution. Explicit offsets disambiguate those instants.

``KiteDateOnly`` retains a Gregorian calendar date without assigning a time or zone. Trade order timestamps containing only `HH:mm:ss` retain a ``KiteTradeOrderTimestamp/timeOfDay(hour:minute:second:)`` value rather than an invented date. Raw order timestamp text remains available for checksum verification.

## Catalogue and snapshots

Persistent instrument identity is exchange plus trading symbol. Numeric tokens can be reused after expiry. Applications own catalogue refresh, storage, and expired-token mappings. CSV readers support reordered columns, a byte-order mark, quoted commas and newlines, and escaped quotes. They enforce required unique columns and consistent row widths. The default URLSession transport decompresses HTTP content encoding.

Quote identities require no catalogue lookup. Repeated query values and input order are preserved. Requests are not deduplicated or batched. Full quotes accept 1 through 500 identities. OHLC and LTP snapshots accept 1 through 1000. Missing response map keys represent unavailable data. No zero snapshot is synthesized.

Depth arrays can be empty or variable length. Optional `open_interest` is distinct from required `oi` and never substitutes for it. See <doc:Request-quote-snapshots> and <doc:Discover-instruments>.

## Historical candles

Historical bounds require a positive token and finite, ordered dates. Equal bounds are allowed. Requests use whole-second text in the configured trading time zone. Continuous requests require daily intervals. Contract eligibility remains server-owned.

Candles have exactly six or seven positional values. Requested open interest must appear in every nonempty row. Unrequested supplied open interest is retained. Empty lists are valid. Null, negative, fractional, or overflowing volume or open interest fails decoding. Prices have no plausibility checks. Continuous futures history does not discover expired options tokens. See <doc:Request-historical-candles>.

## Orders and triggers

Request order and trade identifiers are opaque, nonempty safe path components. They need not be numeric. History retains server ordering. Daily order books and fills require application archival storage. Cancelled or rejected orders can have earlier partial fills. Empty history does not disprove an uncertain submission.

Integer quantities are validated without recomputing balances. Instrument tokens accept documented numeric and string forms when exactly representable as `UInt32`. Trade quantity accepts the documented `quantity` and `filled` spellings. Supplied `quantity` takes precedence, and each present value is validated. ``KiteOrderUpdate`` permits notification-specific optional fields. REST ``KiteOrder`` requires its stricter schema.

Mutation validation checks structure and supplied fields. Market hours, margin, lot sizes, tradability, and exchange eligibility remain broker policy. Modification does not require resending existing state. Cover-order second legs use `parentOrderID` in the modify body or cancellation query.

Autoslice accepts both array acknowledgements and object receipts with children, preserving mixed placed and rejected outcomes. Malformed or ambiguous receipts produce uncertainty without invented partial results. See <doc:Manage-orders>.

Single and two-leg OCO GTT trigger values associate with orders by array index. Receipt IDs must be positive. Unusable mutation IDs produce uncertain decoding outcomes because acceptance may already have occurred. A GTT acknowledgement does not prove execution. See <doc:Manage-GTT-triggers>.

Simple alerts and order-triggering baskets share lifecycle decoding. Unknown history metadata remains lossless JSON. Server limits and eligibility remain broker policy. See <doc:Manage-alerts>.

## Portfolio, calculations, and mutual funds

Positions retain signed quantities and supplied financial values. Exits use an opposite-side order with matching instrument and product. There is no synthetic exit endpoint or execution guarantee. Holdings authorisation remains a browser and depository workflow. Supplied ISIN and quantity pairs and exact callback recognition are validated. See <doc:Inspect-and-convert-portfolio> and <doc:Authorise-holding-sales>.

Calculation APIs do not place orders. Compact responses can contain totals alone. Full responses require their documented breakdown. Mixed basket STT and CTT totals are not authoritative per-order tax allocations. See <doc:Inspect-account-margins>.

Mutual-fund APIs cover the five documented read operations. There is no SIP-detail or mutation route. Date-only NAV and instalment values, fractional holdings, step-up data, unfamiliar statuses, and documented sentinel values are retained. A SIP success envelope without `status` is accepted as documented. See <doc:Read-mutual-fund-information> and <doc:Financial-values-and-portfolio-views>.

## Streaming and postbacks

Each ticker owns one physical WebSocket connection. Physical teardown, including late handshake cleanup, gates new admission. Transport write submission and its completion callback are admitted before event-loop shutdown. Close submission also completes before loop retirement. Transports must finish cancellation and close before subsequent connection admission proceeds.

Subscribers have independent bounded buffers. Subscriber overflow or cancellation removes that subscriber. Transport ingress overflow fails the connection. Binary and text messages are validated atomically. Malformed frames fail explicitly.

Recovery uses bounded backoff, restores desired tokens and modes, and emits possible gaps. Authentication failure stops recovery until credentials change. There is no missed-event replay or automatic order reconciliation. Applications allocate separate tickers rather than relying on a hidden connection pool. See <doc:Connect-and-consume-streams> and <doc:Streaming-recovery>.

Postback validation uses original timestamp text. The checksum binds order ID and timestamp plus the secret. It does not authenticate every payload field. Backends own HTTPS delivery, routing, deduplication, and reconciliation. A valid notification does not establish order execution. See <doc:Receive-HTTP-postbacks> and <doc:Postbacks-and-order-updates>.
