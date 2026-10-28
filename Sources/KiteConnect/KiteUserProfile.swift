//
//  KiteUserProfile.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

import Foundation

/// Account details and enabled trading capabilities returned by Kite.
///
/// Exchange, product, and order-type values preserve unfamiliar server values
/// through open enums. This profile is a server snapshot, not a session-validity
/// guarantee. See ``KiteClient/profile()`` for a read-only authenticated request.
public struct KiteUserProfile: Decodable, Sendable, Equatable {
    /// The broker's identifier for the authenticated user.
    public let userID: String
    /// The account classification returned in `user_type`.
    public let userType: String
    /// The email address in the user's account profile.
    public let email: String
    /// The full display name in the user's account profile.
    public let userName: String
    /// The shortened display name returned in `user_shortname`.
    public let userShortname: String
    /// The broker identifier returned by Kite, such as `ZERODHA`.
    public let broker: String
    /// The exchanges enabled for this user, including unfamiliar server values.
    public let exchanges: [KiteExchange]
    /// The trading products enabled for this user, including unfamiliar server values.
    public let products: [KiteProduct]
    /// The order types enabled for this user, including unfamiliar server values.
    public let orderTypes: [KiteOrderType]
    /// The optional avatar location as returned by Kite, without URL validation.
    public let avatarURL: String?
    /// Additional account metadata returned with the profile.
    public let meta: Metadata
    /// Account metadata whose raw consent value follows Kite's response.
    public struct Metadata: Decodable, Sendable, Equatable {
        /// The raw demat-consent value from Kite, preserved without interpretation.
        public let dematConsent: String
        enum CodingKeys: String, CodingKey { case dematConsent = "demat_consent" }
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case userType = "user_type"
        case email
        case userName = "user_name"
        case userShortname = "user_shortname"
        case broker, exchanges, products
        case orderTypes = "order_types"
        case avatarURL = "avatar_url"
        case meta
    }
}
