# Kite Connect

Kite Connect is Zerodha's interface for trading, portfolio information, and market data. This glossary defines the language used by the unofficial Swift SDK.

## Language

**Instrument**:
A financial instrument identified within an exchange by its trading symbol.
_Avoid_: Instrument token

**Instrument token**:
The numeric identifier Kite uses for an instrument in subscriptions and certain data requests; it may be reused after a derivative contract expires.
_Avoid_: Permanent instrument identity

**Trading symbol**:
The symbol identifying an instrument within a particular exchange; the exchange and trading symbol together identify the instrument for persistent storage.
_Avoid_: Globally unique symbol

**Postback**:
An order-status notification sent by Kite Connect to an application's registered HTTP callback URL.
_Avoid_: Outgoing endpoint, market-data tick

**Order update**:
A notification of an order's state, delivered through WebSocket streaming or an HTTP postback.
_Avoid_: Trade, market-data tick

**Market-data tick**:
A streamed quote update for an instrument, with fields determined by the subscription mode.
_Avoid_: Order update, postback
