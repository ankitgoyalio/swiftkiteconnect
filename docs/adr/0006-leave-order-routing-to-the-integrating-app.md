# Leave order routing to the integrating app

The SDK exposes Kite's order API directly. The integrating app owns network routing and must ensure order placement reaches Kite from a static IP registered with Zerodha. Market data streaming, order-book reads, and position reads can use other IPs.

[Zerodha static IP requirements](https://support.zerodha.com/category/trading-and-markets/general-kite/kite-api/articles/static-ip)
