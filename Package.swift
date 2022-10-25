// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "spacewar-swift",
  platforms: [
    .macOS("12.0"),
  ],
  dependencies: [
    .package(url: "https://github.com/johnfairh/steamworks-swift",
             branch: "main"),
    .package(url: "https://github.com/johnfairh/TMLEngines",
             from: "1.2.0")
  ],
  targets: [
    .executableTarget(
      name: "SpaceWar",
      dependencies: [
        "CSpaceWar",
        .product(name: "MetalEngine", package: "TMLEngines"),
        .product(name: "Steamworks", package: "steamworks-swift"),
        .product(name: "SteamworksHelpers", package: "steamworks-swift"),
      ],
      resources: [
        .process("Resources/steam_controller.vdf"),
        .process("Resources/steam_input_manifest.vdf"),
        .process("Resources/xbox_controller.vdf")
      ]
    ),
    .systemLibrary(name: "CSpaceWar")
  ]
)
