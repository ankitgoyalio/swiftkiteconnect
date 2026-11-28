import Foundation
import KiteConnect
import os
import Testing

struct OrderWriteTests {
    @Test func placesRegularOrderWithAutomaticMarketProtection() async throws {
        try await withAcknowledgement(
            method: "POST",
            path: "/orders/regular",
            form: "exchange=NSE&tradingsymbol=ACC&transaction_type=BUY&order_type=MARKET&quantity=1&product=MIS&validity=DAY&market_protection=-1&autoslice=false"
        ) { client in
            let result = try await client.placeOrder(.regular, parameters: .init(
                exchange: "NSE", tradingSymbol: "ACC", transactionType: .buy,
                orderType: .market, quantity: 1, product: .mis, validity: .day,
                marketProtection: -1, autoslice: false
            ))
            #expect(result.orderID == "151220000000000")
            #expect(result.children == nil)
        }
    }

    @Test func placesAfterMarketOrderUsingAMOVariety() async throws {
        try await withAcknowledgement(
            method: "POST",
            path: "/orders/amo",
            form: "exchange=BSE&tradingsymbol=ACC&transaction_type=SELL&order_type=LIMIT&quantity=2&product=CNC&price=166.5"
        ) { client in
            let result = try await client.placeOrder(.amo, parameters: .init(
                exchange: "BSE", tradingSymbol: "ACC", transactionType: .sell,
                orderType: .limit, quantity: 2, product: .cnc, price: 166.5
            ))
            #expect(result.orderID == "151220000000000")
        }
    }

    @Test func placesCoverOrderWithAStopLossTrigger() async throws {
        try await withAcknowledgement(
            method: "POST",
            path: "/orders/co",
            form: "exchange=NSE&tradingsymbol=ACC&transaction_type=BUY&order_type=LIMIT&quantity=1&product=MIS&validity=DAY&price=166.5&trigger_price=164.75"
        ) { client in
            let result = try await client.placeOrder(.co, parameters: .init(
                exchange: "NSE", tradingSymbol: "ACC", transactionType: .buy,
                orderType: .limit, quantity: 1, product: .mis, validity: .day,
                price: 166.5, triggerPrice: 164.75
            ))
            #expect(result.orderID == "151220000000000")
        }
    }

    @Test func placesIcebergOrderWithExplicitLegSizeAndTTL() async throws {
        try await withAcknowledgement(
            method: "POST",
            path: "/orders/iceberg",
            form: "exchange=NSE&tradingsymbol=SBIN&transaction_type=BUY&order_type=LIMIT&quantity=1000&product=CNC&validity=TTL"
                + "&price=463.25&disclosed_quantity=0&validity_ttl=2&iceberg_legs=5&iceberg_quantity=200&tag=icebergord"
        ) { client in
            let result = try await client.placeOrder(.iceberg, parameters: .init(
                exchange: "NSE", tradingSymbol: "SBIN", transactionType: .buy,
                orderType: .limit, quantity: 1_000, product: .cnc, validity: .ttl,
                price: 463.25, disclosedQuantity: 0, validityTTL: 2, icebergLegs: 5,
                icebergQuantity: 200, tag: "icebergord"
            ))
            #expect(result.orderID == "151220000000000")
        }
    }

    @Test func placesAuctionOrderWithItsStringAuctionNumber() async throws {
        try await withAcknowledgement(
            method: "POST",
            path: "/orders/auction",
            form: "exchange=NSE&tradingsymbol=BHEL&transaction_type=SELL&order_type=LIMIT&quantity=60&product=CNC&validity=DAY&price=85&auction_number=022"
        ) { client in
            let result = try await client.placeOrder(.auction, parameters: .init(
                exchange: "NSE", tradingSymbol: "BHEL", transactionType: .sell,
                orderType: .limit, quantity: 60, product: .cnc, validity: .day,
                price: 85, auctionNumber: "022"
            ))
            #expect(result.orderID == "151220000000000")
        }
    }

    @Test func modifiesOpenOrderWithMarketProtectionAndExplicitZeroes() async throws {
        try await withAcknowledgement(
            method: "PUT",
            path: "/orders/regular/151220000000000",
            form: "order_type=MARKET&quantity=3&price=0&trigger_price=0&disclosed_quantity=0&validity=DAY&market_protection=2.5"
        ) { client in
            let result = try await client.modifyOrder(.regular, orderID: "151220000000000", parameters: .init(
                orderType: .market, quantity: 3, price: 0, triggerPrice: 0,
                disclosedQuantity: 0, validity: .day, marketProtection: 2.5
            ))
            #expect(result.orderID == "151220000000000")
        }
    }

    @Test func modifiesCoverOrderLegWithItsParentID() async throws {
        try await withAcknowledgement(
            method: "PUT",
            path: "/orders/co/151220000000000",
            form: "trigger_price=166.5&parent_order_id=parent%2B1"
        ) { client in
            let result = try await client.modifyOrder(
                .co, orderID: "151220000000000", parentOrderID: "parent+1", parameters: .init(triggerPrice: 166.5)
            )
            #expect(result.orderID == "151220000000000")
        }
    }

    @Test func cancelsCoverOrderLegWithItsParentIDInTheQuery() async throws {
        try await withAcknowledgement(
            method: "DELETE",
            path: "/orders/co/child%2F1",
            query: "parent_order_id=parent%2B1"
        ) { client in
            let result = try await client.cancelOrder(.co, orderID: "child/1", parentOrderID: "parent+1")
            #expect(result.orderID == "151220000000000")
        }
    }

