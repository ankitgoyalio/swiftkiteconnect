# Design a native Swift public API

The SDK will use idiomatic Swift APIs, including typed request parameters, typed responses, and async throwing operations, while preserving Kite's domain terminology and server behavior. Public method signatures will not be constrained to match an official SDK in another language; those SDKs remain references for protocol handling and edge cases.

REST operations will use `async throws`; streaming will expose typed events through `AsyncSequence`. Clients must be safe to share between Swift tasks and support cancellation. Callback and Combine alternatives are outside the first release. Streaming recovery and buffering are specified in ADR-0007.

One SwiftPM library/module, `KiteConnect`, will expose separate `KiteClient` and `KiteTicker` entry points for REST and streaming, with shared models and postback helpers in that module initially. The repository retains its existing `swiftkiteconnect` name.

Structured errors will distinguish local validation, transport failures, API rejections, decoding failures, and streaming failures. Where available, errors will preserve HTTP status, Kite's error type (including unfamiliar values), and its message. Cancellation remains recognizable as cancellation; uncertain mutation outcomes are explicit.
