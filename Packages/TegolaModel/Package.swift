// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaModel",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "TegolaModel", targets: ["TegolaModel"]),
    .library(name: "TegolaModelTesting", targets: ["TegolaModelTesting"]),
  ],
  dependencies: [
    .package(path: "../TegolaCatalogue")
  ],
  targets: [
    // Domain values and rules: objects, events, ShelfCommand, and the pure plan and apply. Pure: builds on Linux
    // (PLAN §2.4).
    .target(
      name: "TegolaModel",
      dependencies: [.product(name: "TegolaCatalogue", package: "TegolaCatalogue")],
      swiftSettings: swiftSettings
    ),
    // What the model's tests and the storage tests share: deterministic ids, and random command sequences.
    .target(
      name: "TegolaModelTesting",
      dependencies: ["TegolaModel", .product(name: "TegolaCatalogue", package: "TegolaCatalogue")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaModelTests",
      dependencies: [
        "TegolaModel", "TegolaModelTesting", .product(name: "TegolaCatalogue", package: "TegolaCatalogue"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
