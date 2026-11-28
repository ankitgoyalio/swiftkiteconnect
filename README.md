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

## Develop and test

Run `swift test` from the package root on macOS. The contract tests run without Kite Connect credentials. REST test fixtures use Zerodha's mock data pinned at `c7a81238f93b4057c07257823b1bfaf30cba9ae5`. [Pinned Zerodha fixtures](https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5)
