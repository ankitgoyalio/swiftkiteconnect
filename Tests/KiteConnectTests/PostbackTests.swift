import Foundation
import KiteConnect
import Testing

struct PostbackTests {
    // Zerodha's postback.json, with only the checksum replaced:
    // https://github.com/zerodha/kiteconnect-mocks/blob/c7a81238f93b4057c07257823b1bfaf30cba9ae5/postback.json
    // The replacement was computed using:
    // printf '%s' '2203030003089322022-03-03 09:24:25postback-test-secret' | openssl dgst -sha256
    private let apiSecret = "postback-test-secret"

    @Test func decodesTheRawHTTPBody() throws {
        let postback = try Postback.decode(HTTPStub.fixture("postback.json"))

        #expect(postback.orderID == "220303000308932")
        #expect(postback.orderTimestamp == "2022-03-03 09:24:25")
        #expect(postback.appID == 1234)
        #expect(postback.status == "COMPLETE")
        #expect(postback.tradingSymbol == "SBIN")
        #expect(postback.instrumentToken == 779521)
        #expect(postback.averagePrice == 470)
        #expect(postback.filledQuantity == 1)
        #expect(postback.unfilledQuantity == 0)
        #expect(postback.parentOrderID == nil)
        #expect(postback.statusMessage == nil)
        #expect(postback.meta == .object([:]))
    }

    @Test func verifiesThePinnedChecksum() throws {
        let postback = try Postback.decode(HTTPStub.fixture("postback.json"))

        #expect(postback.verifyChecksum(apiSecret: apiSecret))
        #expect(!postback.verifyChecksum(apiSecret: "different-secret"))
    }

    @Test(arguments: [
        (#""order_id": "220303000308932""#, #""order_id": "0220303000308932""#),
        (#""order_timestamp": "2022-03-03 09:24:25""#, #""order_timestamp": "2022-03-03 09:24:25 ""#),
        ("e9a41f12daa83defa3d25fc9f0636228811f66b46fea153768b29dcddb653b0a",
         "e9a41f12daa83defa3d25fc9f0636228811f66b46fea153768b29dcddb653b0b"),
        ("e9a41f12daa83defa3d25fc9f0636228811f66b46fea153768b29dcddb653b0a",
         "e9a41f12daa83defa3d25fc9f0636228811f66b46fea153768b29dcddb653b0x"),
        ("e9a41f12daa83defa3d25fc9f0636228811f66b46fea153768b29dcddb653b0a",
         "e9a41f12daa83defa3d25fc9f0636228811f66b46fea153768b29dcddb653b0"),
    ])
    func rejectsTamperedSignedFieldsAndChecksums(original: String, replacement: String) throws {
        let body = try replacingFixtureText(original, with: replacement)
        let postback = try Postback.decode(body)

        #expect(!postback.verifyChecksum(apiSecret: apiSecret))
    }

    @Test func changingStatusLeavesTheChecksumValid() throws {
        let body = try replacingFixtureText(#""status": "COMPLETE""#, with: #""status": "UPDATE""#)
        let postback = try Postback.decode(body)

        #expect(postback.status == "UPDATE")
        #expect(postback.verifyChecksum(apiSecret: apiSecret))
    }

    private func replacingFixtureText(_ original: String, with replacement: String) throws -> Data {
        let fixture = try String(decoding: HTTPStub.fixture("postback.json"), as: UTF8.self)
        try #require(fixture.contains(original))
        return Data(fixture.replacingOccurrences(of: original, with: replacement).utf8)
    }
}
