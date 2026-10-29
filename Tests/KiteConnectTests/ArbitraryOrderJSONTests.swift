//
//  ArbitraryOrderJSONTests.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

private let nestedOrderJSON = #"{"values":[null,true,false,"123.45","true",123.45000000000000000001,-0.00000000000000000001,9007199254740993,1.234567890123456789e-10,{"emptyObject":{},"emptyArray":[],"child":[{"amount":0.10000000000000000001}]}]}"#

private func arbitraryJSONClient(_ body: String) throws -> (KiteClient, ControlledHTTP) {
    let transport = ControlledHTTP(body)
    return try (KiteClient(apiKey: "key", accessToken: "token", transport: transport), transport)
}

@Test func `arbitrary order JSON preserves nested metadata and rejection details`() async throws {
    let body = orderBookJSON.replacingOccurrences(of: #""meta": {}"#, with: #""meta": \#(nestedOrderJSON)"#)
    let (reader, _) = try arbitraryJSONClient(body)
    let metadata = try #require(try await reader.orders().first?.meta)

    #expect(metadata == expectedMetadata)

    let (submitter, _) = try arbitraryJSONClient(rejectionEnvelope(nestedOrderJSON))
    let details = try await rejectionDetails(submitter)

    #expect(details == expectedDetails)
}

private func rejectionEnvelope(_ value: String) -> String {
    #"{"status":"success","data":[{"error":{"code":400,"error_type":"MarginException","message":"Rejected","data":\#(value)}}]}"#
}

private func rejectionDetails(_ client: KiteClient) async throws -> KiteOrderMutationJSONValue {
    var order = KiteOrderPlacement(
        tradingSymbol: "NIFTY", exchange: .nfo, transactionType: .buy,
        orderType: .market, quantity: 10000, product: .nrml,
    )
    order.autoslice = true
    let result = try await client.placeOrder(order)
    guard case let .slices(slices) = result, case let .rejected(rejection) = slices.first else {
        Issue.record("Expected a rejected slice with preserved JSON details")
        throw CancellationError()
    }
    return rejection.data
}

@Test(arguments: [
    ("null", nil as KiteOrderMetadata?, KiteOrderMutationJSONValue.null),
    ("true", .bool(true), .bool(true)),
    ("false", .bool(false), .bool(false)),
    (#""123.45""#, .string("123.45"), .string("123.45")),
    (#""true""#, .string("true"), .string("true")),
    ("0.10000000000000000001", .number(Decimal(string: "0.10000000000000000001")!),
     .number(Decimal(string: "0.10000000000000000001")!)),
    ("[]", .array([]), .array([])),
    ("{}", .object([:]), .object([:])),
])
func `arbitrary order JSON preserves root values`(
    value: String, metadata: KiteOrderMetadata?, details: KiteOrderMutationJSONValue,
) async throws {
    let body = orderBookJSON.replacingOccurrences(of: #""meta": {}"#, with: #""meta": \#(value)"#)
    let (reader, _) = try arbitraryJSONClient(body)
    let order = try #require(try await reader.orders().first)
    #expect(order.meta == metadata)
    let (submitter, _) = try arbitraryJSONClient(rejectionEnvelope(value))
    #expect(try await rejectionDetails(submitter) == details)
}

@Test(arguments: [#"{"nested":[1e999]}"#, #"{"nested":[true,}"#, #"{"nested":NaN}"#])
func `arbitrary order JSON rejects malformed nested values`(value: String) async throws {
    let body = orderBookJSON.replacingOccurrences(of: #""meta": {}"#, with: #""meta": \#(value)"#)
    let readerTransport = ControlledHTTP(body, status: 202)
    let reader = try KiteClient(apiKey: "key", accessToken: "token", transport: readerTransport)
    do {
        _ = try await reader.orders()
        Issue.record("Expected malformed metadata to fail decoding")
    } catch let KiteError.decoding(status, _) {
        #expect(status == 202)
    }
    #expect(await readerTransport.requests.count == 1)

    let mutationTransport = ControlledHTTP(rejectionEnvelope(value), status: 202)
    let submitter = try KiteClient(apiKey: "key", accessToken: "token", transport: mutationTransport)
    do {
        _ = try await rejectionDetails(submitter)
        Issue.record("Expected malformed rejection details to retain uncertainty")
    } catch let KiteError.uncertainOutcome(.decoding(status, _)) {
        #expect(status == 202)
    }
    #expect(await mutationTransport.requests.count == 1)
}

@Test func `arbitrary order JSON requires rejection data but allows absent metadata`() async throws {
    let body = orderBookJSON.replacingOccurrences(of: #""meta": {},"#, with: "")
    let (reader, _) = try arbitraryJSONClient(body)
    #expect(try await reader.orders().first?.meta == nil)
    let missingDetails = rejectionEnvelope("null").replacingOccurrences(of: #","data":null"#, with: "")
    let (submitter, transport) = try arbitraryJSONClient(missingDetails)
    do {
        _ = try await rejectionDetails(submitter)
        Issue.record("Missing required slice rejection data must fail")
    } catch let KiteError.uncertainOutcome(.decoding(status, _)) {
        #expect(status == 200)
    }
    #expect(await transport.requests.count == 1)
}

private let expectedMetadata: KiteOrderMetadata = .object([
    "values": .array([
        .null, .bool(true), .bool(false), .string("123.45"), .string("true"),
        .number(Decimal(string: "123.45000000000000000001")!),
        .number(Decimal(string: "-0.00000000000000000001")!),
        .number(Decimal(string: "9007199254740993")!),
        .number(Decimal(string: "0.0000000001234567890123456789")!),
        .object([
            "emptyObject": .object([:]), "emptyArray": .array([]),
            "child": .array([
                .object(["amount": .number(Decimal(string: "0.10000000000000000001")!)]),
            ]),
        ]),
    ]),
])

private let expectedDetails: KiteOrderMutationJSONValue = .object([
    "values": .array([
        .null, .bool(true), .bool(false), .string("123.45"), .string("true"),
        .number(Decimal(string: "123.45000000000000000001")!),
        .number(Decimal(string: "-0.00000000000000000001")!),
        .number(Decimal(string: "9007199254740993")!),
        .number(Decimal(string: "0.0000000001234567890123456789")!),
        .object([
            "emptyObject": .object([:]), "emptyArray": .array([]),
            "child": .array([
                .object(["amount": .number(Decimal(string: "0.10000000000000000001")!)]),
            ]),
        ]),
    ]),
])
