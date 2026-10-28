//
//  KiteRequest.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation

/// One query or form field; arrays preserve repeated names and caller ordering.
///
/// Values remain unescaped until the client percent-encodes each name and value.
public struct KiteParameter: Sendable, Equatable {
    /// The unescaped query or form field name; repeated names are preserved.
    public let name: String
    /// The unescaped field value, including empty strings when supplied.
    public let value: String
    /// Stores a field without validation or percent encoding.
    ///
    /// - Parameters:
    ///   - name: The unescaped field name.
    ///   - value: The unescaped field value.
    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

/// The wire encoding selected for a REST request body; no content validation occurs here.
public enum KiteRequestBody: Sendable {
    /// Ordered form fields encoded as application/x-www-form-urlencoded, preserving repeated names.
    case form([KiteParameter])
    /// Pre-encoded JSON bytes sent unchanged with application/json content type; callers own JSON validity.
    case json(Data)
}

/// Shared request contract for typed endpoint extensions and controlled protocol tests.
public struct KiteRequest: Sendable {
    /// The HTTP verb used for the single transport attempt.
    public let method: KiteHTTPMethod
    /// An absolute API path without a query, fragment, traversal, or URL scheme.
    public let path: String
    /// Unescaped query pairs encoded in order, including repeated names.
    public let query: [KiteParameter]
    /// The optional form or JSON body; nil sends no body content.
    public let body: KiteRequestBody?
    /// Whether dispatch requires a local access token and adds the Authorization header.
    public let authenticated: Bool
    /// Whether transport or malformed-response failures must expose a potentially accepted mutation.
    public let isTradingMutation: Bool
    /// Whether URL construction omits the configured API prefix for an instrument dump.
    public let isInstrumentDump: Bool
    /// Stores a low-level request description; dispatch validates the path and credentials.
    ///
    /// - Parameters:
    ///   - method: The HTTP verb.
    ///   - path: An absolute API path, without query, fragment, traversal, or URL scheme.
    ///   - query: Ordered unescaped query pairs; duplicates remain intact.
    ///   - body: Optional form fields or pre-encoded JSON.
    ///   - authenticated: Whether to require and send this client's token.
    ///   - isTradingMutation: Set for actions whose lost acknowledgement requires reconciliation.
    ///   - isInstrumentDump: Whether to omit the configured API route prefix.
    ///
    /// Incorrect mutation classification can hide uncertain acceptance. Prefer typed endpoint methods.
    public init(
        method: KiteHTTPMethod = .get, path: String, query: [KiteParameter] = [],
        body: KiteRequestBody? = nil, authenticated: Bool = true, isTradingMutation: Bool = false,
        isInstrumentDump: Bool = false,
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.authenticated = authenticated
        self.isTradingMutation = isTradingMutation
        self.isInstrumentDump = isInstrumentDump
    }
}
