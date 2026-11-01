#if DEBUG
  import AppFeature
  import Foundation

  /// Arguments the UI tests launch the app with (PLAN §2.6): `--reset` starts from an empty catalogue, `--seed` from
  /// the seed shelf, `--screen <name>` opens one screen directly. Debug builds only. `--screen` is read once the
  /// screens exist (M3).
  struct LaunchArguments: Equatable {
    var reset = false
    var seed = false
    var screen: String?
    /// A file to open Bring your list with (journey 2): the system file picker can't be driven by a UI test.
    var importFixture: String?

    init(_ arguments: [String]) {
      var iterator = arguments.dropFirst().makeIterator()
      while let argument = iterator.next() {
        switch argument {
        case "--reset": reset = true
        case "--seed": seed = true
        case "--screen": screen = iterator.next()
        case "--import-fixture": importFixture = iterator.next()
        default: continue
        }
      }
    }

    /// Opens the database as the arguments ask.
    func apply() {
      AppBootstrap.prepare(reset: reset, seed: seed)
    }
  }
#endif
