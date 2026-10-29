//
//  HistoricalCandlesTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

private let historicalFrom = Date(timeIntervalSince1970: 1_513_308_300) // 2017-12-15 03:25Z
private let historicalTo = Date(timeIntervalSince1970: 1_513_308_600)
private let historicalRow = #"["2017-12-15T09:15:00+0530",1704.5,1705,1699.25,1702.8,2499]"#

private func historicalClient(_ rows: String, zone: String = "Asia/Kolkata") throws -> (
    KiteClient, ControlledHTTP,
) {
    let transport = ControlledHTTP(
        "{\"status\":\"success\",\"data\":{\"candles\":\(rows),\"future\":true}}",
    )
    let config = try KiteConfiguration(
        baseURL: URL(string: "https://sandbox.kite.trade")!, routePrefix: "/oms",
        tradingTimeZone: TimeZone(identifier: zone)!,
    )
    return try (
        KiteClient(
            apiKey: "fixture-key", accessToken: "fixture-token", configuration: config,
            transport: transport,
        ), transport,
    )
}

@Test func historicalReturnsDocumentedCandleAndEncodedBounds() async throws {
    let (client, transport) = try historicalClient("[\(historicalRow)]")
    let candles = try await client.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
    )
    let candle = try #require(candles.first)
    #expect(candles.count == 1)
    #expect(candle.timestamp == Date(timeIntervalSince1970: 1_513_309_500))
    #expect(candle.open == Decimal(string: "1704.5"))
    #expect(candle.high == 1705)
    #expect(candle.low == Decimal(string: "1699.25"))
    #expect(candle.close == Decimal(string: "1702.8"))
    #expect(candle.volume == 2499)
    #expect(candle.openInterest == nil)
    let request = try #require(await transport.requests.first)
    #expect(
        request.url.absoluteString
            == "https://sandbox.kite.trade/oms/instruments/historical/5633/minute?from=2017-12-15%2008%3A55%3A00&to=2017-12-15%2009%3A00%3A00&continuous=0&oi=0",
    )
    #expect(request.method == .get)
    #expect(request.body == nil)
    #expect(request.headers["Authorization"] == "token fixture-key:fixture-token")
    #expect(request.headers["X-Kite-Version"] == "3")
}

@Test func historicalRequiresOIOnlyWhenRequested() async throws {
    let (client, _) = try historicalClient("[\(historicalRow)]")
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .day, from: historicalFrom, to: historicalTo, oi: true,
        )
        Issue.record("Missing requested OI must fail")
    } catch let KiteError.decoding(status, _) { #expect(status == 200) }
}

@Test(arguments: ["2017-12-15T09:15:00", "2017-12-15 09:15:00"])
func historicalOffsetlessTimestampsUseConfiguredTradingZone(timestamp: String) async throws {
    let row = historicalRow.replacingOccurrences(of: "2017-12-15T09:15:00+0530", with: timestamp)
    let (india, _) = try historicalClient("[\(row)]")
    let (utc, _) = try historicalClient("[\(row)]", zone: "UTC")
    let a = try await india.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
    )
    let b = try await utc.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
    )
    #expect(a.first?.timestamp == Date(timeIntervalSince1970: 1_513_309_500))
    #expect(b.first?.timestamp == Date(timeIntervalSince1970: 1_513_329_300))
}

@Test(arguments: ["token", "reverse", "nonfinite", "continuous-minute", "out-of-range"])
func historicalRejectsInvalidRequestBeforeTransport(problem: String) async throws {
    let (client, transport) = try historicalClient("[]")
    do {
        _ = try await client.historicalCandles(
            instrumentToken: problem == "token" ? 0 : 5633, interval: .minute,
            from: problem == "nonfinite" ? Date(timeIntervalSince1970: .nan) : historicalFrom,
            to: problem == "reverse"
                ? historicalFrom.addingTimeInterval(-1)
                : (problem == "out-of-range" ? Date(timeIntervalSince1970: 1e15) : historicalTo),
            continuous: problem == "continuous-minute",
        )
        Issue.record("Invalid request must fail: \(problem)")
    } catch KiteError.validation {}
    #expect(await transport.requests.isEmpty)
}

