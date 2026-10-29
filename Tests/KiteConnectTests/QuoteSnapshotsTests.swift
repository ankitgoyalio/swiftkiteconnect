//
//  QuoteSnapshotsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

private func quoteClient(_ body: String, transport: ControlledHTTP? = nil) throws -> KiteClient {
    try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox,
        transport: transport ?? ControlledHTTP(body),
    )
}

@Test func ltpAcceptsSuppliedIdentitiesAndPreservesMissingKeysAndDecimalPrices() async throws {
    let infy = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
    let index = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "NIFTY 50")
    let transport = ControlledHTTP(
        #"{"status":"success","data":{"NSE:INFY":{"instrument_token":408065,"last_price":1412.95000000000001,"future":true}}}"#,
    )
    let client = try quoteClient("", transport: transport)
    let result = try await client.ltp(instruments: [infy, index, infy])
    #expect(result.count == 1)
    #expect(result[infy]?.instrumentToken == 408_065)
    #expect(result[infy]?.lastPrice == Decimal(string: "1412.95000000000001"))
    #expect(result[index] == nil)
    let request = try #require(await transport.requests.first)
    #expect(
        request.url.absoluteString
            == "https://sandbox.kite.trade/oms/quote/ltp?i=NSE%3AINFY&i=NSE%3ANIFTY%2050&i=NSE%3AINFY",
    )
    #expect(request.method == .get)
    #expect(request.body == nil)
    #expect(request.headers["X-Kite-Version"] == "3")
    #expect(request.headers["Authorization"] == "token key:token")
}

@Test func ohlcReturnsTypedPricesWithoutRequiringCatalogue() async throws {
    let identity = try KiteInstrumentIdentity(exchange: .unknown("NEW"), tradingSymbol: "A&B+C")
    let transport = ControlledHTTP(
        #"{"status":"success","data":{"NEW:A&B+C":{"instrument_token":4294967295,"last_price":1075,"ohlc":{"open":1085.8,"high":1085.9,"low":1070.9,"close":1075.8}}}}"#,
    )
    let result = try await quoteClient("", transport: transport).ohlc(instruments: [identity])
    #expect(result[identity]?.instrumentToken == UInt32.max)
    #expect(result[identity]?.lastPrice == 1075)
    #expect(result[identity]?.ohlc.open == Decimal(string: "1085.8"))
    #expect(result[identity]?.ohlc.high == Decimal(string: "1085.9"))
    #expect(result[identity]?.ohlc.low == Decimal(string: "1070.9"))
    #expect(result[identity]?.ohlc.close == Decimal(string: "1075.8"))
    #expect(
        await transport.requests.first?.url.absoluteString
            == "https://sandbox.kite.trade/oms/quote/ohlc?i=NEW%3AA%26B%2BC",
    )
}

private let fullQuote =
    #"{"instrument_token":408065,"timestamp":"2021-06-08 15:45:56","last_trade_time":null,"last_price":1412.95000000000001,"last_quantity":5,"buy_quantity":0,"sell_quantity":5191,"volume":7360198,"average_price":1412.47,"oi":0,"oi_day_high":12.5,"oi_day_low":0,"net_change":-0.125,"lower_circuit_limit":1250.7,"upper_circuit_limit":1528.6,"ohlc":{"open":1396,"high":1421.75,"low":1395.55,"close":1389.65},"depth":{"buy":[{"price":1412.9,"quantity":40,"orders":3}],"sell":[{"price":1412.95,"quantity":5191,"orders":13}]}}"#
private let infy = try! KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
private func fullEnvelope(_ quote: String = fullQuote) -> String {
    #"{"status":"success","data":{"NSE:INFY":\#(quote)}}"#
}

