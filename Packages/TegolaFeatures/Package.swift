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
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "TegolaClients", targets: ["TegolaClients"]),
    .library(name: "ShelfFeature", targets: ["ShelfFeature"]),
    .library(name: "CollectionFeature", targets: ["CollectionFeature"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", "1.26.0"..<"2.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", "1.17.0"..<"2.0.0"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", "1.0.0"..<"2.0.0"),
    .package(path: "../TegolaCatalogue"),
    .package(path: "../TegolaModel"),
    .package(path: "../TegolaStorage"),
    .package(path: "../TegolaDesignSystem"),
  ],
  targets: [
    // Every client's interface with its test and preview values (PLAN §2.4). ShelfClient's live value is the
    // storage itself (TegolaStorage).
    .target(
      name: "TegolaClients",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaClientsTests",
      dependencies: [
        "TegolaClients",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
      ],
      swiftSettings: swiftSettings
    ),
    // What every feature's tests share: the seeded in-memory database and its ids.
    .target(
      name: "FeatureTestSupport",
      dependencies: [
        "TegolaClients",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
      ],
      path: "Tests/FeatureTestSupport",
      swiftSettings: swiftSettings
    ),
    .target(
      name: "ShelfFeature",
      dependencies: [
        "TegolaClients",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
        .product(name: "TegolaDesignSystem", package: "TegolaDesignSystem"),
        .product(name: "TegolaDesignTokens", package: "TegolaDesignSystem"),
      ],
      resources: [.process("Resources")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "ShelfFeatureTests",
      dependencies: [
        "ShelfFeature", "TegolaClients", "FeatureTestSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
        .product(name: "TegolaSnapshotTesting", package: "TegolaDesignSystem"),
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "CollectionFeature",
      dependencies: [
        "TegolaClients",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
        .product(name: "TegolaDesignSystem", package: "TegolaDesignSystem"),
        .product(name: "TegolaDesignTokens", package: "TegolaDesignSystem"),
      ],
      resources: [.process("Resources")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "CollectionFeatureTests",
      dependencies: [
        "CollectionFeature", "TegolaClients", "FeatureTestSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
        .product(name: "TegolaSnapshotTesting", package: "TegolaDesignSystem"),
      ],
      swiftSettings: swiftSettings
    ),
    // One target per reducer (PLAN §5). Features arrive with their milestone; M1 has the root only, so there are no
    // empty placeholder targets (telaio's REVIEW §2).
    .target(
      name: "AppFeature",
      dependencies: [
        "TegolaClients", "ShelfFeature", "CollectionFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaStorage", package: "TegolaStorage"),
        .product(name: "TegolaDesignSystem", package: "TegolaDesignSystem"),
        .product(name: "TegolaDesignTokens", package: "TegolaDesignSystem"),
      ],
      resources: [.process("Resources")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature", "CollectionFeature", "FeatureTestSupport", "ShelfFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "TegolaModel", package: "TegolaModel"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