@Test(arguments: [
    #"["2017-12-15T09:15:00+0530",1,2,0,1,-1]"#, #"["2017-12-15T09:15:00+0530",1,2,0,1,1,-1]"#,
])
func historicalRejectsNegativeCounts(row: String) async throws {
    let (client, _) = try historicalClient("[\(row)]")
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Negative volume/OI must fail")
    } catch KiteError.decoding {}
}

@Test(arguments: KiteHistoricalInterval.allCases)
func historicalSupportsEveryIntervalAndOI(interval: KiteHistoricalInterval) async throws {
    let row = historicalRow.dropLast() + ",13667775]"
    let (client, transport) = try historicalClient("[\(row)]", zone: "UTC")
    let candles = try await client.historicalCandles(
        instrumentToken: 12_517_890, interval: interval, from: historicalFrom, to: historicalTo,
        continuous: interval == .day, oi: true,
    )
    #expect(candles.first?.openInterest == 13_667_775)
    let request = try #require(await transport.requests.first)
    #expect(request.url.path == "/oms/instruments/historical/12517890/\(interval.rawValue)")
    let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems
    #expect(
        query == [
            URLQueryItem(name: "from", value: "2017-12-15 03:25:00"),
            URLQueryItem(name: "to", value: "2017-12-15 03:30:00"),
            URLQueryItem(name: "continuous", value: interval == .day ? "1" : "0"),
            URLQueryItem(name: "oi", value: "1"),
        ],
    )
}

@Test(arguments: [
    "2017-12-15T09:15:00+0530", "2017-12-15T09:15:00+05:30", "2017-12-15 09:15:00+0530",
    "2017-12-15T03:45:00Z", "2017-12-14T22:45:00-0500",
])
func historicalHonorsExplicitOffsets(timestamp: String) async throws {
    let row = historicalRow.replacingOccurrences(of: "2017-12-15T09:15:00+0530", with: timestamp)
    let (client, _) = try historicalClient("[\(row)]", zone: "America/Los_Angeles")
    let result = try await client.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
    )
    #expect(result.first?.timestamp == Date(timeIntervalSince1970: 1_513_309_500))
}

@Test func historicalPreservesFinancialPrecisionAndOptionalOIAndEmptyResults() async throws {
    let row = #"["2017-12-15T03:45:00.125Z",123456789.123456789,2,0,-0.00000001,0,0]"#
    let (client, _) = try historicalClient("[\(row)]")
    let result = try await client.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalFrom,
    )
    #expect(result.first?.open == Decimal(string: "123456789.123456789"))
    #expect(result.first?.close == Decimal(string: "-0.00000001"))
    #expect(result.first?.timestamp == Date(timeIntervalSince1970: 1_513_309_500.125))
    #expect(result.first?.openInterest == 0)
    let (empty, _) = try historicalClient("[]")
    #expect(
        try await empty.historicalCandles(
            instrumentToken: 5633, interval: .day, from: historicalFrom, to: historicalFrom,
        ).isEmpty,
    )
}

@Test(arguments: Array(0 ... 6), ["null", "wrong", "string", "truncated"])
func historicalRejectsMalformedArrayFields(index: Int, corruption: String) async throws {
    var fields = [#""2017-12-15T09:15:00+0530""#, "1", "2", "0", "1", "1", "5"]
    if corruption == "truncated" {
        fields = Array(fields.prefix(index))
    } else {
        fields[index] =
            corruption == "null" ? "null" : (corruption == "string" ? #""invalid""# : "true")
    }
    let (client, _) = try historicalClient("[[\(fields.joined(separator: ","))]]")
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo, oi: true,
        )
        Issue.record("Malformed candle must fail")
    } catch let KiteError.decoding(status, _) { #expect(status == 200) }
}

@Test(arguments: [
    "2017-02-29T09:15:00+0530", "2017-12-15T24:00:00Z", "2017-12-15T09:60:00Z",
    "2017-12-15T09:15:60Z", "2017-12-15T09:15:00+0560", "2017-12-15T09:15:00+2500", "2017-12-15",
    "garbage", "2017-12-15T09:15:00Ztrailing", "2026-03-08 02:30:00",
])
func historicalRejectsMalformedTimestamps(timestamp: String) async throws {
    let row = historicalRow.replacingOccurrences(of: "2017-12-15T09:15:00+0530", with: timestamp)
    let (client, _) = try historicalClient("[\(row)]", zone: "America/New_York")
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Invalid timestamp must fail")
    } catch KiteError.decoding {}
}

