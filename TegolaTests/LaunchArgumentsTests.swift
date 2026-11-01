import Testing

@testable import Tegola

@Suite struct LaunchArgumentsTests {
  @Test func readsTheTestArguments() {
    let arguments = LaunchArguments(["Tegola", "--reset", "--screen", "object", "-AppleLanguages", "(en)"])
    #expect(arguments.reset)
    #expect(!arguments.seed)
    #expect(arguments.screen == "object")
  }

  @Test func movesTheClockForJourneyThree() {
    #expect(LaunchArguments(["Tegola", "--days-ahead", "15"]).daysAhead == 15)
    #expect(LaunchArguments(["Tegola", "--days-ahead", "soon"]).daysAhead == 0)
  }

  @Test func noArgumentsMeansANormalLaunch() {
    #expect(LaunchArguments(["Tegola"]) == LaunchArguments([]))
  }
}
