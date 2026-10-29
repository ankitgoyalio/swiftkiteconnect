//
//  InstrumentsTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation
import KiteConnect
import Testing

private let instrumentHeader =
    "instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,exchange"
private let equityRecord = "408065,1594,INFY,INFOSYS,1412.95000000000001,,,0.05,1,EQ,NSE,NSE"

@Test func instrumentsDownloadsTypedCatalogueWithoutSandboxOMSPrefix() async throws {
    let transport = ControlledHTTP(instrumentHeader + "\n" + equityRecord + "\n")
    let client = try KiteClient(apiKey: "sandboxdemo", configuration: .sandbox, transport: transport)
    let instruments = try await client.instruments()
    let instrument = try #require(instruments.first)
    #expect(instruments.count == 1)
    #expect(instrument.instrumentToken == 408_065)
    #expect(instrument.exchangeToken == 1594)
    #expect(instrument.tradingSymbol == "INFY")
    #expect(instrument.name == "INFOSYS")
    #expect(instrument.lastPrice == Decimal(string: "1412.95000000000001"))
    #expect(instrument.expiry == nil)
    #expect(instrument.strike == nil)
    #expect(instrument.tickSize == Decimal(string: "0.05"))
    #expect(instrument.lotSize == 1)
    #expect(instrument.instrumentType == .equity)
    #expect(instrument.segment == "NSE")
    #expect(instrument.exchange == .nse)
    let request = try #require(await transport.requests.first)
    #expect(request.url.absoluteString == "https://sandbox.kite.trade/instruments")
    #expect(request.method == .get)
    #expect(request.headers["X-Kite-Version"] == "3")
    #expect(request.headers["Authorization"] == nil)
}

@Test func instrumentsSupportsExchangeDateOnlyExpiryAndPersistentIdentity() async throws {
    let transport = ControlledHTTP(
        instrumentHeader
            + "\n5720578,22346,NIFTY159500CE,,23.10,2015-12-31,9500.25,0.05,75,NEW,NFO-NEW,NFO",
    )
    let client = try KiteClient(
        apiKey: "key", accessToken: "token", configuration: .sandbox, transport: transport,
    )
    let instrument = try #require(try await client.instruments(exchange: .nfo).first)
    #expect(instrument.name == nil)
    #expect(try instrument.expiry == KiteDateOnly("2015-12-31"))
    #expect(instrument.expiry?.description == "2015-12-31")
    #expect(instrument.expiry?.year == 2015)
    #expect(instrument.expiry?.month == 12)
    #expect(instrument.expiry?.day == 31)
    #expect(instrument.strike == Decimal(string: "9500.25"))
    #expect(instrument.instrumentType == .unknown("NEW"))
    #expect(instrument.segment == "NFO-NEW")
    #expect(
        try instrument.identity
            == KiteInstrumentIdentity(exchange: .nfo, tradingSymbol: "NIFTY159500CE"),
    )
    #expect(instrument.identity.description == "NFO:NIFTY159500CE")
    let request = try #require(await transport.requests.first)
    #expect(request.url.path == "/instruments/NFO")
    #expect(request.headers["Authorization"] == "token key:token")
    let reused = ControlledHTTP(
        instrumentHeader + "\n5720578,22346,NIFTYNEWCE,,23.10,2028-02-29,9500.25,0.05,75,CE,NFO-OPT,NFO",
    )
    let newerClient = try KiteClient(apiKey: "key", transport: reused)
    let newer = try #require(try await newerClient.instruments().first)
    #expect(newer.instrumentToken == instrument.instrumentToken)
    #expect(newer.identity != instrument.identity)
}

@Test func instrumentsParsesQuotedEscapedMultilineAndReorderedCSV() async throws {
    let csv =
        "\u{FEFF}exchange,tradingsymbol,instrument_token,exchange_token,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,future\r\nNSE,\"A,B\",408065,1594,\"Company, \"\"Quoted\"\"\r\nLimited\",-12.125,,,0.0001,1,NEW,NSE,ignored\r\n\r\n"
    let client = try KiteClient(apiKey: "key", transport: ControlledHTTP(csv))
    let instrument = try #require(try await client.instruments().first)
    #expect(instrument.tradingSymbol == "A,B")
    #expect(instrument.name == "Company, \"Quoted\"\r\nLimited")
    #expect(instrument.lastPrice == Decimal(string: "-12.125"))
    #expect(instrument.tickSize == Decimal(string: "0.0001"))
}

