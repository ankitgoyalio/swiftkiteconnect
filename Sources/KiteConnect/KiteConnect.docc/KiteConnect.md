# ``KiteConnect``

Integrate Kite Connect v3 with an unofficial Swift package for REST requests, market-data ticks, and order updates.

## Overview

This is development documentation for a partial 0.x package, not a qualified 1.0 release. Authenticated sandbox evidence remains incomplete. Fixture-backed tests do not establish live trading qualification. The package implements the selected 2026-10-27 upstream snapshot. See the repository's [capability coverage](https://github.com/ankitgoyalio/swiftkiteconnect/blob/main/Documentation/CapabilityCoverage.md) and [verification evidence](https://github.com/ankitgoyalio/swiftkiteconnect/blob/main/Documentation/Verification.md) for limitations.

The package requires Swift 6.4 and supports iOS 18+, macOS 15+, and server-side Swift on Linux. CI targets Ubuntu 24.04. These pages assume that you know Swift, Swift Package Manager, and `async/await`.

Use ``KiteClient`` for REST operations and ``KiteTicker`` for streaming. A market-data tick is a streamed quote update. An order update describes an order's state. A postback delivers an order update to your application's HTTP callback URL.

Applications own browser presentation, redirect handling, credential storage, and reconciliation. Secret-bearing token exchange belongs on a backend for publicly distributed applications. Each client represents one API key and user session. Requests attempt once without automatic retries. Reconcile uncertain trading mutations before another action. Each ticker owns one connection. Missed streaming events are not replayed.

The configuration and client reference is the first completed documentation slice. Other generated symbol pages may lack descriptions until their slices are complete. Complete meaningful public API documentation remains a release requirement.

## Topics

### Configure a client

- <doc:Create-a-client>
- ``KiteConfiguration``
- ``KiteClient``
