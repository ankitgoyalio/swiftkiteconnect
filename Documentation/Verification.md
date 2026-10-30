# Verification and remaining qualification

This unofficial package is partial 0.x against the pinned 2026-10-27 snapshot.
No 1.0 qualification, production testing or release publication is claimed.
[Coverage](Coverage.md) and [CapabilityCoverage](CapabilityCoverage.md) describe
implemented scope; the [request and response contracts](../Sources/KiteConnect/KiteConnect.docc/Request-and-response-contracts.md) describe behavior.

The [SDK parity reference](SDKParity.md) separates static wrapper coverage from
controlled compatibility. Its retained official response fixtures run through public
Swift APIs offline; their provenance and byte hashes are checked with the
documentation suite. They add no authenticated remote qualification.

## Automated platform checks

For 0.1.0 preparation, the 2026-10-29
[Protocol tests run](https://github.com/ankitgoyalio/swiftkiteconnect/actions/runs/40849402303)
passed the `apple` and `ubuntu` jobs at
`aca9ae13ba0c3e7ac2a444c9bf82e0bbfdd8b41a`. The run retains
[Apple test results](https://github.com/ankitgoyalio/swiftkiteconnect/actions/runs/40849402303/artifacts/12887595584),
[Ubuntu test results](https://github.com/ankitgoyalio/swiftkiteconnect/actions/runs/40849402303/artifacts/12886138722),
and the [DocC artifact](https://github.com/ankitgoyalio/swiftkiteconnect/actions/runs/40849402303/artifacts/12885923326).
The workflow uses Swift 6.4, Ubuntu 24.04, Xcode 27.1, and the iOS 27.0
simulator. These results establish routine platform checks for that revision.
They do not qualify macOS 15 or iOS 18, or a later release candidate.

Hosted Apple (macOS and iOS Simulator) and Ubuntu checks passed on the pre-cleanup
source `4ffb6e4`; [PR #28 checks](https://github.com/ankitgoyalio/swiftkiteconnect/pull/28/checks)
record that historical branch. Local full suites at that revision
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
two prose routes, and all 42 API/test/example mappings. Catalog examples compile
with the tests; `Scripts/check-documentation-examples.py` reports their current count.
Publisher examples are checked offline.

Reproduce checks with the [development guide](../docs/development.md#run-checks).
CI retains logs, result bundles, and process samples on hangs. These artifacts
identify the tested revision; historical counts above are not current thresholds.

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

## Reproducible follow-up scenarios

The runner now includes SDK token exchange, renewal and logout, remote recovery
in each tick mode, distinct-session replacement, observed LIMIT lifecycles, and
eligible position conversion and exit. [SandboxVerification](SandboxVerification.md)
provides the opt-in commands and private attempt-file requirements. Offline tests
check that attempt files prevent repeat placements and that diagnostics omit
private values.

The execution evidence dated 2026-10-29 in
[#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27) came from uncommitted
runner extensions based on `24593af` in the triage worktree. This revision preserves
those scenarios with formatting and safety checks. It does not claim another
remote run or new provider qualification. The 2026-10-28 results above remain the
dated baseline for the original runner.

Keep pending work and remote evidence in #27, labelled with the source revision
or working-tree status and execution date. Do not copy its pending checklist into
coverage matrices.

## Remaining qualification

Publication of 0.1.0 remains blocked on the minimum OS release gate below.
Authenticated sandbox qualification is incomplete, and production testing is
not claimed. The 0.x coverage allowance does not waive the minimum OS gate.

Minimum macOS 15 and iOS 18 runtime qualification has not been executed. Follow
the [minimum OS release gate](../docs/development.md#qualify-minimum-apple-os-versions-before-release)
before publication. The newer Apple CI runtimes do not satisfy that gate.

The package remains partial 0.x. #27 tracks pending remote qualification.
Read its current body before planning a remote run. A passed day-history request does not qualify every interval,
option, or populated-data shape.

GTT, order/basket margin and charge calculations, and API MARKET placement are
documented sandbox exclusions and remain remotely unverified. There is no
production fallback. Local deterministic tests do not substitute for broker evidence.

[Publication #40](https://github.com/ankitgoyalio/swiftkiteconnect/issues/40) and
[local completeness #24](https://github.com/ankitgoyalio/swiftkiteconnect/issues/24)
are closed as of 2026-10-29. Their closure is not 1.0 qualification. Publication
evidence belongs to #40; use the [Pages guide](Pages.md) to verify or maintain the
site. For current automated checks, inspect the workflow run for the revision
being assessed rather than the old PR #28 check page. Parent
[#3](https://github.com/ankitgoyalio/swiftkiteconnect/issues/3) tracks overall completion.