@Test func quotesDecodeFullDepthNullableTradeAndDefaultTradingTimestamp() async throws {
    let transport = ControlledHTTP(fullEnvelope())
    let result = try await quoteClient("", transport: transport).quotes(instruments: [infy])
    let quote = try #require(result[infy])
    #expect(quote.instrumentToken == 408_065)
    #expect(quote.timestamp.timeIntervalSince1970 == 1_623_147_356)
    #expect(quote.lastTradeTime == nil)
    #expect(quote.lastPrice == Decimal(string: "1412.95000000000001"))
    #expect(quote.lastQuantity == 5)
    #expect(quote.buyQuantity == 0)
    #expect(quote.sellQuantity == 5191)
    #expect(quote.volume == 7_360_198)
    #expect(quote.averagePrice == Decimal(string: "1412.47"))
    #expect(quote.oi == 0)
    #expect(quote.oiDayHigh == Decimal(string: "12.5"))
    #expect(quote.oiDayLow == 0)
    #expect(quote.openInterest == nil)
    #expect(quote.netChange == Decimal(string: "-0.125"))
    #expect(quote.lowerCircuitLimit == Decimal(string: "1250.7"))
    #expect(quote.upperCircuitLimit == Decimal(string: "1528.6"))
    #expect(quote.ohlc.close == Decimal(string: "1389.65"))
    #expect(quote.depth.buy.first?.price == Decimal(string: "1412.9"))
    #expect(quote.depth.buy.first?.quantity == 40)
    #expect(quote.depth.buy.first?.orders == 3)
    #expect(quote.depth.sell.first?.price == Decimal(string: "1412.95"))
    #expect(quote.depth.sell.first?.quantity == 5191)
    #expect(quote.depth.sell.first?.orders == 13)
    #expect(await transport.requests.first?.url.path == "/oms/quote")
}

@Test func quoteTimestampsHonorExplicitOffsetsAndConfiguredTradingZone() async throws {
    let cases: [(String, String, Double)] = [
        ("2021-06-08 15:45:56", "Asia/Kolkata", 1_623_147_356),
        ("2021-06-08 15:45:56", "UTC", 1_623_167_156),
        ("2021-06-08 15:45:56", "America/New_York", 1_623_181_556),
        ("2021-06-08T15:45:56+05:30", "Pacific/Honolulu", 1_623_147_356),
        ("2021-06-08 15:45:56+0530", "UTC", 1_623_147_356),
        ("2021-06-08T10:15:56Z", "Asia/Kolkata", 1_623_147_356),
        ("2021-06-08T10:15:56.125Z", "Asia/Kolkata", 1_623_147_356.125),
        ("2021-06-08 15:45:56.125", "Asia/Kolkata", 1_623_147_356.125),
        ("2021-06-08T05:15:56-05:00", "Asia/Kolkata", 1_623_147_356),
    ]
    for (stamp, zone, expected) in cases {
        let body = fullEnvelope(
            fullQuote.replacingOccurrences(of: "2021-06-08 15:45:56", with: stamp)
                .replacingOccurrences(
                    of: #""last_trade_time":null"#, with: #""last_trade_time":"\#(stamp)""#,
                ),
        )
        let client = try KiteClient(
            apiKey: "key", accessToken: "token",
            configuration: KiteConfiguration(tradingTimeZone: TimeZone(identifier: zone)!),
            transport: ControlledHTTP(body),
        )
        let quote = try #require(try await client.quotes(instruments: [infy])[infy])
        #expect(quote.timestamp.timeIntervalSince1970 == expected)
        #expect(quote.lastTradeTime?.timeIntervalSince1970 == expected)
    }
}

@Test func snapshotLimitsRejectEmptyAndOversizedRequestsWithoutSending() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":{}}"#)
    let client = try quoteClient("", transport: transport)
    for count in [0, 501] {
        do {
            _ = try await client.quotes(instruments: Array(repeating: infy, count: count))
            Issue.record("Expected full-quote instrument count validation")
        } catch let KiteError.validation(field, _) { #expect(field == "instruments") }
    }
    for count in [0, 1001] {
        await #expect(throws: KiteError.self) {
            try await client.ohlc(instruments: Array(repeating: infy, count: count))
        }
        await #expect(throws: KiteError.self) {
            try await client.ltp(instruments: Array(repeating: infy, count: count))
        }
    }
    #expect(await transport.requests.isEmpty)
    #expect(try await client.quotes(instruments: Array(repeating: infy, count: 500)).isEmpty)
    #expect(try await client.ohlc(instruments: Array(repeating: infy, count: 1000)).isEmpty)
    #expect(try await client.ltp(instruments: Array(repeating: infy, count: 1000)).isEmpty)
}

