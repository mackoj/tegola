// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaTestSupport",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "TegolaFixtures", targets: ["TegolaFixtures"]),
    .library(name: "TegolaTestSupport", targets: ["TegolaTestSupport"]),
  ],
  targets: [
    // Files tests read: real data where it exists (a collector's own spreadsheet), recorded responses otherwise.
    // Linked by test targets only, never by a source target (PLAN §2.4).
    .target(name: "TegolaFixtures", resources: [.copy("Fixtures")], swiftSettings: swiftSettings),
    // Helpers shared by test targets, and the guard tests over the whole repo's sources (PLAN §2.6).
    .target(name: "TegolaTestSupport", dependencies: ["TegolaFixtures"], swiftSettings: swiftSettings),
    .testTarget(
      name: "TegolaTestSupportTests",
      dependencies: ["TegolaTestSupport", "TegolaFixtures"],
      swiftSettings: swiftSettings
    ),
  ]
)
