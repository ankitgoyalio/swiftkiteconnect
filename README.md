# swiftkiteconnect

An unofficial Swift SDK for Kite Connect v3. **Partial 0.x implementation; not a
complete SDK or a qualified 1.0 release.** Currently provides typed user profile
retrieval and reusable HTTP contracts. Requires Swift 6.4, iOS 18+, macOS 15+;
Ubuntu 24.04 checks are configured, with execution evidence still pending.

Add this repository as a Swift package dependency and select the `KiteConnect`
product. The module name is `KiteConnect`:

```swift
import KiteConnect

// Supply an access token from your application's authentication flow.
let client = try KiteClient(
    apiKey: "sandboxdemo",
    accessToken: accessToken,
    configuration: .sandbox
)
let profile = try await client.profile()
print(profile.userID, profile.userName)
```

Use a separate client for each API key/user session. Applications own login UI,
redirect handling, credential storage, and secret-bearing backend token exchange.
Token exchange and invalidation endpoint wrappers arrive in ticket #5.

`KiteConfiguration.sandbox` uses `https://sandbox.kite.trade/oms` for API routes.
Instrument dump requests explicitly bypass `/oms`. The default configuration
uses the production API; all remote verification for this project uses sandbox
only. No credentials are needed for the routine suite.

REST calls make one transport attempt, with no queue or automatic retry.
`KiteConfiguration(timeout:)` controls the request/resource deadline.
`replaceAccessToken(_:)` changes credentials for subsequent requests, and nil
clears them locally. Already dispatched requests may finish using their original
credentials. Await replacement before launching work that must use the new token.
Cancellation remains `CancellationError`. A cancellation after dispatch can still
leave a trading action accepted; applications must reconcile before resubmission.

Catch `KiteError.validation`, `.transport`, `.api`, `.decoding`, or
`.uncertainOutcome`. API errors preserve available HTTP status, server error type,
message and response headers, including rate-limit responses. Unknown server enum
values remain `.unknown(originalString)`.

`KiteSessionCredentials` also supports `KiteClient(session:configuration:transport:)`
when an application already holds the authenticated key/token pair.

For endpoint implementers, `execute(_:as:)` decodes Kite success envelopes and
`response(for:)` returns validated raw bytes. `KiteRequest` supports repeated
query parameters, form bodies, and JSON bodies. Trading mutations must set
`isTradingMutation: true`; failed transport, invalid success data, and responses
without confirmed Kite rejection then surface uncertain outcomes. A successful
submission is not evidence of execution. The injected `KiteHTTPTransport` contract
is the public testing boundary; custom transports must honor cancellation,
timeouts and one-attempt behavior. The default adapter refuses redirects.

Run `swift test` for protocol and real loopback HTTP tests. On Apple platforms,
select full Xcode if the active Command Line Tools installation cannot discover
Swift Testing. Run `bash Scripts/test-ios.sh` with an installed iOS Simulator.
See [verification evidence](Documentation/Verification.md), the
[release snapshot and coverage checklist](Documentation/Coverage.md), and
[Publisher browser guidance](Documentation/Publisher.md).
