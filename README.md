# swiftkiteconnect

An unofficial Swift SDK for Kite Connect v3, with typed REST requests, streaming,
and postback validation. This is a partial 0.x package, not a qualified 1.0 release.
Authenticated sandbox qualification remains incomplete.

Requires Swift 6.4. Supports iOS 18+, macOS 15+, and server-side Swift on Linux;
CI targets Ubuntu 24.04. Add this repository as a SwiftPM dependency and select
the `KiteConnect` library product and module.

Start with the [DocC overview](Sources/KiteConnect/KiteConnect.docc/KiteConnect.md)
and [first-request tutorial](Sources/KiteConnect/KiteConnect.docc/First-request.tutorial).
[Build the browsable documentation](Documentation/DocC.md) locally. The planned
site is `https://kiteconnect.ankitgoyal.io`; publication and domain setup belong
to [#40](https://github.com/ankitgoyalio/swiftkiteconnect/issues/40).

See [capability coverage](Documentation/CapabilityCoverage.md),
[qualification evidence](Documentation/Verification.md), and
[development instructions](docs/development.md) for scope and contributor checks.
