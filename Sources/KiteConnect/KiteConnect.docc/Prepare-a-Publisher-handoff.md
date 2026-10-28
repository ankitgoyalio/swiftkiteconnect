# Prepare a Publisher handoff

Prepare an offsite basket form for the user's explicit review on Kite.

Use the offsite flow for iOS. See <doc:Publisher-integration> for application ownership and platform constraints.

## Prepare the form

The official [offsite guide](https://kite.trade/docs/connect/v3/basket/)
describes a user-side browser form POST to
`https://kite.zerodha.com/connect/basket` with `api_key` and a JSON array in
`data`. A backend may prepare the basket, but must not replace the browser
handoff with a server-side trading request. Prior API login is unnecessary;
Kite prompts for login when needed, presents the basket, then redirects back.

This offline example prepares the payload without submitting it. Its action is
intentionally an invalid domain. For an application deployment, configure the
official action above and your public API key, register your redirect URL in
the developer console, and let the user's explicit button click submit the
form. That official action is **production**, not a sandbox test target.
The price below is an illustrative integer, not a current quote or valid order
recommendation.

```html
<!doctype html>
<meta charset="utf-8">
<title>Review a prepared basket</title>
<form method="post" action="https://example.invalid/connect/basket">
  <input type="hidden" name="api_key" value="YOUR_PUBLIC_API_KEY">
  <input type="hidden" name="data" id="basket-data">
  <button type="submit">Review on Kite</button>
</form>
<script>
  const basket = [{
    exchange: "NSE", tradingsymbol: "INFY", transaction_type: "BUY",
    quantity: 1, order_type: "LIMIT", product: "CNC", price: 100,
    variety: "regular", readonly: false, tag: "demo23"
  }];
  document.getElementById("basket-data").value = JSON.stringify(basket);
</script>
```

Use a form's normal URL encoding; assign JSON to the input's `value`, avoiding
string concatenation into HTML. Do not double-encode the JSON. Keep secrets and
access tokens out of the form. See the official
[request parameters](https://kite.trade/docs/connect/v3/basket/#request-parameters)
for exchange and trading symbol identity, side, quantity, type, product, variety, validity,
price, trigger, disclosed quantity, tag and `readonly`. Kite remains the
business-rule authority. The plugin documents a ten-entry basket maximum;
keep shared application baskets within ten entries rather than assuming that
limit establishes a separate offsite protocol guarantee.

Application preparation should reject an empty basket, missing identities,
nonpositive integer quantities and absent required LIMIT and trigger prices. Use
`Decimal` for financial calculations on Swift and backend paths and serialize
locale-independent JSON numbers without converting through `Double`. The small
integer price here avoids implying JavaScript floating-point money arithmetic
is a suitable pricing implementation. `readonly` constrains Kite's review UI;
it is not tamper protection for client-generated payloads.

## Handle the return

Register the application's redirect URL before deployment. Validate the callback and reconcile the outcome as described in <doc:Handle-a-Publisher-return>. For compatible websites, <doc:Use-the-Publisher-plugin> describes the alternative JavaScript integration.
