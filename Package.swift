// swift-tools-version:6.0
// MocksAgent: realistic mock backend responses for an app's API client, written into the client's package, as a
// Granite agent package. An app that links it finds the `mocks` agent through Granite's roster, with nothing listed
// by hand.

import PackageDescription

let package = Package(
    name: "MocksAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MocksAgent", targets: ["MocksAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MocksAgent",
            dependencies: [.product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "MocksAgentTests",
            dependencies: ["MocksAgent", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
