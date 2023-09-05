// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "vola-cluster",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        
    ],
    products: [
        .library(
            name: "VolaCluster",
            targets: ["VolaCluster"]),
        
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.56.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.0.0"),
        .package(url: "git@github.com:christopherweems/swift-distributed-actors.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-service-discovery.git", from: "1.2.1"),
        
    ],
    targets: [
        .target(
            name: "VolaCluster",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                .product(name: "DistributedCluster", package: "swift-distributed-actors"),
                .product(name: "ServiceDiscovery", package: "swift-service-discovery"),
                
            ]
        ),
        
        .testTarget(
            name: "VolaClusterTests",
            dependencies: [
                "VolaCluster",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                
            ]),
        
    ]
)
