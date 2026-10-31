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
    .package(path: "../TegolaModel"),
    .package(path: "../TegolaTestSupport"),
  ],
  targets: [
    // Import and export: reading what collectors bring and writing what they take away. Pure: builds on Linux
    // (PLAN §2.4). M1 has the delimited-text reader; the Importer API and the three v1 importers arrive in M6.
    .target(
      name: "TegolaInterchange",
      dependencies: [.product(name: "TegolaModel", package: "TegolaModel")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaInterchangeTests",
      dependencies: ["TegolaInterchange", .product(name: "TegolaFixtures", package: "TegolaTestSupport")],
      swiftSettings: swiftSettings
    ),
  ]
)
