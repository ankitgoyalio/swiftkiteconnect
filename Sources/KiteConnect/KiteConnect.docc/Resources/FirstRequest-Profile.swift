//
//  FirstRequest-Profile.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import KiteConnect

func tutorialFetchProfile(client: KiteClient) async throws -> KiteUserProfile {
    let profile = try await client.profile()
    print(profile.userID)
    return profile
}
