# Verification and remaining qualification

This unofficial package is partial 0.x against the pinned 2026-10-27 snapshot.
No 1.0 qualification, production testing or release publication is claimed.
[Coverage](Coverage.md) and [CapabilityCoverage](CapabilityCoverage.md) describe
implemented scope; [Contracts](Contracts.md) describes behavior.

The [SDK parity reference](SDKParity.md) separates static wrapper coverage from
controlled compatibility. Its retained official response fixtures run through public
Swift APIs offline; their provenance and byte hashes are checked with the
documentation suite. They add no authenticated remote qualification.

## Automated platform checks

Hosted Apple (macOS and iOS Simulator) and Ubuntu checks passed on the pre-cleanup
source `4ffb6e4`; [PR #28 checks](https://github.com/ankitgoyalio/swiftkiteconnect/pull/28/checks)
are authoritative for the current revision. Local full suites at that revision
had 278 passed and two optional sandbox tests skipped on each Apple target,
with zero iOS runtime warnings. Test counts are historical observations, not a
fixed acceptance threshold. Inspect the current runner summary and CI artifacts.

Routine tests use fixtures, controlled transports and real loopback services.
They cover request/response contracts, Decimal/time semantics, cancellation,
session isolation, uncertain mutations, all five binary layouts, order/broker
events, buffering and recovery. Real HTTP/WebSocket tests exercise upgrades,
redirect refusal, fragments, close, timeout and ingress overflow. Trusted local
WSS tests verify DNS/IPv4/IPv6 certificates, chain and hostname validation, with
explicit per-transport trust roots. Missing/untrusted/malformed anchors fail closed.
No OS trust store is changed; fixture private keys are disposable public material.
Default URLSession local HTTPS success with a private CA is not separately asserted.

The snapshot audit verifies 17 exact upstream pages, 40 route-table entries plus
two prose routes, and all 42 API/test/example mappings. Nine Swift examples compile
with the tests; Publisher examples are checked offline.

Reproduce on macOS with full Xcode and Swift 6.4 selected (Fish-compatible):

```fish
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build --build-tests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Scripts/test-macos.py
env LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --skip-build --maximum-repetitions 10
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Scripts/test-ios.sh
python3 Scripts/check-documentation.py
python3 Scripts/audit-snapshot.py
python3 Scripts/check-documentation-examples.py
node --test Tests/Publisher.test.cjs
python3 -m unittest discover -s Tests/Hooks -p 'test_*.py'
```

On Ubuntu 24.04 with Swift 6.4, Python and Node, run `bash Scripts/test-ubuntu.sh`.
CI bounds macOS execution and retains process samples on hangs. CI uploads logs
and result bundles as artifacts; local output belongs in ignored `.test-results/`.
Historical raw logs, per-ticket reports and xcresult summaries are not source files.

## Executed sandbox checks

On 2026-10-28, the public SDK smoke parsed 48 NSE instruments and demo login
returned HTTP 200 after redirect. Python's default user-agent requests received
Cloudflare 403/1010. Public accessibility alone does not establish user access.
The public smoke runs separately as a nonblocking Ubuntu CI step with retained
outcome/log; it does not downgrade failures in deterministic qualification.

A user-provided request token was successfully exchanged via curl against the
sandbox session endpoint. This establishes sandbox session access, but does not
qualify the Swift SDK's token-exchange decoder. The existing authenticated SDK
runner executed at 2026-10-28 08:53 UTC:

- Passed (15): profile; combined/equity margins; holdings; positions; NSE instruments;
  quotes; OHLC; LTP; orders; trades; day historical data; LTP/quote/full WebSocket ticks.
- Failed (5): alerts and MF orders/SIPs/holdings returned HTTP 504; MF instruments
  returned HTTP 404. These are observed failures, not documented exclusions.
- No simulated orders or production calls were made. Successful empty collections
  establish access, not populated-model coverage or execution behavior.

The aggregate test correctly failed. Sanitized results and remaining work are
recorded in [#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27#issuecomment-6464744222).
Private session material stays outside the repository; future runs use
[SandboxVerification](SandboxVerification.md).

## Remaining qualification

Documentation publication requires the dedicated DNS record, account-level domain
verification, a GitHub Pages HTTPS certificate, and a successful deployment from
`main`. Repository automation and offline DocC validation do not establish a live
custom domain. Follow [Pages setup and verification](Pages.md) before claiming
hosted documentation success.

[#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27) remains open for
SDK session exchange/logout and approved renewal, simulated LIMIT lifecycle and
reconciliation, eligible position conversion, alerts/MF availability, browser
holdings authorisation/Publisher, delivered postbacks, streaming order events and
controlled remote recovery/credential replacement. A passed day-history request
does not qualify every interval, option or populated-data shape.

GTT, order/basket margin and charge calculations, and API MARKET placement are
documented sandbox exclusions and remain remotely unverified. There is no
production fallback. Local deterministic tests do not substitute for broker evidence.

Final qualification [#24](https://github.com/ankitgoyalio/swiftkiteconnect/issues/24)
and parent [#3](https://github.com/ankitgoyalio/swiftkiteconnect/issues/3) remain open.
Workflow authorization #29 is resolved; review/merge and release publication are
separate decisions. Implementation/review history belongs to issues and PRs rather
than duplicated status documents in the source tree.
