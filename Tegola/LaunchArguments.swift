#if DEBUG
  import Foundation

  /// Arguments the UI tests launch the app with (PLAN §2.6): `--reset` starts from an empty catalogue, `--seed` from
  /// the seed shelf, `--screen <name>` opens one screen directly. Debug builds only. The catalogue and the seed arrive
  /// in M2; until then the arguments are parsed and remembered.
  struct LaunchArguments: Equatable {
    var reset = false
    var seed = false
    var screen: String?

    init(_ arguments: [String]) {
      var iterator = arguments.dropFirst().makeIterator()
      while let argument = iterator.next() {
        switch argument {
        case "--reset": reset = true
        case "--seed": seed = true
        case "--screen": screen = iterator.next()
        default: continue
        }
      }
    }

    func apply() {}
  }
#endif
