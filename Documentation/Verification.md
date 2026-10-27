# Verification — partial 0.x

Updated 2026-10-27. This is a **partial 0.x**, not a qualified 1.0 release.
Authenticated broker, browser and delivered-postback scenarios remain unverified
under [#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27). Sandbox
login/homepage requests returned 504 while the user observed 502; that is an
availability blocker, not proof that the service has not launched. No production
fallback is authorized.

Current local source (trusted TLS/fallback qualification changes) passes 276 tests
on each of macOS and iOS Simulator, with two opt-in sandbox tests skipped per target. Trusted local WSS now verifies a CA-signed DNS leaf, transmits LTP
through the public ticker, rejects a hostname mismatch and untrusted/malformed
roots, and accepts correctly certified IPv4 and IPv6 literal addresses. No OS trust-store changes or
certificate-verification bypasses are used. This also exercises the HTTPS upgrade
inside WSS; it does not establish a new local HTTPS-profile pass for the default
URLSession adapter. Its successful public sandbox HTTPS CSV read is listed below.

The new cases found and fixed two adapter bugs: failed IPv6 candidates prematurely
aborted IPv4 fallback, and literal IP addresses were incorrectly supplied as SNI.
[Partial 0.x qualification](Partial-0x.md) records evidence and remaining scope.
The new transport source awaits hosted macOS/iOS/Ubuntu confirmation.
Both hosted jobs passed on `ab9bc34` ([run 40493488881](https://github.com/ankitgoyalio/swiftkiteconnect/actions/runs/40493488881));
that prior platform pass does not qualify later transport changes. CI now uses
native Xcode 27.1 and pins iOS 27.0 / iPhone 17 after the image's iOS 27.1 simulator
failed before test startup. Workflow permission blocker #29 is resolved.

The historical review table below retains its original source-specific counts.

| Check | Executed result / boundary | Durable evidence |
| --- | --- | --- |
| Full macOS suite, final source, `TZ=Pacific/Honolulu` | 276 named tests: 275 passed, 1 opt-in sandbox test skipped, zero failures; no compiler warnings in final run | [macOS log](Evidence/review-macos.txt) |
| Full iOS Simulator suite | iPhone Duo / iOS 27.1 / arm64: 276 named tests, 275 passed, 1 skipped, zero failures/runtime warnings; result summary also counts 1333 passed parameter-expanded executions | [iOS summary](Evidence/review-ios-summary.json) |
| Real local HTTP | Passed as part of both suites: actual URLSession TCP requests, headers/path, redirect refusal, timeout, cancellation | `LocalHTTPTests.swift`, full suite above |
| Real local WebSocket | Passed as part of both suites: actual HTTP upgrade, masked writes, binary/text, fragment reassembly, peer close, 403 rejection, cancellation, timeout, bounded ingress overflow | `LocalWebSocketTests.swift`, full suite above |
| Local TLS | Passed on both Apple targets: real self-signed TLS peer rejected by default HTTP and WebSocket transports | `LocalTLSTests.swift`; fixture key is public test material only |
| Trusted local TLS / successful WSS | Passed on current macOS/iOS source with per-transport explicit roots; hostname/untrusted/malformed rejection and literal-IP success; hosted matrix pending | `TrustedWebSocketTests.swift`; [qualification](Partial-0x.md) |
| Combined streaming/recovery/session/subscriber behavior | Passed: all 8/28/32/44/184-byte layouts, text events after recovery, bounded backoff, credential fences, desired-state restore and isolated overflow/cancellation | `TickerRecoveryTests.swift`, `TickerTextTests.swift` |
| REST/WebSocket/postback consistency | Passed in Asia/Kolkata and UTC: unknown status, exact Decimal, matching order state/timestamps, replacement REST credential | `CrossChannelIntegrationTests.swift` |
| Public Swift examples | All nine README/Usage Swift blocks compile in the full suite; drift check passed | [compiled source](../Tests/KiteConnectTests/DocumentationExamples.swift), [checks](Evidence/review-checks.txt) |
| Publisher examples | 3 offline Node tests passed; no browser/remote submission | [checks](Evidence/review-checks.txt) |
| Snapshot integrity and mapping consistency | All 17 SHA-256 hashes and byte counts verified; independent 40 table rows + 2 prose routes, 178 headings; all 42 API/named-test/example mappings resolve | [inventory](Evidence/ticket-24-snapshot-inventory.json), [Coverage](Coverage.md) |
| Public sandbox equity instrument smoke | Separately executed opt-in test passed: 10,093 NSE records via default HTTP; no authenticated session | [sandbox log](Evidence/ticket-24-sandbox.txt) |
| Authenticated sandbox | **Not executed**: no user credentials/access token; remote endpoint, streaming and browser cases remain #27 | Residual list below |
| Ubuntu 24.04 | **Passed in hosted CI** on `d1e3fe6`: Swift 6.4, 275 tests passed, one skipped; real local HTTP/WebSocket and TLS rejection | [hosted evidence](Evidence/hosted-ubuntu.txt) |
| GitHub Actions | Both jobs passed on `ab9bc34`; new transport source awaits hosted confirmation | [workflow](../.github/workflows/protocol-tests.yml) |
| Strict Swift formatting / patch checks | Passed for changed Swift files and `git diff --check` | [checks](Evidence/review-checks.txt) |
| Production API / live trades | No requests made | Sandbox-only verification policy |

The historical Swift Testing terminal summary counts the skipped declaration in “276 tests.”
The iOS result summary separates 275 passed + 1 skipped and also reports expanded
parameter cases. Counts are not 276 passing tests. Initial local compilation and
format warnings in the new TLS/example test sources were corrected; final suites
and lint passed. The original #24 integration checks passed when introduced. The subsequent
final review identified two functional bugs; [Review](Review.md) records their
actual red-before-green public regressions and the two focused refactors.

## Reproduce on Apple

Run from the repository root with full Xcode selected (Fish-compatible commands):

```fish
env TZ=Pacific/Honolulu DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Scripts/test-ios.sh
python3 Scripts/audit-snapshot.py
python3 Scripts/check-documentation-examples.py
node --test Documentation/Publisher.test.cjs
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift format lint --strict Sources/KiteConnect/BoundedSubscribers.swift Sources/KiteConnect/CSV.swift Sources/KiteConnect/GTT.swift Sources/KiteConnect/Instruments.swift Sources/KiteConnect/KiteTicker.swift Sources/KiteConnect/MutualFundInstruments.swift Tests/KiteConnectTests/GTTTests.swift Tests/KiteConnectTests/TickerRecoveryTests.swift
git diff --check
```

The optional public read can be run separately, never as a substitute for
credentialed qualification:

```fish
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer KITE_SANDBOX_INSTRUMENT_SMOKE=1 swift test --filter instrumentsPublicSandboxSmoke
```

Final local iOS bundle: `.test-results/iOS.WkaArn/Results.xcresult` (uncommitted).
The durable JSON above is extracted with
`xcrun xcresulttool get test-results summary --path <bundle> --format json`.
Full transient logs: `/tmp/review-final-macos.log`, `/tmp/review-final-ios.log`.
The committed log/summary are the portable evidence; temporary bundles are not CI
artifacts. The initial #24 logs and summaries remain historical evidence; the post-review
bundle is the one reported here. Xcode emitted its AppIntents metadata-extraction
host warning (no AppIntents dependency); runtime warnings are empty.

## Reproduce on an existing Ubuntu 24.04 runtime

With Swift 6.4, Python 3 and Node installed, run:

```fish
bash Scripts/test-ubuntu.sh
```

[The script](../Scripts/test-ubuntu.sh) checks the real OS/compiler, validates
snapshot and documentation mappings, runs Publisher checks, then the complete
`swift test` suite including actual loopback HTTP/WebSocket/TLS rejection.
It provisions nothing. `bash Scripts/test-websocket-transport.sh` remains a
focused WebSocket diagnostic, not the full matrix. The CI Ubuntu job invokes the
full script and is configured to upload its log even on failure. Toolchain setup
failure is a failed/blocked job, never a downgraded or fabricated Swift 6.4 pass.

The original local qualification had no Linux runtime. Hosted execution has now
passed on Ubuntu 24.04.5 with Swift 6.4, including the actual network tests. The
new trusted TLS/WSS and fallback changes await hosted Linux confirmation.
Rejecting an untrusted peer is a separate check from successful negotiation.

## Remote residuals — #27

Keep these under [#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27),
without a production fallback:

- Login/exchange/logout, approved refresh permissions and authenticated profile/margins.
- Authenticated quotes/OHLC/LTP and historical data. Prior quote probes were
  Cloudflare-blocked, not verified endpoint behavior. Public equity CSV succeeded;
  it qualifies neither authenticated quote reads nor MF CSV.
- Order list/history/trades and sandbox LIMIT place/modify/cancel/reconciliation;
  no authenticated order or portfolio mutation was submitted for #24.
- Portfolio holdings/auctions/positions/conversion and authorisation browser completion.
- Simple/ATO alert lifecycle, triggers and any resulting order behavior.
- All five MF reads including authenticated CSV; sandbox docs do not prove availability.
- Real sandbox WSS authentication, binary/text events, recovery and session replacement;
  actual HTTP postback delivery and application deduplication/reconciliation.
- GTT, margin/basket/charge calculations and MARKET orders: explicitly unavailable
  in sandbox. They remain controlled protocol implementations, not remote-qualified
  capabilities. Do not use production to close those cases.
- Publisher and depository browser flows: documented origin has no specified sandbox
  counterpart; no remote navigation/completion was validated.

Fixture requests assert wire contracts, modeled values and error/lifecycle policy;
they do not demonstrate broker/exchange acceptance or account availability.

## Publication — #29 resolved

[#29](https://github.com/ankitgoyalio/swiftkiteconnect/issues/29) is closed: the
GitHub CLI credential now includes workflow scope and the complete integration
branch is published on [PR #28](https://github.com/ankitgoyalio/swiftkiteconnect/pull/28).
Earlier ticket evidence mentioning the publication block predates that approval.
The PR remains draft while qualification is incomplete.
