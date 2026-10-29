# Official PHP SDK response fixtures

These 29 JSON responses are unmodified copies of
[`zerodha/phpkiteconnect` at `34107a327473c0ce0fac2bdad121afa2ee05f76b`](https://github.com/zerodha/phpkiteconnect/tree/34107a327473c0ce0fac2bdad121afa2ee05f76b/tests/mock_responses),
inspected 2026-10-28. Copyright belongs to Zerodha Technology. The upstream
[MIT license](LICENSE.md) applies and is reproduced in full. The
[manifest](manifest.json) records each upstream path and SHA-256 hash.
Fixture contents are upstream examples, not local credentials or broker results.

## Public compatibility cases

[OfficialSDKCompatibilityTests.swift](../../OfficialSDKCompatibilityTests.swift)
loads these resources through `Bundle.module`, injects a controlled HTTP transport
into public `KiteClient`, and asserts decoded values and the outgoing route.
No broker connection, credential acquisition, or trading request occurs.

| Files, without `.json` | Typed Swift API | Independent value checked |
| --- | --- | --- |
| profile | `profile()` | User ID |
| margins, margins_equity, margin_commodity | `margins()`, `margins(segment:)` | Net and available cash, including Decimal precision |
| orders, order_info | `orders()`, `orderHistory(orderID:)` | Order IDs |
| trades, order_trades | `trades()`, `orderTrades(orderID:)` | Fill prices |
| gtt_get_order, gtt_get_orders | `gttTrigger(id:)`, `gttTriggers()` | Trigger IDs |
| holdings, positions, auctions_list | `holdings()`, `positions()`, `auctionHoldings()` | Trading symbols and signed quantity |
| mf_orders, mf_orders_info, mf_sips, mf_holdings | Mutual-fund read APIs | Order ID, amount, instalment amount, fractional units |
| quote, ohlc, ltp | `quotes(instruments:)`, `ohlc(instruments:)`, `ltp(instruments:)` | Decimal prices |
| historical_minute, historical_oi | `historicalCandles(...)` | Volume and open interest |
| order_margins, basket_margins, virtual_contract_note | `orderMargins(_:)`, `basketMargins(_:)`, `orderCharges(_:)` | Total, span, transaction tax |
| alerts_get, alerts_get_one, alerts_history | `alerts(...)`, `alert(uuid:)`, `alertHistory(uuid:)` | Alert UUID |
| autoslice_response | `placeOrder(_:)` | Five outcomes, placed order ID, rejection code, type, and null details |

## Offline checks

Run `swift test --filter "official SDK"` for public-client compatibility.
Run `python3 -m unittest discover -s Tests/Documentation -p 'test_*.py'` for
manifest integrity, license retention, and documentation checks. SwiftPM may need
to resolve package dependencies on the first build. Routine fixture tests read
only the retained local files and do not download upstream responses.

For a provenance check, fetch a manifest entry's `upstreamPath` from the pinned
GitHub revision and compare its SHA-256 digest with the manifest. Preserve exact
bytes, the revision, and attribution when refreshing this set. A fixture alone
does not prove a callable PHP wrapper or remote operation availability.
