# Authenticate a session

Connect an application-owned login flow to a client and end the session explicitly.

For a guided introduction, use <doc:First-request>. For the reasons behind the ownership boundaries, read <doc:Authentication-ownership>.

## Complete login and token exchange

1. Create a ``KiteClient`` for the application's API key and one user session. Construction sends no request.
2. Call ``KiteClient/loginURL(redirectParameters:endpoint:)`` and present the returned URL using your application's browser flow.
3. Validate the exact registered callback and any application state when the browser redirects. Extract the short-lived, one-time request token. The SDK does not validate redirects or application state.
4. Send the request token to your backend through your application's authenticated channel. Keep the API secret on that backend for publicly distributed applications.
5. On a Swift backend, call ``KiteClient/exchangeRequestToken(_:apiSecret:)``. Use a separate client for each API key and user session. This helper illustrates the SDK part of that operation.

```swift
import KiteConnect

// Backend only. The caller supplies the secret from backend configuration.
// Authenticate the application request and validate its login flow before calling.
func doccBackendExchange(
	apiKey: String, requestToken: String, backendAPISecret: String
) async throws -> KiteSessionCredentials {
	let client = try KiteClient(apiKey: apiKey)
	let session = try await client.exchangeRequestToken(
		requestToken, apiSecret: backendAPISecret)
	return KiteSessionCredentials(apiKey: session.apiKey, accessToken: session.accessToken)
}
```

6. Return the required credentials through your application's authenticated channel. Do not expose the full session response in browser payloads or logs. The SDK does not define your backend protocol.
7. In the application, construct a client with ``KiteClient/init(session:configuration:transport:)`` or await ``KiteClient/replaceAccessToken(_:)`` on the existing client. Store credentials through your application's credential store.
8. Call ``KiteClient/profile()`` to confirm the account with a read-only request. Use the returned ``KiteUserProfile/userID`` to identify the signed-in account.

Each request attempts once. Handle `CancellationError` as cancellation. Handle `KiteError.api`, including `TokenException`, through your application's error and login flow. The SDK does not renew or retry automatically. After a canceled exchange or a transport failure, do not assume that the one-time request token remains unused. Establish the remote outcome before deciding how to resume login.

## Select sandbox routing explicitly

Create the client with ``KiteConfiguration/sandbox`` and pass the sandbox login endpoint separately. Sandbox configuration changes REST routing without changing the default login URL.

```swift
import Foundation
import KiteConnect

func doccSandboxAuthentication(apiKey: String) throws -> (KiteClient, URL) {
	let client = try KiteClient(apiKey: apiKey, configuration: .sandbox)
	let login = try client.loginURL(
		endpoint: URL(string: "https://sandbox.kite.trade/connect/login")!)
	return (client, login)
}
```

Use the backend exchange and access token for the same environment. There is no implicit production fallback. See <doc:Create-a-client> for request configuration.

## End a session

Call ``KiteClient/invalidateSession()`` to request remote revocation. A confirmed `true` clears the matching token in that client. A `false` response or a failure preserves local credentials. Clear your application's persisted credentials and update its logout UI separately.

To clear only local credentials, await ``KiteClient/replaceAccessToken(_:)`` with `nil`. Local clearing sends no remote revocation request. Stop admitting old-session work before replacement. Already transmitted requests may complete with their original credentials. Ticker credentials are separate and require explicit application handling.

If remote revocation is canceled or its response is lost, the remote outcome can differ from the client's local state. Choose your application's logout behavior without treating cancellation as proof that the session remains valid.

## Use refresh tokens only with Kite approval

Call ``KiteClient/renewSession(refreshToken:apiSecret:)`` only on a backend for a platform that Kite has approved for refresh tokens. Store any returned refresh token through your backend's credential store. An absent refresh token in ``KiteSessionRenewal`` does not synthesize a replacement.

Use ``KiteClient/invalidateRefreshToken(_:)`` to revoke a refresh token independently of the installed access token. These operations follow the official SDK reference and have less upstream narrative coverage than the main login flow. They do not provide general perpetual login.
