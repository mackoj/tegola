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
    .library(name: "FindFeature", targets: ["FindFeature"]),
    .library(name: "PlacesFeature", targets: ["PlacesFeature"]),
    .library(name: "ObjectFeature", targets: ["ObjectFeature"]),
    .library(name: "ObjectEditFeature", targets: ["ObjectEditFeature"]),
    .library(name: "AddByHandFeature", targets: ["AddByHandFeature"]),
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
    .target(
      name: "PlacesFeature",
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
      name: "PlacesFeatureTests",
      dependencies: [
        "PlacesFeature", "TegolaClients", "FeatureTestSupport",
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
      name: "FindFeature",
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
      name: "FindFeatureTests",
      dependencies: [
        "FindFeature", "TegolaClients", "FeatureTestSupport",
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
    // How the shelf's values read on screen, shared by every feature that shows an object.
    .target(
      name: "ShelfViews",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "TegolaDesignTokens", package: "TegolaDesignSystem"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaDesignSystem", package: "TegolaDesignSystem"),
      ],
      resources: [.process("Resources")],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "ObjectEditFeature",
      dependencies: [
        "TegolaClients", "ShelfViews",
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
      name: "ObjectEditFeatureTests",
      dependencies: [
        "ObjectEditFeature", "TegolaClients", "FeatureTestSupport",
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
      name: "AddByHandFeature",
      dependencies: [
        "TegolaClients", "ShelfViews",
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
      name: "AddByHandFeatureTests",
      dependencies: [
        "AddByHandFeature", "TegolaClients", "FeatureTestSupport",
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
      name: "ObjectFeature",
      dependencies: [
        "TegolaClients", "ShelfViews", "ObjectEditFeature",
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
      name: "ObjectFeatureTests",
      dependencies: [
        "ObjectFeature", "ObjectEditFeature", "TegolaClients", "FeatureTestSupport",
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
        "TegolaClients", "ShelfFeature", "CollectionFeature", "ObjectFeature", "AddByHandFeature", "FindFeature",
        "PlacesFeature",
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
        "AppFeature", "AddByHandFeature", "CollectionFeature", "FeatureTestSupport", "FindFeature", "ShelfFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "TegolaModel", package: "TegolaModel"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
