// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "KiteConnect",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "KiteConnect", targets: ["KiteConnect"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.0.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", exact: "2.16.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.78.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.24.0"),
    ],
    targets: [
        .target(
            name: "KiteConnect",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
        ),
        .testTarget(
            name: "KiteConnectTests",
            dependencies: [
                "KiteConnect",
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ], resources: [.copy("Fixtures")],
        ),
    ],
)
