// swift-tools-version: 5.9
import PackageDescription

extension [SwiftSetting] {
    static let inProgress: [SwiftSetting] = [
        
    ]
    
    static let prereleaseTools: [SwiftSetting] = [
        .enableExperimentalFeature("AccessLevelOnImport"),
        
    ]
    
    static let featureFlags: [SwiftSetting] = [
        .define("BUILD_LIL_BISH_SERVER"),
        
    ]
    
    static let volaCluster = inProgress + prereleaseTools + featureFlags
    static let volaClusterTests = Self.volaCluster
    
}

let package = Package(
    name: "vola-cluster",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
        .watchOS(.v9),
        
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
                
            ],
            swiftSettings: .volaCluster
        ),
        
        .testTarget(
            name: "VolaClusterTests",
            dependencies: [
                "VolaCluster",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                
            ],
            swiftSettings: .volaClusterTests
        ),
        
    ]
)
