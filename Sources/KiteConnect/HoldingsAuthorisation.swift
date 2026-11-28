import Foundation

/// The ISIN and quantity of a holding to authorise for sale.
public struct HoldingAuthorisationItem: Equatable, Sendable {
    public let isin: String
    public let quantity: Int64

    public init(isin: String, quantity: Int64) {
        self.isin = isin
        self.quantity = quantity
    }

    public init(holding: Holding, quantity: Int64) {
        self.init(isin: holding.isin, quantity: quantity)
    }
}

/// The request ID and web URL for completing authorisation at the depository.
public struct HoldingsAuthorisation: Equatable, Sendable {
    public let requestID: String
    public let redirectURL: URL
}

extension KiteConnectClient {
    /// Initiates holdings authorisation. The caller opens the returned URL for the user.
    /// An empty list requests authorisation for the entire portfolio of holdings.
    public func authoriseHoldings(_ items: [HoldingAuthorisationItem] = []) async throws -> HoldingsAuthorisation {
        let form = items.flatMap { item in
            [
                URLQueryItem(name: "isin", value: item.isin),
                URLQueryItem(name: "quantity", value: String(item.quantity)),
            ]
        }
        let response: HoldingsAuthorisationResponse = try await rest.send(
            .init(.post, path: ["portfolio", "holdings", "authorise"], body: .form(form))
        )
        let browserRequest = RESTRequest(
            .get,
            path: ["connect", "portfolio", "authorise", "holdings", rest.apiKey, response.requestID]
        )
        let redirectURL = try browserRequest.urlRequest(baseURL: URL(string: "https://kite.zerodha.com")!).url!
        return HoldingsAuthorisation(requestID: response.requestID, redirectURL: redirectURL)
    }
}

private struct HoldingsAuthorisationResponse: Decodable {
    let requestID: String

    private enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
    }
}
