// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "spacewar-swift",
    platforms: [
      .macOS("12.0"),
    ],
    dependencies: [
        .package(url: "https://github.com/johnfairh/steamworks-swift",
                 revision: "214af96"),
        .package(url: "https://github.com/johnfairh/TMLEngines",
                 from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SpaceWar",
            dependencies: [
                .product(name: "MetalEngine", package: "TMLEngines"),
                .product(name: "Steamworks", package: "steamworks-swift"),
                .product(name: "SteamworksHelpers", package: "steamworks-swift"),
            ]
        )
    ]
)
