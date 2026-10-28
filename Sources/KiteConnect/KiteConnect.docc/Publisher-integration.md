# Publisher integration boundaries

Publisher hands a prepared basket to Kite for user review and confirmation in a browser.

This guidance describes the 2026-10-27 upstream snapshot for the unofficial, partial 0.x package. No Swift client is required for Publisher. The package supplies no Publisher endpoint wrapper, browser plugin, bundled UI, or HTTP server.

## Ownership

| Owner | Responsibility |
| --- | --- |
| Application | Basket preparation, browser presentation, navigation and callback handling, cancellation UI, credential storage, user and session isolation, and reconciliation. |
| Application backend | Secret-bearing token exchange, authenticated application sessions and access controls. |
| Kite and the user | Login, review and confirmation on Kite's order page, broker and exchange validation and execution. |
| Unofficial Swift SDK | Separate REST, streaming, and postback capabilities as implemented by the selected release. This guide supplies no Publisher endpoint wrapper, browser plugin, bundled UI or HTTP server. |

Treat browser completion as a navigation event. It does not prove every basket
entry was accepted, filled or executed atomically. Inspect orders and trades using
the application's authenticated integration before presenting final results.
Do not automatically resubmit after a timeout, closed browser or lost callback;
reconcile first. Closing the UI does not cancel an order already submitted.
These are application policies consistent with the SDK's single-attempt and
uncertain-outcome contracts.

## Browser and platform constraints

The official [mobile and desktop guide](https://kite.trade/docs/connect/v3/apps/)
describes registering a redirect URL, opening a browser view, watching navigation
for that exact redirect and extracting `request_token` and `status` before
closing the view. It mentions cookies and third-party cookies and a `127.0.0.1`
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

## Qualification limits

The official [sandbox reference](https://kite.trade/docs/connect/v3/sandbox/)
and [agent setup prompt](https://kite.trade/docs/connect/v3/agent-setup/sandbox-prompt.md)
cover sandbox authentication, `/oms` REST routing and LIMIT-only orders. They
do not document a Publisher basket endpoint or a sandbox plugin configuration.
Do not guess a sandbox basket URL or point the production plugin or form at a
real account to fill that gap. These Publisher examples execute only offline;
current authenticated REST and streaming results are recorded separately in
[verification evidence](https://github.com/ankitgoyalio/swiftkiteconnect/blob/main/Documentation/Verification.md). No Publisher order submission is qualified.

Publisher redirect success, cookies and popups, per-order results, holdings
approval, and iOS and macOS browser integration remain unverified end to end.
Track these exclusions in the integration verification issue before release
qualification. Any later remote verification must stay sandbox-only, obtain a
provider-supported Publisher test route first, and use authenticated sandbox
LIMIT orders only. Offline success does not establish sandbox feature support
or production readiness.

## Topics

### Prepare and handle a browser flow

- <doc:Prepare-a-Publisher-handoff>
- <doc:Handle-a-Publisher-return>
- <doc:Use-the-Publisher-plugin>

### Connect an authenticated Swift session

- <doc:Create-a-client>
- ``KiteClient/exchangeRequestToken(_:apiSecret:)``
- ``KiteClient/orders()``
- ``KiteClient/trades()``