@Test func instrumentsRejectsMalformedRecordsAndMissingRequiredData() async throws {
    let invalidBodies = [
        "", "name\nINFOSYS", instrumentHeader + ",exchange\n" + equityRecord + ",NSE",
        instrumentHeader + "\n" + equityRecord + ",extra",
        instrumentHeader + "\n408065,1594,INFY",
        instrumentHeader + "\n"
            + equityRecord.replacingOccurrences(of: ",INFOSYS,", with: ",\"unterminated,"),
        instrumentHeader + "\n"
            + equityRecord.replacingOccurrences(of: ",INFOSYS,", with: ",bad\"quote,"),
        instrumentHeader + "\n"
            + equityRecord.replacingOccurrences(of: ",INFOSYS,", with: ",\"closed\"junk,"),
        instrumentHeader + "\n"
            + equityRecord.replacingOccurrences(of: "1412.95000000000001", with: "1oops"),
        instrumentHeader + "\n"
            + equityRecord.replacingOccurrences(of: "1412.95000000000001", with: "NaN"),
        instrumentHeader + "\n"
            + equityRecord.replacingOccurrences(of: "1412.95000000000001", with: "1e999"),
        instrumentHeader + "\n" + equityRecord.replacingOccurrences(of: "408065", with: "4294967296"),
        instrumentHeader + "\n" + equityRecord.replacingOccurrences(of: ",,,", with: ",2027-02-29,,"),
        instrumentHeader + "\n" + equityRecord.replacingOccurrences(of: ",,,", with: ",1900-02-29,,"),
        instrumentHeader + "\n" + equityRecord.replacingOccurrences(of: ",,,", with: ",0000-01-01,,"),
        instrumentHeader + "\n" + equityRecord.replacingOccurrences(of: ",,,", with: ",2026-02-30,,"),
        instrumentHeader + "\n" + equityRecord.replacingOccurrences(of: ",,,", with: ",2026-1-01,,"),
    ]
    for body in invalidBodies {
        let client = try KiteClient(apiKey: "key", transport: ControlledHTTP(body))
        do {
            _ = try await client.instruments()
            Issue.record("Expected malformed CSV rejection: \(body)")
        } catch let KiteError.decoding(status, message) {
            #expect(status == 200)
            #expect(!message.isEmpty)
        }
    }
    let columns = instrumentHeader.components(separatedBy: ",")
    let values = equityRecord.components(separatedBy: ",")
    for index in columns.indices {
        let missing = columns.enumerated().filter { $0.offset != index }.map(\.element).joined(
            separator: ",",
        )
        let client = try KiteClient(apiKey: "key", transport: ControlledHTTP(missing))
        await #expect(throws: KiteError.self) { try await client.instruments() }
        if !["name", "expiry", "strike"].contains(columns[index]) {
            var blank = values
            blank[index] = ""
            let client = try KiteClient(
                apiKey: "key",
                transport: ControlledHTTP(instrumentHeader + "\n" + blank.joined(separator: ",")),
            )
            await #expect(throws: KiteError.self) { try await client.instruments() }
        }
    }
}

