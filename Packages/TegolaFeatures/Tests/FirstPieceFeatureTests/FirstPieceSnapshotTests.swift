#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaCatalogue
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import FirstPieceFeature

  /// Every screen and state of the first piece (T5.6): page 46 has no board in the archive, so these are its record.
  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf(seed: false) })
  struct FirstPieceSnapshotTests {
    func snapshot(_ state: FirstPieceFeature.State, named name: String, height: Double = 852) {
      let store = Store(initialState: state) { FirstPieceFeature() }
      assertScreenSnapshot(of: FirstPieceView(store: store), named: name, suite: "firstPiece", height: height)
    }

    var named: FirstPieceFeature.State {
      var state = FirstPieceFeature.State()
      state.name = "Ocarina of Time"
      state.guess = TypeGuess(type: "video-game", subtype: "n64", isEnabled: true)
      state.type = "video-game"
      state.subtype = "n64"
      return state
    }

    @Test func oneQuestion() {
      snapshot(FirstPieceFeature.State(), named: "1-oneQuestion")
    }

    @Test func recognised() {
      var state = named
      state.step = .recognised
      snapshot(state, named: "2-recognised")
    }

    @Test func whatIsItEmpty() {
      var state = FirstPieceFeature.State()
      state.step = .whatIsIt
      snapshot(state, named: "2-whatIsIt-empty")
    }

    @Test func whatIsItGuessedAWatch() {
      var state = FirstPieceFeature.State()
      state.step = .whatIsIt
      state.name = "Omega Seamaster"
      state.guess = TypeGuess(type: "watches", subtype: nil, isEnabled: false)
      state.type = "watches"
      snapshot(state, named: "2-whatIsIt-watch")
    }

    @Test func story() {
      var state = named
      state.step = .story
      state.chip = .sinceChild
      state.line = "My brother's, then mine"
      snapshot(state, named: "2-story")
    }

    @Test func notShipped() {
      var state = FirstPieceFeature.State()
      state.name = "Omega Seamaster"
      state.awaiting = "watches"
      state.step = .notShipped
      snapshot(state, named: "2B-notShipped")
    }

    @Test func payoffNow() {
      var state = named
      state.step = .payoff
      state.chip = .sinceChild
      state.payoff = FirstPiecePayoff(
        line: .now(
          Signal(
            clock: "saveBattery",
            status: .watch,
            reason: .battery(since: 1998, swapped: false, lastsYears: 25...35),
            changesAt: nil
          )
        )
      )
      snapshot(state, named: "3-payoff-now")
    }

    @Test func payoffLater() {
      var state = FirstPieceFeature.State()
      state.name = "Château Musar 2018"
      state.step = .payoff
      state.chip = .gift
      state.payoff = FirstPiecePayoff(
        line: .later(clock: "drinkingWindow", from: Calendar.testUTC.date(from: DateComponents(year: 2027))!)
      )
      snapshot(state, named: "3-payoff-later")
    }
  }
#endif
