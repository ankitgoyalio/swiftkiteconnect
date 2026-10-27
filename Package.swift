// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "KiteConnect",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [.library(name: "KiteConnect", targets: ["KiteConnect"])],
  targets: [
    .target(name: "KiteConnect"),
    .testTarget(name: "KiteConnectTests", dependencies: ["KiteConnect"]),
  ]
)
