// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaFeatures",
  defaultLocalization: "en",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", "1.26.0"..<"2.0.0"),
    .package(path: "../TegolaModel"),
    .package(path: "../TegolaDesignSystem"),
  ],
  targets: [
    // One target per reducer (PLAN §5). Features arrive with their milestone; M1 has the root only, so there are no
    // empty placeholder targets (telaio's REVIEW §2).
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaDesignSystem", package: "TegolaDesignSystem"),
        .product(name: "TegolaDesignTokens", package: "TegolaDesignSystem"),
      ],
      resources: [.process("Resources")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
