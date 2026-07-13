// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WharfsideAnalysis",
    platforms: [.macOS("26")],
    products: [
        .library(name: "WharfsideAnalysis", targets: ["WharfsideAnalysis"]),
        .executable(name: "digest-preview", targets: ["DigestPreview"]),
    ],
    dependencies: [
        .package(path: "../RulebookCore"),
    ],
    targets: [
        .target(
            name: "WharfsideAnalysis",
            dependencies: [
                .product(name: "RulebookCore", package: "RulebookCore"),
            ]
        ),
        .executableTarget(
            name: "DigestPreview",
            dependencies: ["WharfsideAnalysis"]
        ),
        .testTarget(
            name: "WharfsideAnalysisTests",
            dependencies: ["WharfsideAnalysis"]
        ),
    ]
)
