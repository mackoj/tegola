// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaCatalogue",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "TegolaCatalogue", targets: ["TegolaCatalogue"])
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", "6.0.0"..<"7.0.0")
  ],
  targets: [
    // The type files and the code that reads and validates them. Pure: builds on Linux (PLAN §2.4).
    .target(
      name: "TegolaCatalogue",
      dependencies: [.product(name: "Yams", package: "Yams")],
      resources: [.copy("Types")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "TegolaCatalogueTests",
      dependencies: ["TegolaCatalogue"],
      swiftSettings: swiftSettings
    ),
  ]
)
