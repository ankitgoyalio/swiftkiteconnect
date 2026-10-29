//
//  SandboxOrderAttempt.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// Reserve before sending a mutation. Never remove a marker automatically.
struct SandboxOrderAttempt {
    let url: URL
    let tag: String

    init(url: URL, tag: String) throws {
        self.url = url
        self.tag = tag
        // Exclusive creation also rejects symlinks. Restrict permissions before
        // writing private identifiers, including during the first write.
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw SandboxVerificationFailure.unexpectedReceipt }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: JSONSerialization.data(withJSONObject: ["tag": tag, "state": "attempted"]))
        try handle.synchronize()
    }

    func acknowledge(orderID: String) throws {
        let descriptor = open(url.path, O_WRONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw SandboxVerificationFailure.unexpectedReceipt }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: JSONSerialization.data(withJSONObject: [
            "tag": tag, "order_id": orderID, "state": "acknowledged",
        ]))
        try handle.synchronize()
    }
}
