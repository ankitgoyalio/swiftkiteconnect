# swiftkiteconnect

An unofficial Swift SDK for Kite Connect v3. **Partial 0.x; not a qualified 1.0
release.** The package implements the selected 2026-10-27 snapshot's 42 REST
method/route contracts, typed streaming, postback validation and Publisher guidance.
Authenticated sandbox evidence remains incomplete under #27.

Requires Swift 6.4, iOS 18+ or macOS 15+. The Ubuntu 24.04 CI suite has passed,
including real HTTP/WebSocket checks. Local trusted TLS/WSS now passes on macOS and iOS Simulator;
the new trust/fallback cases await the hosted platform matrix. No 1.0 or successful
authenticated broker integration is claimed.

Add this repository as a SwiftPM dependency and select the `KiteConnect` product.
The module is `KiteConnect`. A minimal sandbox read with an app-provided token:

```swift
import KiteConnect

func readProfile(accessToken: String) async throws -> KiteUserProfile {
  let client = try KiteClient(
    apiKey: "sandboxdemo", accessToken: accessToken, configuration: .sandbox)
  return try await client.profile()
}
```

`KiteClient` provides authentication/session operations, account margins,
instruments/quotes/history, order reads and mutations, GTT, simple/ATO alerts,
portfolio/authorisation, hypothetical margin/charge calculations and the five
snapshot mutual-fund reads. `KiteTicker` provides every documented binary layout,
text order/broker events, bounded independent subscribers and bounded recovery
with gap notifications. `KitePostbacks` decodes and validates incoming raw bodies.

Use a separate client per API key/user session. REST calls attempt once; no queue,
automatic retries or trading resubmission is included. A receipt is not a fill.
Reconcile uncertain mutations and missed stream updates before taking another
action. Applications own browser presentation, redirect handling, secret-bearing
backend token exchange, credentials, instrument persistence and reconciliation.
Defaults point to production; all project remote verification is sandbox-only.

Start with the [compiled usage guide](Documentation/Usage.md) for authentication,
REST, reconciliation, portfolio exits, streaming and postbacks. See the
[endpoint and prose audit](Documentation/Coverage.md),
[executed vs configured verification](Documentation/Verification.md), and
[Publisher browser guidance](Documentation/Publisher.md).

Routine checks require no account or remote API access:

```fish
swift test
python3 Scripts/audit-snapshot.py
python3 Scripts/check-documentation-examples.py
node --test Tests/Publisher.test.cjs
```

On this macOS host select full Xcode with
`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.
Run iOS with `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Scripts/test-ios.sh`.
[Verification](Documentation/Verification.md) provides the Ubuntu path and explicit
remaining credential-dependent cases in
[#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27).
