// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "KiteConnect",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [.library(name: "KiteConnect", targets: ["KiteConnect"])],
  dependencies: [.package(url: "https://github.com/apple/swift-crypto.git", exact: "4.0.0")],
  targets: [
    .target(name: "KiteConnect", dependencies: [.product(name: "Crypto", package: "swift-crypto")]),
    .testTarget(name: "KiteConnectTests", dependencies: ["KiteConnect"]),
  ]
)
