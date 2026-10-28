# Publisher browser integration

Audit date: **2026-10-27**. This is the Publisher guidance slice for spec #3,
ticket #23, against the official Kite Connect v3 pages linked below. It is a
dated coverage record, not a claim that the whole SDK is complete or that
Zerodha endorses this unofficial package. No Swift client is required to use
these browser flows.

## Ownership

| Owner | Responsibility |
| --- | --- |
| Application | Basket preparation, browser presentation, navigation/callback handling, cancellation UI, credential storage, user/session isolation and reconciliation. |
| Application backend | Secret-bearing token exchange, authenticated application sessions and access controls. |
| Kite and the user | Login, review and confirmation on Kite's order page, broker/exchange validation and execution. |
| Unofficial Swift SDK | Separate REST/streaming/postback capabilities as implemented by the selected release. This guide supplies no Publisher endpoint wrapper, browser plugin, bundled UI or HTTP server. |

Treat browser completion as a navigation event. It does not prove every basket
entry was accepted, filled or executed atomically. Inspect orders/trades using
the application's authenticated integration before presenting final results.
Do not automatically resubmit after a timeout, closed browser or lost callback;
reconcile first. Closing the UI does not cancel an order already submitted.
These are application policies consistent with the spec's single-attempt and
uncertain-outcome contracts.

## Offsite flow (preferred)

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
for exchange/symbol identity, side, quantity, type, product, variety, validity,
price, trigger, disclosed quantity, tag and `readonly`. Kite remains the
business-rule authority. The plugin documents a ten-entry basket maximum;
keep shared application baskets within ten entries rather than assuming that
limit establishes a separate offsite protocol guarantee.

Application preparation should reject an empty basket, missing identities,
nonpositive integer quantities and absent required LIMIT/trigger prices. Use
`Decimal` for financial calculations on Swift/backend paths and serialize
locale-independent JSON numbers without converting through `Double`. The small
integer price here avoids implying JavaScript floating-point money arithmetic
is a suitable pricing implementation. `readonly` constrains Kite's review UI;
it is not tamper protection for client-generated payloads.

## Redirect and optional session

