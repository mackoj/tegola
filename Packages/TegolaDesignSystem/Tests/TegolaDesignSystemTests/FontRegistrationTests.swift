#if canImport(SwiftUI) && canImport(CoreText)
  import Testing
  import TegolaDesignSystem

  @Suite struct FontRegistrationTests {
    @Test func everyBundledFontRegisters() {
      #expect(TegolaFonts.register().isEmpty)
    }
  }
#endif
