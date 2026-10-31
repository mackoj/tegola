// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaStorage",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "TegolaStorage", targets: ["TegolaStorage"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/sqlite-data", "1.0.0"..<"2.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", "1.17.0"..<"2.0.0"),
    .package(path: "../TegolaModel"),
    .package(path: "../TegolaCatalogue"),
  ],
  targets: [
    // The one database (ADR-0006): the event log and its projection, written in one transaction (PLAN §3.1).
    .target(
      name: "TegolaStorage",
      dependencies: [
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaStorageTests",
      dependencies: [
        "TegolaStorage",
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaModelTesting", package: "TegolaModel"),
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
