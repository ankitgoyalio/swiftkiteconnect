//
//  FirstRequest-Session.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import KiteConnect

func tutorialInstallAccessToken(client: KiteClient, accessToken: String) async throws {
    try await client.replaceAccessToken(accessToken)
}
