# Use the Publisher plugin

Prepare a basket with Zerodha's JavaScript plugin on a compatible website.

Use <doc:Prepare-a-Publisher-handoff> for the preferred offsite flow. The plugin fails in iOS WebViews because of iframe cookie restrictions.

## Prepare a user-clicked basket

The official [plugin guide](https://kite.trade/docs/connect/v3/publisher/)
recommends offsite execution and warns that the plugin fails in iOS WebViews
because of iframe cookie restrictions.

For compatible websites, load `https://kite.trade/publisher.js?v=3` once.
Static buttons use `<kite-button>` or an existing element with `data-kite`
(public key) and `data-exchange`, `data-tradingsymbol`,
`data-transaction_type`, `data-quantity`, `data-order_type` and applicable
`data-price` and other parameters. Dynamic usage is:

```javascript
KiteConnect.ready(function () {
  const publisher = new KiteConnect("YOUR_PUBLIC_API_KEY");
  publisher.add({ exchange: "NSE", tradingsymbol: "INFY", quantity: 1,
    transaction_type: "BUY", order_type: "LIMIT", price: 100 });
  publisher.finished(function (status, request_token) {
    // Application handles completion, optional session and reconciliation.
    // Never log request_token or infer fills from status.
  });
  publisher.link("#review-basket"); // Existing user-clicked element.
});
```

These JavaScript `KiteConnect` objects belong to Zerodha's plugin, not the Swift
module. Up to ten entries are documented. `get()` and `count()` inspect the basket;
`renderButton(selector)` supplies a branded button instead of `link(selector)`;
`html()` returns form markup for application submission. `setOption("redirect_url",
value)` supports `#`, a testing `127.0.0.1` URL, or a fully qualified URL in
the registered domain. `finished(callback)` reports completion.
The plugin documents alphanumeric tags up to eight characters; offsite lists
20. Use at most eight for shared baskets pending provider clarification.

## Hand off holdings authorisation

The plugin also exposes `authHoldings(request_id, callback)`. Obtain the request
ID through your separately implemented authenticated
[holdings authorisation flow](https://kite.trade/docs/connect/v3/portfolio/#holdings-authorisation),
then let Kite and CDSL own PIN entry. Alternatively present
`https://kite.zerodha.com/connect/portfolio/authorise/holdings/:api_key/:request_id`
in the application's browser UI and observe its matching `/finish` URL and
`status=success` or `error`. A callback is not a sell order or proof of a fill.
This guidance supplies neither an authorisation REST call nor automatic sell retries.

## Handle completion

Validate the return and reconcile through the initiating user's authenticated integration as described in <doc:Handle-a-Publisher-return>. See <doc:Publisher-integration> for platform and qualification limits.
