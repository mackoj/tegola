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
    .library(name: "TegolaModel", targets: ["TegolaModel"])
  ],
  dependencies: [
    .package(path: "../TegolaCatalogue")
  ],
  targets: [
    // Domain values and rules. Pure: builds on Linux (PLAN §2.4). M1 holds the values every later milestone needs;
    // objects, events and ShelfCommand arrive in M2.
    .target(
      name: "TegolaModel",
      dependencies: [.product(name: "TegolaCatalogue", package: "TegolaCatalogue")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaModelTests",
      dependencies: ["TegolaModel"],
      swiftSettings: swiftSettings
    ),
  ]
)
