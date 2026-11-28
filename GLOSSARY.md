# Kite Connect

This context covers broker sessions, trading, portfolio data, and market data provided by Zerodha's Kite Connect API.

## Language

**Request Token**:
A short-lived, one-time credential issued by Kite Connect after the user signs in. It can be exchanged for an **Access Token**.

**Access Token**:
A credential that authenticates API requests and ticker connections for a Kite user session.

**Ticker Subscription**:
A request to receive live market data for an instrument in last traded price, quote, or full mode.

**Postback**:
An HTTP notification that Kite Connect sends to a registered application URL when the status of an order placed by that application changes.

**WebSocket Order Update**:
An order status event delivered through the authenticated ticker connection. It can include orders the user placed through other Kite channels.

**Publisher**:
Zerodha's browser-based integration for submitting orders from an external website through Kite.
