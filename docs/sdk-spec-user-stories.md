# SDK user stories

Part of the [SDK specification](sdk-spec.md), published as [issue #3](https://github.com/ankitgoyalio/swiftkiteconnect/issues/3).

1. As a Swift developer, I want to install a SwiftPM library and import `KiteConnect`, so that I can integrate Kite without writing a protocol client.
2. As an iOS developer, I want support for iOS 18 and later, so that I can use the SDK in a native application.
3. As a macOS developer, I want support for macOS 15 and later, so that I can use the same integration in desktop software.
4. As a backend developer, I want tested Linux support, so that I can run Kite integrations on a Swift server.
5. As a Swift developer, I want typed request and response models with `async throws` operations, so that I can use normal Swift concurrency and compiler assistance.
6. As a developer, I want clients that are safe to share between Swift tasks and support cancellation, so that I can integrate them into concurrent applications.
7. As an application developer, I want to construct Kite login URLs, so that I can initiate authentication through my chosen browser experience.
8. As a backend developer, I want to exchange a request token for an authenticated session, so that my application can keep its API secret on the backend.
9. As an application developer, I want to control browser presentation, redirects, and credential storage, so that authentication fits my application's architecture.
10. As a developer, I want authenticated calls and session invalidation operations, so that I can manage a user's Kite session through the documented API.
11. As a multi-user backend developer, I want isolated clients for each API key/user session, so that one user's credentials cannot leak into another user's work.
12. As a developer replacing credentials, I want stale queued work and reconnect attempts prevented from using the previous session accidentally, so that session changes are predictable.
13. As an application developer, I want to retrieve user profile, funds, and margin information, so that I can present the user's account state.
14. As a trading application developer, I want all documented order placement, modification, cancellation, and related order operations, so that I can implement Kite's supported order workflows.
15. As a trading application developer, I want order lists, order history, and trade information, so that I can inspect the actual state of an order after submission.
16. As a developer submitting a trading mutation, I want an uncertain outcome distinguished from a confirmed API rejection, so that I can reconcile state before deciding on another action.
17. As a developer, I want trading mutations sent without automatic resubmission, so that a lost response does not cause the SDK to duplicate an action.
18. As a trading application developer, I want all documented GTT operations, so that I can manage supported trigger-based orders.
19. As a trading application developer, I want all documented alert operations, including documented order-triggering alert capabilities, so that I can use those workflows from Swift.
20. As an investment application developer, I want holdings, positions, and documented portfolio operations, so that I can present and manage portfolio state.
21. As a market-data application developer, I want the documented quote, OHLC, and last-traded-price APIs, so that I can retrieve the appropriate snapshot for my use case.
22. As a developer, I want the instrument CSV downloaded and parsed into typed instruments, so that I can discover symbols and request identifiers without maintaining my own parser.
23. As a watchlist developer, I want an exchange/trading-symbol identity distinct from an instrument token, so that a saved instrument is not mistaken for a reused token.
24. As a developer, I want to own instrument persistence, refresh schedules, and expired-contract mappings, so that caching follows my application's needs.
25. As a historical-data application developer, I want every documented candle-data operation and option, so that I can retrieve the historical data Kite supports.
26. As a mutual-fund application developer, I want all documented mutual-fund and SIP operations, so that I can implement those investment workflows in Swift.
27. As a trading application developer, I want all documented margin and charge calculation operations, so that I can estimate the values Kite exposes before an action.
28. As a market-data developer, I want typed ticks for every documented WebSocket mode and instrument layout, so that I do not have to decode binary packets myself.
29. As a streaming developer, I want subscription, unsubscription, and mode changes, so that I can control which instrument data I receive.
30. As an order-monitoring developer, I want asynchronous order updates and documented non-binary messages, so that my application can react to Kite events.
31. As a streaming developer, I want explicit connect and disconnect operations on a ticker owning one connection, so that I control its lifecycle and connection use.
32. As a developer needing multiple connections, I want to create separate ticker instances, so that connection allocation remains explicit.
33. As a streaming developer, I want configurable, bounded reconnect backoff with subscription and mode restoration after transient failures, so that recoverable interruptions require less application code.
34. As a streaming consumer, I want notifications of possible data gaps, so that reconnection is not mistaken for replay of missed events.
35. As an application developer, I want reconnect attempts to stop on authentication failures until fresh credentials arrive, so that invalid sessions do not produce endless recovery attempts.
36. As a developer, I want disconnect to cancel reconnection and close event streams, so that an explicitly stopped ticker stays stopped.
37. As a developer with multiple event consumers, I want each subscriber to receive its own copy of subscribed events, so that a UI and an order monitor do not compete for updates.
38. As a developer, I want bounded, independent market-data and order-update buffers, so that quote traffic cannot consume order-update buffering or grow memory without limit.
39. As a slow subscriber, I want an explicit overflow failure affecting my subscription while other subscribers continue, so that lost continuity is visible and isolated.
40. As a streaming developer, I want cancelling one subscriber to leave the ticker and other subscribers running, so that consumers have independent lifetimes.
41. As a backend developer, I want to decode and validate incoming order postbacks, so that I can verify and consume notifications in my own HTTP application.
42. As a developer, I want postbacks and WebSocket order updates distinguished from market-data ticks, so that the event models reflect their different meanings.
43. As a financial application developer, I want `Decimal` prices, monetary amounts, and financial rates, including streamed prices, so that my calculations receive decimal values.
44. As a developer, I want date-only expiry values distinguished from timestamp instants, so that calendar dates are not distorted by timezone conversion.
45. As a developer, I want explicit timestamp offsets honored and offsetless fields interpreted with a configurable trading timezone defaulting to `Asia/Kolkata`, so that results do not depend on the device timezone.
46. As a developer, I want unfamiliar server values preserved alongside known typed cases, so that newly introduced statuses or identifiers do not unnecessarily break decoding.
47. As a developer, I want additional JSON fields tolerated and malformed required data rejected clearly, so that forward compatibility does not hide corrupt responses.
48. As a developer, I want local checks for documented request structure while Kite remains authoritative for broker/exchange rules, so that validation is useful without becoming stale business logic.
49. As a developer, I want structured validation, transport, API, decoding, and streaming errors with available HTTP status, Kite error type, and message, so that I can make informed recovery decisions.
50. As a developer, I want cancellation to remain recognizable, so that expected task cancellation is not mistaken for an API failure.
51. As a developer, I want each REST request attempted once, configurable timeouts, and visible rate-limit errors, so that I control scheduling and retry decisions.
52. As a developer testing an integration, I want replaceable transports, so that I can exercise public SDK behavior without credentials or real orders.
53. As an SDK maintainer, I want automated protocol tests on macOS, iOS Simulator, and Ubuntu 24.04, so that supported platforms have evidence of compatibility.
54. As an SDK maintainer, I want real Linux transport compatibility verified before its implementation is selected, so that a networking API's presence is not confused with working WebSocket support.
55. As a developer, I want authentication, REST, streaming, postback, reconciliation, and Publisher integration guidance, so that I can use the SDK within the intended application boundaries.
56. As an SDK consumer, I want a release-specific documentation snapshot and endpoint/capability checklist with visible gaps, so that I can assess the release's coverage.
57. As an early adopter, I want partial 0.x releases clearly identified, so that I can try available functionality without assuming 1.0 completeness.
58. As a contributor, I want the routine test suite to use fixtures and controlled transports without live trading, so that I can validate changes without an account or financial side effects.
