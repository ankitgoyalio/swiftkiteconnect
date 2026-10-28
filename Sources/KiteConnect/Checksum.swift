import Crypto
import Foundation

/// Shared UTF-8 SHA-256 primitive for session and postback checksums.
enum KiteChecksum {
  static func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}
