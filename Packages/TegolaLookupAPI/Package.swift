// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "TegolaLookupAPI",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "TegolaLookupAPI", targets: ["TegolaLookupAPI"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-generator", "1.10.0"..<"2.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime", "1.8.0"..<"2.0.0"),
  ],
  targets: [
    // The client and types generated from api/tegola-lookup.openapi.yaml (a symlink here, so the contract has one
    // home). The transport (URLSession) and the App Attest middleware are attached in TegolaClients; this target
    // stays pure and builds on Linux (PLAN §2.4, §7).
    .target(
      name: "TegolaLookupAPI",
      dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
      swiftSettings: swiftSettings,
      plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
    ),
    .testTarget(
      name: "TegolaLookupAPITests",
      dependencies: [
        "TegolaLookupAPI",
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
      ],
      resources: [.copy("Responses")],
      swiftSettings: swiftSettings
    ),
  ]
)
