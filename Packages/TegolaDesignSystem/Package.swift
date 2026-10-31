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
      resources: [.copy("Resources/Fonts")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaDesignTokensTests",
      dependencies: ["TegolaDesignTokens"],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaDesignSystemTests",
      dependencies: ["TegolaDesignSystem", "TegolaDesignTokens"],
      swiftSettings: swiftSettings
    ),
  ]
)
