# Ticket #4 verification record

Executed **2026-10-27**, on macOS arm64 with Apple Swift **6.4**
(`swiftlang-6.4.0.34.1`) and Xcode **27.1 (27A9275)**.
This is evidence for the HTTP/profile foundation, not a release qualification.

| Check | Evidence / result |
| --- | --- |
| macOS public SDK protocol suite | 19 Swift Testing tests passed |
| macOS actual URLSession HTTP | Loopback profile, headers, redirect refusal, deadline and in-flight cancellation passed |
| iOS Simulator | 19 tests passed on iPhone 18 Pro, iOS 27.0; includes actual loopback HTTP |
| Additional simulator/script check | Earlier 17-test suite passed on iPhone Duo, iOS 27.1 using `Scripts/test-ios.sh` |
| Ubuntu 24.04 | CI configured with Swift 6.4.0; **not executed locally**, no Linux/container runtime available |
| GitHub Actions macOS/iOS/Ubuntu | Workflow configured; **not run on GitHub** because this implementation is not pushed |
| Documentation snapshot | 17 official HTML sources captured; manifest SHA-256 hashes verified against all files |
| Successful authenticated sandbox profile | **Not run**: no sandbox user credentials/access token; tracked by [#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27) |
| Production API / live trades | No requests made |
| Real WebSocket transport | Not selected or verified by this ticket; #18 owns validation |

Reproduce macOS tests with `swift test` and simulator tests with
`bash Scripts/test-ios.sh`. On this machine, use
`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` to select
full Xcode. The default Command Line Tools installation could not discover
Testing macros; the native build system also lacked the Testing module. Those
setup failures are not counted as functional red tests or passing checks.

The loopback tests start a real HTTP TCP listener inside the test process on a
random localhost port, and use the default URLSession transport. They run without
Python, credentials, internet access, a shared server, or market hours on each
platform. They verify the real request headers/path and typed response, plus
redirect refusal, configurable timeout and cancellation after receipt.

Public seam tests additionally verify session isolation/replacement, one attempt
on transport failure and rate limiting, unfamiliar error types, malformed and
extended responses, open server enums, local validation, repeated query/form/JSON
encoding, confirmed rejection versus uncertain mutation outcomes. Controlled
mutation routes are fixtures; no actual trading endpoint is exercised.

## Red-green evidence

The pre-agreed seams are `KiteClient` public operations against injected
`KiteHTTPTransport`, and the default adapter against controlled real HTTP. No
private helpers or actor internals are tested. Tests use Swift Testing.

1. Profile tracer test was written before the public client/module, but initial
   runs were blocked by the toolchain discovery issues above. This is not claimed
   as a verified functional red. The full-Xcode run passed after implementation.
2. `knownAndUnknownServerValuesRemainTyped` failed to compile against string
   arrays (`String` has no member `unknown`/`nse`/`cnc`). Added shared public open
   enums for exchanges, products and order types; the test then passed.
3. `malformedErrorEnvelopeRetainsAvailableKiteDetails` failed with
   `error.errorType → nil`, expected `FutureException`, when the message field was
   missing. Made error-envelope message optional to retain available details;
   the same public profile test passed, with HTTP message fallback.
4. `unrelatedTransportErrorCodeIsNotCancellation` failed because a non-URL error
   with code -999 became `CancellationError`. Restricted URL cancellation mapping
   to `NSURLErrorDomain`; the test passed while actual cancellation tests stayed
   green.

5. `typedSessionCredentialsConstructAnIsolatedClient` failed to compile before
   `KiteSessionCredentials` and the session initializer existed. Added the shared
   immutable credential contract and delegating client initializer; it passed.

[Captured excerpts](Evidence/ticket-4-tests.txt) preserve the functional failures
and final results. Full local logs are `/tmp/spec4-red2.log`,
`/tmp/spec4-red3.log`, `/tmp/spec4-red4.log`, `/tmp/spec4-red5.log`, `/tmp/spec4-final-macos.log` and
`/tmp/spec4-final19-ios.log`. The final simulator result bundle is
`/tmp/spec4-final19-ios.xcresult`; these temporary paths are local execution
artifacts, not portable CI results. Workflow artifacts will provide hosted
execution evidence once the branch is integrated/pushed and checks run.

CI intentionally fails if a runner lacks Swift 6.4/Xcode rather than silently
downgrading the package. Actual Ubuntu HTTP success remains a qualification gap
until its configured job passes. Successful simulated protocol calls cannot
substitute for that evidence, authenticated sandbox success, or WebSocket tests.