    @Test func returnsAutosliceParentAndEveryChildOutcomeInOrder() async throws {
        // From autoslice_response.json at https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        try await withAcknowledgement(
            method: "POST",
            path: "/orders/regular",
            form: "exchange=NFO&tradingsymbol=NIFTY2580724400CE&transaction_type=BUY&order_type=MARKET&quantity=5000&product=NRML&validity=DAY"
                + "&market_protection=-1&autoslice=true",
            fixtureName: "order_write_autoslice.json"
        ) { client in
            let result = try await client.placeOrder(.regular, parameters: .init(
                exchange: "NFO", tradingSymbol: "NIFTY2580724400CE", transactionType: .buy,
                orderType: .market, quantity: 5_000, product: .nrml, validity: .day,
                marketProtection: -1, autoslice: true
            ))
            #expect(result.orderID == "1914227164488687616")
            let children = try #require(result.children)
            try #require(children.count == 4)
            #expect(children[0] == .placed(orderID: "1914227164534824960"))
            #expect(children[1] == .placed(orderID: "1914227164580962304"))
            #expect(children[3] == .placed(orderID: "1914227164681625600"))
            guard case let .failed(error) = children[2] else {
                Issue.record("Expected the third slice to fail.")
                return
            }
            #expect(error.code == 400)
            #expect(error.errorType == "MarginException")
            #expect(error.kind == .margin)
            #expect(error.message == "Insufficient funds. Required margin is 228365.92 but available margin is 228358.50.")
            #expect(error.data == .null)
        }
    }

    @Test func preservesStructuredDataAndUnknownErrorTypesForFailedSlices() async throws {
        // Synthetic variant of autoslice_response.json at https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        try await withAcknowledgement(
            method: "POST",
            path: "/orders/regular",
            form: "exchange=NFO&tradingsymbol=NIFTY2580724400CE&transaction_type=BUY&order_type=MARKET&quantity=5000&product=NRML"
                + "&autoslice=true",
            fixtureName: "order_write_autoslice_error_data.json"
        ) { client in
            let result = try await client.placeOrder(.regular, parameters: .init(
                exchange: "NFO", tradingSymbol: "NIFTY2580724400CE", transactionType: .buy,
                orderType: .market, quantity: 5_000, product: .nrml, autoslice: true
            ))
            #expect(result.orderID == "1914227164488687616")
            let children = try #require(result.children)
            try #require(children.count == 3)
            guard case let .failed(error) = children[0],
                  case let .failed(errorWithoutData) = children[1] else {
                Issue.record("Expected the slice to fail.")
                return
            }
            #expect(error.code == 429)
            #expect(error.errorType == "SliceLimitException")
            #expect(error.kind == nil)
            #expect(error.message == "Slice limit reached.")
            #expect(error.data == .object([
                "limits": .array([.number(10), .null]),
                "retryable": .bool(false),
            ]))
            #expect(errorWithoutData.kind == .margin)
            #expect(errorWithoutData.data == nil)
            #expect(children[2] == .placed(orderID: "1914227164681625600"))
        }
    }

    enum Write: String {
        case place = "POST"
        case modify = "PUT"
        case cancel = "DELETE"
    }

    @Test(arguments: [Write.place, .modify, .cancel])
    func returnsWriteTimeoutWithoutResubmitting(_ write: Write) async throws {
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        let fixture = try HTTPStub.fixture("order_write_acknowledgement.json")
        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == write.rawValue)
            let attempt = attempts.withLock {
                $0 += 1
                return $0
            }
            if attempt == 1 { throw URLError(.timedOut) }
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let client = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            do {
                switch write {
                case .place:
                    _ = try await client.placeOrder(.regular, parameters: .init(
                        exchange: "NSE", tradingSymbol: "ACC", transactionType: .buy,
                        orderType: .limit, quantity: 1, product: .cnc, validity: .day, price: 166.5
                    ))
                case .modify:
                    _ = try await client.modifyOrder(.regular, orderID: "151220000000000", parameters: .init(quantity: 2))
                case .cancel:
                    _ = try await client.cancelOrder(.regular, orderID: "151220000000000")
                }
                Issue.record("Expected the timeout to be surfaced.")
            } catch KiteError.transport(let domain, let code) {
                #expect(domain == NSURLErrorDomain)
                #expect(code == URLError.timedOut.rawValue)
            }
        }
        #expect(attempts.withLock { $0 } == 1)
    }

    private func withAcknowledgement(
        method: String,
        path: String,
        query: String? = nil,
        form: String? = nil,
        fixtureName: String = "order_write_acknowledgement.json",
        operation: (KiteConnectClient) async throws -> Void
    ) async throws {
        // From order_response.json at https://github.com/zerodha/kiteconnect-mocks/tree/c7a81238f93b4057c07257823b1bfaf30cba9ae5.
        let fixture = try HTTPStub.fixture(fixtureName)
        try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            #expect(request.httpMethod == method)
            #expect(components.percentEncodedPath == path)
            #expect(components.percentEncodedQuery == query)
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            let body = try HTTPStub.body(of: request)
            if let form {
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
                let encoded = try String(decoding: #require(body), as: UTF8.self).split(separator: "&").sorted()
                #expect(encoded == form.split(separator: "&").sorted())
            } else {
                #expect(body == nil)
            }
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let client = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            try await operation(client)
        }
    }
}
