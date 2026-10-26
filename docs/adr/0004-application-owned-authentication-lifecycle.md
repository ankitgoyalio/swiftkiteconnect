# Let applications own the authentication lifecycle

The SDK will provide login-URL creation, token exchange, and authenticated requests. Applications will own browser presentation, redirect handling, and credential storage, avoiding UI and storage dependencies in the shared Apple/Linux core.

Secret-bearing token exchange belongs on a backend for publicly distributed applications, as required by the [Kite authentication documentation](https://kite.trade/docs/connect/v3/user/). Swift backends may perform that exchange with the SDK; application-specific backend protocols remain the application's responsibility.

Each client instance represents one API key/user session. Credentials and mutable session state are not global; applications create separate clients for separate users. Replacing credentials must prevent queued work or reconnect attempts from accidentally using the previous session.