The offsite page has inconsistent terminology: its note uses `redirect_url`
and `request_token`, while a later paragraph says `redirect_login` and
`request_key`. Follow the canonical [login contract](https://kite.trade/docs/connect/v3/user/#login-flow):
the registered redirect receives `request_token`. Do not invent a `request_key`
exchange parameter. Validate the actual callback during sandbox qualification.

Application callback handling must match the registered scheme, host, port and
path exactly, bind the attempt to the initiating application user, and reject
missing/duplicate token or status parameters. Preserve unfamiliar status text
as an unknown result; do not treat it as success. Ignore unrelated extra query
fields. The following pure JavaScript example illustrates URL validation only;
it does not exchange tokens or prove callback authenticity:

```javascript
function parsePublisherReturn(location, registeredRedirect) {
  let actual, expected;
  try {
    actual = new URL(location);
    expected = new URL(registeredRedirect);
  } catch { return null; }
  if (actual.origin !== expected.origin || actual.pathname !== expected.pathname ||
      actual.username || actual.password || actual.hash) return null;
  const tokens = actual.searchParams.getAll("request_token");
  const statuses = actual.searchParams.getAll("status");
  if (tokens.length !== 1 || !tokens[0] || statuses.length !== 1 || !statuses[0]) {
    return null;
  }
  return { requestToken: tokens[0], status: statuses[0] };
}
```

A browser token may be disregarded when no API session is needed. Otherwise,
send it promptly over the application's authenticated HTTPS channel to its
backend. The backend exchanges the one-time, short-lived `request_token` via
`POST /session/token`, with `api_key` and SHA-256 of
`api_key + request_token + api_secret`; see
[authentication](https://kite.trade/docs/connect/v3/user/#authentication-and-token-exchange).
Keep the secret on the backend and tokens out of logs, analytics and public
URLs after processing. The application owns storage and separate credentials
for each user. Never share a global mutable session between users. No new
session-exchange implementation or Swift method is promised by this guide.

## JavaScript plugin alternatives

The official [plugin guide](https://kite.trade/docs/connect/v3/publisher/)
recommends offsite execution and warns that the plugin fails in iOS WebViews
because of iframe cookie restrictions.

For compatible websites, load `https://kite.trade/publisher.js?v=3` once.
Static buttons use `<kite-button>` or an existing element with `data-kite`
(public key) and `data-exchange`, `data-tradingsymbol`,
`data-transaction_type`, `data-quantity`, `data-order_type` and applicable
`data-price`/other parameters. Dynamic usage is:

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
module. Up to ten entries are documented. `get()`/`count()` inspect the basket;
`renderButton(selector)` supplies a branded button instead of `link(selector)`;
`html()` returns form markup for application submission. `setOption("redirect_url",
value)` supports `#`, a testing `127.0.0.1` URL, or a fully qualified URL in
the registered domain. `finished(callback)` reports completion.
The plugin documents alphanumeric tags up to eight characters; offsite lists
20. Use at most eight for shared baskets pending provider clarification.

### Holdings authorisation boundary

The plugin also exposes `authHoldings(request_id, callback)`. Obtain the request
ID through your separately implemented authenticated
[holdings authorisation flow](https://kite.trade/docs/connect/v3/portfolio/#holdings-authorisation),
then let Kite/CDSL own PIN entry. Alternatively present
`https://kite.zerodha.com/connect/portfolio/authorise/holdings/:api_key/:request_id`
in the application's browser UI and observe its matching `/finish` URL and
`status=success` or `error`. A callback is not a sell order or proof of a fill.
This ticket adds neither the authorisation REST call nor automatic sell retries.

## Mobile and desktop handoff

The official [mobile/desktop guide](https://kite.trade/docs/connect/v3/apps/)
describes registering a redirect URL, opening a browser view, watching navigation
for that exact redirect and extracting `request_token` and `status` before
closing the view. It mentions cookies/third-party cookies and a `127.0.0.1`
callback for personal desktop apps. Its example's `status_from` wording is a
documentation inconsistency; the shown URL uses `status`.

On Apple platforms, the application chooses and implements the browser or
WebKit presentation and callback mechanism; this package does not supply one.
Use the offsite handoff for Publisher on iOS rather than the iframe plugin.
Test the chosen platform's cookie, redirect and dismissal behavior; do not
promise that enabling a setting bypasses iOS cookie restrictions. Distributed
apps must use a backend for secret-bearing exchange, as the official guide
requires. Route only an exact validated callback into the pending user's flow;
dismissal, denial or missing callbacks leave the outcome unresolved until
reconciled. Avoid persisting a user's pending basket across a different user's
login without explicit application handling.

## Snapshot coverage and validation

All entries below are **guidance coverage**, not new Swift SDK APIs or a 1.0
qualification claim. Source links identify the audited v3 snapshot as of
2026-10-27; revisit them for each release.

| Capability | Guidance in this file | Evidence / limitation |
| --- | --- | --- |
| Offsite basket form, login and return | Offsite flow; Redirect | Offline form preparation test; no remote submission. |
| Branded/custom HTML data buttons | JavaScript plugin alternatives | Official documentation audit; no browser execution. |
| Dynamic basket, readiness, inspection and rendering | JavaScript plugin alternatives | Controlled plugin boundary test; no remote assets. |
| Redirect override and finished callback | JavaScript plugin alternatives; Redirect | Pure callback parsing tests; no provider callback observed. |
| Holdings authorisation plugin/browser bridge | Holdings authorisation boundary | Official portfolio/plugin audit only; REST owned by separate capability. |
| Mobile/desktop cookies and redirects; iOS restriction | Mobile and desktop handoff | Official docs audit only; device behavior unverified. |
| Optional API session and application ownership | Ownership; Redirect | Authentication documentation audit; no credentialed exchange. |

Run focused, credential-free validation from the repository root:

```sh
node --test Tests/Publisher.test.cjs
```

The tests evaluate the examples using controlled DOM/plugin boundaries, without
loading external JavaScript, opening a browser or placing orders. They verify
payload serialization, initialization and callback parsing, not Kite execution,
cookie compatibility or SDK REST coverage. No dates/timestamps are transported
by these examples, so temporal SDK contracts have no new implementation here.

### Sandbox exclusions

The official [sandbox reference](https://kite.trade/docs/connect/v3/sandbox/)
and [agent setup prompt](https://kite.trade/docs/connect/v3/agent-setup/sandbox-prompt.md)
cover sandbox authentication, `/oms` REST routing and LIMIT-only orders. They
do not document a Publisher basket endpoint or a sandbox plugin configuration.
Do not guess a sandbox basket URL or point the production plugin/form at a
real account to fill that gap. These Publisher examples execute only offline;
current authenticated REST/streaming results are recorded separately in
[Verification](Verification.md). No Publisher order submission is qualified.

Publisher redirect success, cookies/popups, per-order results, holdings
approval, and iOS/macOS browser integration remain unverified end to end.
Track these exclusions in the integration verification issue before release
qualification. Any later remote verification must stay sandbox-only, obtain a
provider-supported Publisher test route first, and use authenticated sandbox
LIMIT orders only. Offline success does not establish sandbox feature support
or production readiness.
