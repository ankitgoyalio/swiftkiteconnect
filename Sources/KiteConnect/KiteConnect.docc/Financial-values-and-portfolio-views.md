# Financial values and portfolio views

Understand why account funds, hypothetical margin estimates, holdings, and positions describe different parts of an account.

## Account funds and hypothetical requirements

``KiteSegmentMargins`` describes actual account funds and utilisation in one segment. Disabled equity and commodity segments remain in ``KiteAccountMargins``. The SDK preserves Kite's `net` amount instead of deriving it from component sums.

``KiteCalculatedMargin`` describes the estimated requirements of a hypothetical order. Basket estimates have initial and final aggregate margins and can consider existing positions. They do not reserve funds, place orders, or guarantee future eligibility. A compact estimate requires only `total`. An absent breakdown is unknown, not zero.

Mixed basket securities and commodities transaction taxes may be missing from aggregate charges. Per-order charge breakdowns retain the relevant tax information. Aggregate exchange and trading symbol fields can be empty, so a calculated margin's `instrument` can be nil.

## Holdings and position views

``KiteHolding`` represents long-term equity inventory with separate settled, unsettled, authorised, and collateral quantities. Those fields have distinct meanings and are not interchangeable sale quantities. Optional metadata remains nil when absent. Auction rows add a required auction number to the holding layout.

``KitePositions`` separates net exposure from current-day activity. Its `net` and `day` arrays can describe overlapping activity. A position's signed quantity distinguishes long, short, and flat exposure. Converting a product changes the margin treatment rather than closing the position. An exit uses a separate opposite-side order, whose execution the application must reconcile.

``KiteMutualFundHolding`` represents allotted fund units in demat, with fractional quantity and optional folio data. It is distinct from equity holdings and from an unfilled mutual-fund order. SIP records describe investment plans rather than proof of allotted units.

## Decimal values and dates

Prices, amounts, financial rates, and fractional fund units use `Decimal`. Counts and equity quantities use their endpoint-specific integer types. The SDK preserves financial values reported by Kite, including profit and loss, instead of recomputing them. Construct decimal literals from strings when an exact fractional value matters.

NAV dates, exchange dates in fund orders, and next-instalment dates use ``KiteDateOnly``. They describe calendar dates rather than instants. Order, creation, and last-instalment timestamps use `Date`. Explicit offsets determine the instant. Offsetless timestamp fields use the configured trading timezone, which defaults to `Asia/Kolkata`, independently of the device timezone.

Unfamiliar response classifications retain their original strings. Required malformed fields fail decoding, while additional server fields are ignored. This tolerance does not add new request capabilities.

## Related tasks

- <doc:Inspect-account-margins>
- <doc:Inspect-and-convert-portfolio>
- <doc:Authorise-holding-sales>
- <doc:Read-mutual-fund-information>
