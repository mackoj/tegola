// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaDesignSystem",
  defaultLocalization: "en",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "TegolaDesignTokens", targets: ["TegolaDesignTokens"]),
    .library(name: "TegolaDesignSystem", targets: ["TegolaDesignSystem"]),
    .library(name: "TegolaSnapshotTesting", targets: ["TegolaSnapshotTesting"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", "1.18.0"..<"2.0.0")
  ],
  targets: [
    // Pure values: the palette, the roles, the themes, type, spacing, radii, borders, shadows. No SwiftUI, so the
    // contrast tests run on Linux (scripts/test-linux.sh). This is the only place a colour value may be written.
    .target(
      name: "TegolaDesignTokens",
      swiftSettings: swiftSettings
    ),
    // SwiftUI: the theme in the environment, colours and fonts resolved from tokens, font registration, and (from
    // M3) every shared component. Compiles to nothing where SwiftUI isn't available.
    .target(
      name: "TegolaDesignSystem",
      dependencies: ["TegolaDesignTokens"],
      resources: [.copy("Resources/Fonts"), .process("Resources/Localizable.xcstrings")],
      swiftSettings: swiftSettings
    ),
    // Snapshot assertions at PLAN §2.6's settings, for every package's iOS snapshot tests. Linked by tests only.
    .target(
      name: "TegolaSnapshotTesting",
      dependencies: [
        "TegolaDesignSystem", "TegolaDesignTokens",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaDesignTokensTests",
      dependencies: ["TegolaDesignTokens"],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaDesignSystemTests",
      dependencies: [
        "TegolaDesignSystem", "TegolaDesignTokens", "TegolaSnapshotTesting",
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
