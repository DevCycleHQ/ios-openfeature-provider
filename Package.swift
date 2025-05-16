// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "DevCycleOpenFeatureProvider",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
    ],
    products: [
        .library(
            name: "DevCycleOpenFeatureProvider",
            targets: ["DevCycleOpenFeatureProvider"])
    ],
    dependencies: [
        .package(
            name: "OpenFeature",
            url: "https://github.com/open-feature/swift-sdk.git",
            .upToNextMajor(from: "0.3.0")
        ),
        .package(
            name: "DevCycle",
            url: "https://github.com/DevCycleHQ/ios-client-sdk.git",
            .upToNextMajor(from: "1.18.1")
        ),
    ],
    targets: [
        .target(
            name: "DevCycleOpenFeatureProvider",
            dependencies: [
                .product(name: "OpenFeature", package: "OpenFeature"),
                .product(name: "DevCycle", package: "DevCycle"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "DevCycleOpenFeatureProviderTests",
            dependencies: [
                .target(name: "DevCycleOpenFeatureProvider")
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
