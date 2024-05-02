// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "spacewar-swift",
  platforms: [
    .macOS("14.0"),
  ],
  dependencies: [
    .package(url: "https://github.com/johnfairh/steamworks-swift",
             from: "0.5.2"),
    .package(url: "https://github.com/johnfairh/TMLEngines",
             from: "1.3.3")
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
        .process("Resources/xbox_controller.vdf"),
        .process("Resources/ps5_controller.vdf")
      ],
      swiftSettings: [
        .interoperabilityMode(.Cxx),
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .systemLibrary(name: "CSpaceWar")
  ]
)
