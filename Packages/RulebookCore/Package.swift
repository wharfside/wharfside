// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RulebookCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RulebookCore", targets: ["RulebookCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "RulebookCore",
            dependencies: [.product(name: "Crypto", package: "swift-crypto")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RulebookCoreTests",
            dependencies: ["RulebookCore"]
        ),
    ]
)
