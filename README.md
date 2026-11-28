# KiteConnect for Swift

KiteConnect is a Swift package for Zerodha's Kite Connect v3 API. It requires Swift 6 and supports iOS 16 and macOS 13 or later.

## Add the package

In Xcode, add `https://github.com/ankitgoyalio/swiftkiteconnect` as a Swift package dependency and link the `KiteConnect` product to your target.

```swift
import Foundation
import KiteConnect

let kite = KiteConnectClient(apiKey: apiKey, accessToken: accessToken)

let profile = try await kite.profile()
print(profile.userName)

let end = Date()
let candles = try await kite.historicalCandles(
    instrumentToken: 408065,
    interval: .day,
    from: end.addingTimeInterval(-7 * 24 * 60 * 60),
    to: end
)
```

## Sessions and order routing

Your app owns browser login, Access Token storage, and session recovery. In a distributed iOS or macOS app, exchange the Request Token on a trusted backend and keep the API secret there. A REST failure with `KiteError.service` and `isSessionExpired == true` identifies Kite's invalid or expired session response. [Kite app integration guidance](https://kite.trade/docs/connect/v3/apps/)

Order placement requires network egress through a static IP registered with Zerodha. Your app controls order routing and REST retries. If an order write times out, query the order book to reconcile the outcome before deciding whether to submit again. [Zerodha static IP requirements](https://support.zerodha.com/category/trading-and-markets/general-kite/kite-api/articles/static-ip)

On your backend, call `KiteConnectClient.exchangeRequestToken(_:apiKey:apiSecret:)` to obtain a `UserSession`. Call `kite.invalidateAccessToken()` to invalidate the current session explicitly. Your app manages its stored credentials. [Kite user and session API](https://kite.trade/docs/connect/v3/user/)

## Stream market data

```swift
let ticker = try await KiteTicker.connect(apiKey: apiKey, accessToken: accessToken)
try await ticker.subscribe([408065], mode: .ltp)

for try await event in ticker {
    if case .ticks(let ticks) = event {
        for tick in ticks { print(tick.instrumentToken, tick.lastPrice) }
    }
}
```

Use one iterator per ticker. Tick batches and WebSocket Order Updates arrive in receive order. The ticker pauses receives when its event buffer fills. A transient disconnect emits `.interrupted`, and the ticker emits `.recovered` after restoring the latest requested subscriptions and modes. Reconcile any data missed during the gap through the REST API. Call `await ticker.close()` to close the socket and drain buffered events. [Kite WebSocket API](https://kite.trade/docs/connect/v3/websocket/)

## Verify HTTP Postbacks

Host the registered Postback receiver on your backend. Decode the raw HTTP request body and verify Kite's checksum with the API secret. The checksum covers the order ID and order timestamp. [Kite Postback checksum](https://kite.trade/docs/connect/v3/postbacks/#checksum)

```swift
let postback = try Postback.decode(requestBody)
if postback.verifyChecksum(apiSecret: apiSecret) {
    print(postback.orderID)
}
```

## Develop and test

Run `swift test` from the package root on macOS. The contract tests run without Kite Connect credentials. REST test fixtures use Zerodha's mock data pinned at `c7a81238f93b4057c07257823b1bfaf30cba9ae5`. [Pinned Zerodha fixtures](https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5)
