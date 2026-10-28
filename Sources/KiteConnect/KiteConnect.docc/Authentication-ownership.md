# Authentication ownership

A client represents one API key and user session, while the application controls how that session begins and ends.

## Browser and backend boundaries

``KiteClient/loginURL(redirectParameters:endpoint:)`` constructs a URL. The application presents the browser, validates the exact registered callback, checks any application state, and routes the request token. The SDK has no UI dependency or callback listener, so the same module works on Apple platforms and Linux.

The request token is short lived and can be exchanged once. Publicly distributed applications keep the API secret on a backend. Embedding a secret in an application binary gives every recipient access to it. A checksum-based exchange does not remove that storage constraint.

``KiteClient/exchangeRequestToken(_:apiSecret:)`` lets a Swift backend perform the exchange. The SDK computes the checksum from the exact API key, request token, and secret bytes. It installs the access token only after validating the response's API key, login time, and access token. Applications define the backend protocol and control delivery of credentials to an authorized client.

## Credential storage and lifetime

The SDK keeps the installed access token in client memory. It does not persist the secret, session response, or access token. Applications own secure credential storage, logging policy, and logout UI. Tokens and complete session responses are sensitive even when a field is named `publicToken`.

The pinned upstream contract states that access tokens expire at 6 AM the next day unless invalidated sooner. ``KiteSession/loginTime`` records login time, not a locally enforced expiration deadline. A successful profile request confirms that one request succeeded; it does not guarantee future validity. Expiry and `TokenException` require an application login decision. The SDK never schedules renewal.

Refresh tokens normally arrive empty and require platform approval from Kite. ``KiteClient/renewSession(refreshToken:apiSecret:)`` is a backend operation for those approved platforms. It follows the official Python SDK reference rather than a fully described route in the pinned user snapshot.

## Concurrent work and session changes

An actor allows tasks for the same session to share a ``KiteClient``. Separate users have separate clients. Replacing an access token preserves the client's API key. A different API key requires another client.

``KiteClient/replaceAccessToken(_:)`` changes local credentials for requests admitted after replacement returns. A request already handed to the transport can finish with its original credentials. Late exchange and renewal responses cannot overwrite an explicit replacement. A late invalidation response cannot clear a replacement token.

A canceled authentication request throws `CancellationError` without installing or clearing local credentials from its response. Cancellation does not prove that the server stopped processing the request. The SDK makes one attempt and does not retry token exchange, renewal, or revocation. Applications decide how to reconcile remote state with their credential store. REST clients and tickers have independent credentials.

## Related documentation

- <doc:First-request>
- <doc:Authenticate-a-session>
- ``KiteSession``
- ``KiteSessionCredentials``
- ``KiteSessionRenewal``
- ``KiteUserProfile``

See <doc:Request-and-response-contracts> for the shared reference and <doc:First-request> for the introductory read-only tutorial.
