# Create a client

Construct a sandbox client with an application-provided access token.

Use ``KiteConfiguration/sandbox`` to select the sandbox origin and route prefix. The default configuration points to production.

```swift
import KiteConnect

func configuredSandboxClient(accessToken: String) throws -> KiteClient {
	try KiteClient(
		apiKey: "sandboxdemo",
		accessToken: accessToken,
		configuration: .sandbox)
}
```

Pass the access token supplied by your application's authentication flow. Construction validates credentials locally and makes no request. An invalid credential throws ``KiteError/validation(field:message:)``. Keep a separate client for each API key and user session.

Use ``KiteClient/init(apiKey:accessToken:configuration:transport:)`` for explicit credentials. Use ``KiteClient/init(session:configuration:transport:)`` when your application already has ``KiteSessionCredentials``. Both initializers accept a configuration and a replaceable HTTP transport.

For a custom origin or timeout, use ``KiteConfiguration/init(baseURL:routePrefix:timeout:tradingTimeZone:)``. The configuration validates the origin, route prefix, and timeout before constructing the client.

## Confirm a sandbox profile request

Call this read-only function with the access token supplied by your application. For installation and authentication steps, follow <doc:First-request>.

```swift
import KiteConnect

func readProfile(accessToken: String) async throws -> KiteUserProfile {
	let client = try KiteClient(
		apiKey: "sandboxdemo", accessToken: accessToken, configuration: .sandbox)
	return try await client.profile()
}
```