@Test func malformedQuoteMapPreservesActualHTTPStatus() async throws {
    let transport = ControlledHTTP(
        #"{"status":"success","data":{"NSE:BAD:KEY":{"instrument_token":1,"last_price":2}}}"#,
        status: 201,
    )
    do {
        _ = try await quoteClient("", transport: transport).ltp(instruments: [infy])
        Issue.record("Expected malformed identity rejection")
    } catch let KiteError.decoding(status, message) {
        #expect(status == 201)
        #expect(message.contains("identity"))
    }
}

@Test func quoteModelsRejectMissingMalformedAndNullRequiredData() async throws {
    let required = [
        "instrument_token", "timestamp", "last_price", "last_quantity", "buy_quantity", "sell_quantity",
        "volume", "average_price", "oi", "oi_day_high", "oi_day_low", "net_change",
        "lower_circuit_limit", "upper_circuit_limit", "ohlc", "depth",
    ]
    let object = try #require(
        JSONSerialization.jsonObject(with: Data(fullQuote.utf8)) as? [String: Any],
    )
    for field in required {
        for replacement in [nil, NSNull(), "wrong"] as [Any?] {
            var malformed = object
            malformed[field] = replacement
            let data = try JSONSerialization.data(withJSONObject: malformed)
            let body = fullEnvelope(String(decoding: data, as: UTF8.self))
            do {
                _ = try await quoteClient(body).quotes(instruments: [infy])
                Issue.record("Expected required field rejection: \(field)")
            } catch let KiteError.decoding(status, message) {
                #expect(status == 200)
                #expect(message.contains(field))
            }
        }
    }
    let malformedQuotes = [
        fullQuote.replacingOccurrences(of: "408065", with: "4294967296"),
        fullQuote.replacingOccurrences(of: "408065", with: "-1"),
        fullQuote.replacingOccurrences(of: #""orders":13"#, with: #""orders":1.5"#),
        fullQuote.replacingOccurrences(of: #""quantity":5191"#, with: #""quantity":null"#),
        fullQuote.replacingOccurrences(of: #""low":1395.55"#, with: #""low":null"#),
        fullQuote.replacingOccurrences(
            of: #""last_trade_time":null"#, with: #""last_trade_time":12345"#,
        ),
    ]
    for quote in malformedQuotes {
        await #expect(throws: KiteError.self) {
            try await quoteClient(fullEnvelope(quote)).quotes(instruments: [infy])
        }
    }
    for body in [
        #"{"instrument_token":1}"#, #"{"instrument_token":1,"last_price":null}"#,
        #"{"instrument_token":1,"last_price":"1.5"}"#, #"{"instrument_token":1,"last_price":{}}"#,
    ] {
        await #expect(throws: KiteError.self) {
            try await quoteClient(fullEnvelope(body)).ltp(instruments: [infy])
        }
        await #expect(throws: KiteError.self) {
            try await quoteClient(fullEnvelope(body)).ohlc(instruments: [infy])
        }
    }
}

@Test func quoteModelsTolerateAdditionalFieldsAndOptionalOpenInterest() async throws {
    let body = fullQuote.replacingOccurrences(
        of: #""last_trade_time":null"#, with: #""future":{"field":1},"open_interest":123.125"#,
    )
    let quote = try #require(
        try await quoteClient(fullEnvelope(body)).quotes(instruments: [infy])[infy],
    )
    #expect(quote.openInterest == Decimal(string: "123.125"))
    #expect(quote.lastTradeTime == nil)
    let emptyDepth = fullQuote.replacingOccurrences(
        of: #"[{"price":1412.9,"quantity":40,"orders":3}]"#, with: "[]",
    )
    #expect(
        try await quoteClient(fullEnvelope(emptyDepth)).quotes(instruments: [infy])[infy]?.depth.buy
            == [],
    )
}

