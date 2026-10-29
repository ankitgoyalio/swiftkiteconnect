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

## Evidence reported after the committed runner

As of 2026-10-29, [#27](https://github.com/ankitgoyalio/swiftkiteconnect/issues/27)
records SDK token exchange and logout, remote recovery in each tick mode,
simulated LIMIT placement/modification/cancellation, position conversion and exit,
and holdings-authorisation initiation. That report explicitly identifies its
runner extensions as uncommitted and unmerged. The first-pass runner in this
revision does not reproduce all those scenarios. The 2026-10-28 results above
remain the dated baseline for the committed runner, not a list of current blockers.

Keep pending work and evidence from unmerged changes in #27, labelled with the
source revision or working-tree status and execution date. When the runner changes
merge, update this record with the reproducible commands and evidence revision.
Do not copy their pending checklist into coverage matrices.

## Remaining qualification

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
