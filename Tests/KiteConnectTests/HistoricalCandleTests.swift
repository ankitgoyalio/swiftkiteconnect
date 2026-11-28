import Foundation
import KiteConnect
import Testing

struct HistoricalCandleTests {
    @Test func fetchesMinuteCandlesInExchangeTime() async throws {
        // First two rows of historical_minute.json:
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/historical_minute.json
        let fixture = try HTTPStub.fixture("historical_minute.json")
        let from = Date(timeIntervalSince1970: 1_513_309_500)
        let to = Date(timeIntervalSince1970: 1_513_309_800)

        try await HTTPStub.withSession { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/kite/instruments/historical/5633/minute")
            #expect(request.value(forHTTPHeaderField: "X-Kite-Version") == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "token test-key:test-token")
            try #expect(HTTPStub.body(of: request) == nil)
            let url = try #require(request.url)
            let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            #expect(Set(query) == [
                URLQueryItem(name: "from", value: "2017-12-15 09:15:00"),
                URLQueryItem(name: "to", value: "2017-12-15 09:20:00"),
            ])
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(
                apiKey: "test-key",
                accessToken: "test-token",
                baseURL: baseURL.appendingPathComponent("kite", isDirectory: true),
                session: session
            )
            let candles = try await kite.historicalCandles(instrumentToken: 5633, interval: .minute, from: from, to: to)

            #expect(candles.map(\.timestamp) == [from, Date(timeIntervalSince1970: 1_513_309_560)])
            let candle = try #require(candles.first)
            #expect(candle.open == 1704.5)
            #expect(candle.high == 1705)
            #expect(candle.low == 1699.25)
            #expect(candle.close == 1702.8)
            #expect(candle.volume == 2499)
            #expect(candles.allSatisfy { $0.openInterest == nil })
        }
    }

    @Test func fetchesCandlesWithOpenInterest() async throws {
        // First two rows of historical_oi.json:
        // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/historical_oi.json
        let fixture = try HTTPStub.fixture("historical_oi.json")
        let from = Date(timeIntervalSince1970: 1_575_431_100)
        let to = Date(timeIntervalSince1970: 1_575_431_400)

        try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/instruments/historical/12517890/minute")
            let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            #expect(Set(query) == [
                URLQueryItem(name: "from", value: "2019-12-04 09:15:00"),
                URLQueryItem(name: "to", value: "2019-12-04 09:20:00"),
                URLQueryItem(name: "continuous", value: "0"),
                URLQueryItem(name: "oi", value: "1"),
            ])
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            let candles = try await kite.historicalCandles(
                instrumentToken: 12517890,
                interval: .minute,
                from: from,
                to: to,
                continuous: false,
                includeOpenInterest: true
            )

            #expect(candles.map(\.timestamp) == [from, Date(timeIntervalSince1970: 1_575_431_160)])
            #expect(candles.map(\.openInterest) == [13_667_775, 13_667_775])
            let candle = try #require(candles.first)
            #expect(candle.open == 12009.9)
            #expect(candle.high == 12019.35)
            #expect(candle.low == 12001.25)
            #expect(candle.close == 12001.5)
            #expect(candle.volume == 163275)
        }
    }

    @Test func requestsContinuousDailyCandles() async throws {
        let fixture = Data(#"{"status":"success","data":{"candles":[]}}"#.utf8)
        let date = Date(timeIntervalSince1970: 1_575_431_100)

        try await HTTPStub.withSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/instruments/historical/12517890/day")
            let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            #expect(Set(query) == [
                URLQueryItem(name: "from", value: "2019-12-04 09:15:00"),
                URLQueryItem(name: "to", value: "2019-12-04 09:15:00"),
                URLQueryItem(name: "continuous", value: "1"),
                URLQueryItem(name: "oi", value: "0"),
            ])
            return .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            let candles = try await kite.historicalCandles(
                instrumentToken: 12517890,
                interval: .day,
                from: date,
                to: date,
                continuous: true,
                includeOpenInterest: false
            )
            #expect(candles.isEmpty)
        }
    }

    @Test func rejectsInvalidCandleTimestamp() async throws {
        let fixture = Data("""
            {"status":"success","data":{"candles":[["2017-02-31T09:15:00+0530",1,2,1,2,3]]}}
            """.utf8)
        let date = Date(timeIntervalSince1970: 1_513_309_500)

        try await HTTPStub.withSession { _ in
            .init(statusCode: 200, body: fixture)
        } operation: { session, baseURL in
            let kite = KiteConnectClient(apiKey: "test-key", accessToken: "test-token", baseURL: baseURL, session: session)
            do {
                _ = try await kite.historicalCandles(instrumentToken: 5633, interval: .minute, from: date, to: date)
                Issue.record("Expected a candle decoding error")
            } catch KiteError.decoding(let error) {
                guard case DecodingError.dataCorrupted = error else {
                    Issue.record("Expected an invalid timestamp")
                    return
                }
            }
        }
    }
}
