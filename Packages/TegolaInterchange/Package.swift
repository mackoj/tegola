// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaInterchange",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "TegolaInterchange", targets: ["TegolaInterchange"])
  ],
  dependencies: [
    .package(path: "../TegolaCatalogue"),
    .package(path: "../TegolaModel"),
    .package(path: "../TegolaTestSupport"),
  ],
  targets: [
    // Import and export: reading what collectors bring and writing what they take away. Pure: builds on Linux
    // (PLAN §2.4). The delimited-text reader, the Importer API (PLAN F9) and the v1 importers.
    .target(
      name: "TegolaInterchange",
      dependencies: [
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaInterchangeTests",
      dependencies: [
        "TegolaInterchange",
        .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
        .product(name: "TegolaModel", package: "TegolaModel"),
        .product(name: "TegolaFixtures", package: "TegolaTestSupport"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
