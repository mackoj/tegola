#if os(iOS)
  public import SwiftUI
  import Foundation
  import SnapshotTesting
  import TegolaDesignSystem
  import TegolaDesignTokens
  public import Testing
  import UIKit

  /// Snapshots a view at PLAN §2.6's settings: 2×, light, the Board theme, fonts registered, 99 % pixel and 98 %
  /// perceptual precision. References live in `docs/snapshots/<suite>/` at the repo root, outside every package:
  /// writing into a package mid-run makes xcodebuild reload it and hang. Those PNGs are the milestone screenshots.
  ///
  /// A missing reference is recorded and the test fails. To record new or changed snapshots, run
  /// `SNAPSHOTS=record scripts/test.sh ios:<Package>`, which records and passes; then run without it to check.
  @MainActor
  public func assertScreenSnapshot(
    of view: some View,
    named name: String,
    suite: String,
    width: Double = 393,
    height: Double? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    TegolaFonts.register()
    let framed = view.tegolaTheme(.board).frame(width: width, height: height.map { CGFloat($0) })
    let layout: SwiftUISnapshotLayout =
      height.map { .fixed(width: width, height: $0) } ?? .sizeThatFits
    let recording = ProcessInfo.processInfo.environment["SNAPSHOTS"] == "record"
    let record: SnapshotTestingConfiguration.Record = recording ? .all : .missing
    let failure = verifySnapshot(
      of: framed,
      as: .image(
        precision: 0.99,
        perceptualPrecision: 0.98,
        layout: layout,
        traits: UITraitCollection {
          $0.displayScale = 2; $0.userInterfaceStyle = .light
        }
      ),
      named: name,
      record: record,
      snapshotDirectory: snapshotsRoot.appending(path: suite).path(percentEncoded: false),
      testName: suite
    )
    // A record run writes the references and passes: a failing xcodebuild run can hang on this Mac (D-46).
    if let failure, !recording {
      Issue.record(Comment(rawValue: failure), sourceLocation: sourceLocation)
    }
  }

  /// `docs/snapshots`, found from this file: Packages/TegolaDesignSystem/Sources/TegolaSnapshotTesting/….
  let snapshotsRoot: URL = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "docs/snapshots")
#endif
