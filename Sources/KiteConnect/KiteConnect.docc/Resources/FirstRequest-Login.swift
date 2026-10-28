//
//  FirstRequest-Login.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 28/10/2026.

import Foundation
import KiteConnect

func tutorialLoginURL(client: KiteClient) throws -> URL {
    try client.loginURL()
}