@Test func quoteTimestampsRejectInvalidCalendarDatesAndOffsets() async throws {
    for stamp in [
        "2021-02-29 12:00:00", "2021-06-08 24:00:00", "2021-06-08 12:60:00",
        "2021-06-08 12:00:60", "2021-6-08 12:00:00", "2021-06-08", "0000-01-01 12:00:00",
        "2021-06-08T12:00:00+05:60", "2021-06-08T12:00:00+24:00",
        "2021-06-08T12:00:00Zjunk", "2021-06-08T12:00:00Z\n",
    ] {
        let body = fullEnvelope(
            fullQuote.replacingOccurrences(
                of: "2021-06-08 15:45:56", with: stamp.replacingOccurrences(of: "\n", with: "\\n"),
            ),
        )
        await #expect(throws: KiteError.self) {
            try await quoteClient(body).quotes(instruments: [infy])
        }
    }
    let body = fullEnvelope(
        fullQuote.replacingOccurrences(of: "2021-06-08 15:45:56", with: "2021-03-14 02:30:00"),
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token",
        configuration: KiteConfiguration(tradingTimeZone: TimeZone(identifier: "America/New_York")!),
        transport: ControlledHTTP(body),
    )
    await #expect(throws: KiteError.self) { try await client.quotes(instruments: [infy]) }
}

@Test func snapshotFailuresKeepOneAttemptAndCancellationRecognizable() async throws {
    for endpoint in 0 ..< 3 {
        for status in [401, 429, 503] {
            let transport = ControlledHTTP(
                #"{"status":"error","error_type":"FutureError","message":"Rejected"}"#, status: status,
            )
            let client = try quoteClient("", transport: transport)
            do {
                switch endpoint {
                case 0: _ = try await client.quotes(instruments: [infy])
                case 1: _ = try await client.ohlc(instruments: [infy])
                default: _ = try await client.ltp(instruments: [infy])
                }
                Issue.record("Expected API rejection")
            } catch let KiteError.api(error) {
                #expect(error.statusCode == status)
                #expect(error.errorType == "FutureError")
                #expect(error.message == "Rejected")
            }
            #expect(await transport.requests.count == 1)
        }
        let transport = FailingHTTP()
        let client = try KiteClient(apiKey: "key", accessToken: "token", transport: transport)
        do {
            switch endpoint {
            case 0: _ = try await client.quotes(instruments: [infy])
            case 1: _ = try await client.ohlc(instruments: [infy])
            default: _ = try await client.ltp(instruments: [infy])
            }
            Issue.record("Expected transport failure")
        } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
        #expect(await transport.attempts == 1)
        let cancelled = try KiteClient(apiKey: "key", accessToken: "token", transport: CancelledHTTP())
        await #expect(throws: CancellationError.self) {
            switch endpoint {
            case 0: _ = try await cancelled.quotes(instruments: [infy])
            case 1: _ = try await cancelled.ohlc(instruments: [infy])
            default: _ = try await cancelled.ltp(instruments: [infy])
            }
        }
    }
}

@Test func snapshotsUseIsolatedReplacedSessionsAndConfiguredTimeout() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":{}}"#)
    let first = try KiteClient(
        apiKey: "first", accessToken: "old",
        configuration: KiteConfiguration(timeout: 7), transport: transport,
    )
    let second = try KiteClient(apiKey: "second", accessToken: "other", transport: transport)
    _ = try await first.quotes(instruments: [infy])
    _ = try await second.ohlc(instruments: [infy])
    try await first.replaceAccessToken("new")
    _ = try await first.ltp(instruments: [infy])
    try await first.replaceAccessToken(nil)
    await #expect(throws: KiteError.self) { try await first.ltp(instruments: [infy]) }
    let requests = await transport.requests
    #expect(
        requests.map { $0.headers["Authorization"] } == [
            "token first:old", "token second:other", "token first:new",
        ],
    )
    #expect(requests.first?.timeout == 7)
}
