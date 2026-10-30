<p align="center">
  <img src="assets/branding/swiftkiteconnect-mascot-transparent.png" alt="swiftkiteconnect mascot" width="220">
</p>

# swiftkiteconnect

An unofficial Swift SDK for Kite Connect v3. Build iOS, macOS, and server-side
Swift applications with typed REST APIs, live market data, and order updates.

[Documentation](https://kiteconnect.ankitgoyal.io) ·
[First request](Sources/KiteConnect/KiteConnect.docc/First-request.tutorial) ·
[Releases](https://github.com/ankitgoyalio/swiftkiteconnect/releases) ·
[Issues](https://github.com/ankitgoyalio/swiftkiteconnect/issues)

## Capabilities

- Use `KiteClient` for authentication, orders, GTT triggers, alerts, portfolio,
  instruments, quotes, historical candles, mutual-fund information, and margin calculations.
- Use `KiteTicker` to subscribe to market-data ticks and order updates over WebSocket,
  with typed events, bounded buffers, and configurable reconnection.
- Validate incoming HTTP order postbacks with `KitePostbacks`.
- Work with `async/await`, `Decimal` financial values, and replaceable HTTP and
  WebSocket transports.
- Integrate Kite Publisher through guides for application-owned browser flows.

The [REST coverage matrix](Documentation/Coverage.md) and
[capability coverage](Documentation/CapabilityCoverage.md) describe the implemented
scope against the 2026-10-27 Kite Connect documentation snapshot.

## Requirements

The package requires Swift 6.4 and Swift Package Manager.

| Platform | Minimum target |
| --- | --- |
| iOS | 18 |
| macOS | 15 |
| Linux | CI targets Ubuntu 24.04 |

Minimum iOS and macOS runtime qualification remains pending. See
[verification evidence](Documentation/Verification.md) for tested environments and remaining release gates.

## Installation

Add `https://github.com/ankitgoyalio/swiftkiteconnect` as a Swift package dependency
in Xcode or your `Package.swift`. Add the `KiteConnect` library product to your
application target. The module name is also `KiteConnect`.

Once the **0.1.0** tag is published, select an exact version requirement of
**0.1.0** in Xcode, or use `exact: "0.1.0"` in your package dependency.
Until publication, pin a reviewed commit revision. The
[releases page](https://github.com/ankitgoyalio/swiftkiteconnect/releases)
lists published versions.

## Get started

Follow the [first-request tutorial](Sources/KiteConnect/KiteConnect.docc/First-request.tutorial)
to create a client, authenticate through your backend, and fetch a user profile.
You need a Kite Connect application API key and a registered redirect URL.

Your application owns browser presentation, redirects, and credential storage.
For publicly distributed applications, keep the API secret and token exchange on
your backend. See [authentication ownership](Sources/KiteConnect/KiteConnect.docc/Authentication-ownership.md).

Continue with the task guides:

- [Manage orders](Sources/KiteConnect/KiteConnect.docc/Manage-orders.md)
- [Stream market data and order updates](Sources/KiteConnect/KiteConnect.docc/Connect-and-consume-streams.md)
- [Request quote snapshots](Sources/KiteConnect/KiteConnect.docc/Request-quote-snapshots.md)
- [Inspect holdings and positions](Sources/KiteConnect/KiteConnect.docc/Inspect-and-convert-portfolio.md)
- [Receive HTTP postbacks](Sources/KiteConnect/KiteConnect.docc/Receive-HTTP-postbacks.md)

The [hosted documentation](https://kiteconnect.ankitgoyal.io) tracks development on
`main`. For documentation that matches an installed revision, use its DocC catalog
or [build the documentation locally](Documentation/DocC.md).

## Release status

0.1.0 is the planned first release. Publication remains blocked on minimum
macOS 15 and iOS 18 runtime qualification. This early 0.x release has incomplete
authenticated sandbox qualification, and production testing is not claimed. Review the
[verification evidence and remaining qualification](Documentation/Verification.md)
before adopting the package.

REST requests make one attempt without automatic retries. Reconcile an uncertain
trading mutation before submitting another action. Streaming recovery does not
replay missed events. Your application must reconcile gaps. Read the
[request contracts](Sources/KiteConnect/KiteConnect.docc/Request-and-response-contracts.md),
[trading mutation outcomes](Sources/KiteConnect/KiteConnect.docc/Trading-mutation-outcomes.md), and
[streaming recovery guide](Sources/KiteConnect/KiteConnect.docc/Streaming-recovery.md).

## Contributing

Report bugs and propose changes through
[GitHub Issues](https://github.com/ankitgoyalio/swiftkiteconnect/issues).
Include a reproducible example and remove credentials and account data.

Read the [development guide](docs/development.md) for toolchain setup and checks,
and the [documentation policy](Documentation/README.md) before changing guides.

## License

swiftkiteconnect is available under the [MIT license](LICENSE).