@Test func instrumentsValidatesExchangeAndPreservesSingleAttemptErrors() async throws {
    let transport = ControlledHTTP(instrumentHeader)
    let client = try KiteClient(apiKey: "key", transport: transport)
    for exchange in ["", "NSE/BSE", "..", "NSE?x=1", "NSE#x", " NSE", "NSE\n", "NSE%2FBSE"] {
        do {
            _ = try await client.instruments(exchange: .unknown(exchange))
            Issue.record("Expected validation")
        } catch let KiteError.validation(field, _) { #expect(field == "exchange") }
    }
    #expect(await transport.requests.isEmpty)
    #expect(try await client.instruments().isEmpty)
    for status in [401, 429, 503] {
        let failure = ControlledHTTP(
            #"{"status":"error","error_type":"NewError","message":"Unavailable"}"#, status: status,
        )
        let client = try KiteClient(apiKey: "key", transport: failure)
        do {
            _ = try await client.instruments()
            Issue.record("Expected API error")
        } catch let KiteError.api(error) {
            #expect(error.statusCode == status)
            #expect(error.errorType == "NewError")
            #expect(error.message == "Unavailable")
        }
        #expect(await failure.requests.count == 1)
    }
    let failure = FailingHTTP()
    let failed = try KiteClient(apiKey: "key", transport: failure)
    do {
        _ = try await failed.instruments()
        Issue.record("Expected transport error")
    } catch let KiteError.transport(code, _) { #expect(code == URLError.timedOut.rawValue) }
    #expect(await failure.attempts == 1)
    let cancelled = try KiteClient(apiKey: "key", transport: CancelledHTTP())
    await #expect(throws: CancellationError.self) { try await cancelled.instruments() }
}

@Test func instrumentsUsesReplacedIsolatedSessions() async throws {
    let transport = ControlledHTTP(instrumentHeader)
    let first = try KiteClient(apiKey: "first", accessToken: "old", transport: transport)
    let second = try KiteClient(apiKey: "second", accessToken: "other", transport: transport)
    _ = try await first.instruments()
    _ = try await second.instruments()
    try await first.replaceAccessToken("new")
    _ = try await first.instruments()
    try await first.replaceAccessToken(nil)
    _ = try await first.instruments()
    let requests = await transport.requests
    #expect(
        requests.map { $0.headers["Authorization"] } == [
            "token first:old", "token second:other", "token first:new", nil,
        ],
    )
}

private struct InstrumentBytesHTTP: KiteHTTPTransport {
    let bytes: Data
    func send(_: KiteHTTPRequest) async throws -> KiteHTTPResponse {
        KiteHTTPResponse(statusCode: 200, body: bytes)
    }
}

@Test func instrumentsRejectsInvalidUTF8() async throws {
    let client = try KiteClient(
        apiKey: "key", transport: InstrumentBytesHTTP(bytes: Data([0xFF, 0xFE])),
    )
    do {
        _ = try await client.instruments()
        Issue.record("Expected UTF-8 rejection")
    } catch let KiteError.decoding(status, message) {
        #expect(status == 200)
        #expect(message.contains("UTF-8"))
    }
}

/// Explicit opt-in; routine protocol tests never contact remote services.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KITE_SANDBOX_INSTRUMENT_SMOKE"] == "1"))
func instrumentsPublicSandboxSmoke() async throws {
    let client = try KiteClient(apiKey: "sandboxdemo", configuration: .sandbox)
    let instruments = try await client.instruments(exchange: .nse)
    #expect(!instruments.isEmpty)
    #expect(instruments.allSatisfy { $0.exchange == .nse })
    print(
        "SANDBOX instrument SDK parse succeeded: NSE records=\(instruments.count); no authenticated session",
    )
}

@Test func instrumentsRejectsDecimalPrecisionLoss() async throws {
    let raw = equityRecord.replacingOccurrences(
        of: "1412.95000000000001", with: "123456789012345678901234567890123456789.123",
    )
    let client = try KiteClient(
        apiKey: "key", transport: ControlledHTTP(instrumentHeader + "\n" + raw),
    )
    do {
        _ = try await client.instruments()
        Issue.record("Expected rejection rather than rounded financial data")
    } catch let KiteError.decoding(_, message) { #expect(message.contains("last_price")) }
}

@Test(arguments: ["2000-02-29", "2028-02-29", "2026-12-31"])
func instrumentsExpiryIsIndependentOfConfiguredTimeZone(expiry: String) async throws {
    let csv =
        instrumentHeader + "\n" + equityRecord.replacingOccurrences(of: ",,,", with: ",\(expiry),,")
    for zone in ["Pacific/Honolulu", "Asia/Kolkata", "Pacific/Kiritimati"] {
        let client = try KiteClient(
            apiKey: "key", configuration: KiteConfiguration(tradingTimeZone: TimeZone(identifier: zone)!),
            transport: ControlledHTTP(csv),
        )
        #expect(try await client.instruments().first?.expiry?.description == expiry)
    }
}

@Test func instrumentsReusesOpenExchangeAndInstrumentTypeValues() async throws {
    let csv =
        instrumentHeader + "\n"
            + equityRecord.replacingOccurrences(of: ",NSE,NSE", with: ",NEWSEG,NEWEXCHANGE")
    let client = try KiteClient(apiKey: "key", transport: ControlledHTTP(csv))
    let instrument = try #require(try await client.instruments().first)
    #expect(instrument.exchange == KiteExchange.unknown("NEWEXCHANGE"))
    #expect(instrument.identity.exchange == KiteExchange.unknown("NEWEXCHANGE"))
    #expect(instrument.instrumentType == KiteInstrumentType.equity)
}
