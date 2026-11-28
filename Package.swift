// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiteConnect",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "KiteConnect", targets: ["KiteConnect"])],
    targets: [
        .target(name: "KiteConnect"),
        .testTarget(
            name: "KiteConnectTests",
            dependencies: ["KiteConnect"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