@Test(arguments: [
    "null", "{}", "[null]", "[{}]", #"[["2017-12-15T09:15:00Z",1,2,0,1,1,2,3]]"#,
    #"[["2017-12-15T09:15:00Z",1,2,0,1,1.5]]"#,
    #"[["2017-12-15T09:15:00Z",1,2,0,1,9223372036854775808]]"#,
])
func historicalRejectsMalformedCollectionsAndQuantities(rows: String) async throws {
    let (client, _) = try historicalClient(rows)
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Malformed candle collection must fail")
    } catch KiteError.decoding {}
}

@Test(arguments: [
    #"{"status":"success","data":{}}"#, #"{"status":"success","data":null}"#,
    #"{"status":"unexpected","data":{"candles":[]}}"#,
])
func historicalRejectsMalformedEnvelope(body: String) async throws {
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token", configuration: .sandbox,
        transport: ControlledHTTP(body),
    )
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Malformed envelope must fail")
    } catch KiteError.decoding {}
}

@Test(arguments: [401, 429, 503])
func historicalPreservesAPIFailuresWithoutRetry(status: Int) async throws {
    let transport = ControlledHTTP(
        #"{"status":"error","error_type":"FutureHistoricalException","message":"Unavailable"}"#,
        status: status,
    )
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token", configuration: .sandbox,
        transport: transport,
    )
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Expected API error")
    } catch let KiteError.api(error) {
        #expect(error.statusCode == status)
        #expect(error.errorType == "FutureHistoricalException")
        #expect(error.message == "Unavailable")
    }
    #expect(await transport.requests.count == 1)
}

@Test func historicalPreservesTransportFailureAndCancellation() async throws {
    let transport = FailingHTTP()
    let client = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token", configuration: .sandbox,
        transport: transport,
    )
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Expected transport error")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    #expect(await transport.attempts == 1)
    let cancelled = try KiteClient(
        apiKey: "fixture-key", accessToken: "fixture-token", configuration: .sandbox,
        transport: CancelledHTTP(),
    )
    await #expect(throws: CancellationError.self) {
        try await cancelled.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
    }
}

@Test func historicalIsolatesSessionsAndUsesReplacementCredentials() async throws {
    let transport = ControlledHTTP(#"{"status":"success","data":{"candles":[]}}"#)
    let first = try KiteClient(
        apiKey: "first", accessToken: "old", configuration: .sandbox, transport: transport,
    )
    let second = try KiteClient(
        apiKey: "second", accessToken: "other", configuration: .sandbox, transport: transport,
    )
    async let a = first.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
    )
    async let b = second.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
    )
    _ = try await (a, b)
    try await first.replaceAccessToken("new")
    _ = try await first.historicalCandles(
        instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
    )
    let requests = await transport.requests
    #expect(
        Set(requests.prefix(2).compactMap { $0.headers["Authorization"] }) == [
            "token first:old", "token second:other",
        ],
    )
    #expect(requests.last?.headers["Authorization"] == "token first:new")
    try await first.replaceAccessToken(nil)
    do {
        _ = try await first.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Expected missing authentication")
    } catch let KiteError.validation(field, _) { #expect(field == "accessToken") }
    #expect(await transport.requests.count == 3)
}

@Test func historicalRejectsTimestampTrailingNewline() async throws {
    let row = historicalRow.replacingOccurrences(of: "+0530", with: #"+0530\n"#)
    let (client, _) = try historicalClient("[\(row)]")
    do {
        _ = try await client.historicalCandles(
            instrumentToken: 5633, interval: .minute, from: historicalFrom, to: historicalTo,
        )
        Issue.record("Timestamp must consume the full string")
    } catch KiteError.decoding {}
}
