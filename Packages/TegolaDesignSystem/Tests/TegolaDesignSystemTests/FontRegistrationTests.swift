#if canImport(SwiftUI) && canImport(CoreText)
  import CoreText
  import Foundation
  import Testing
  import TegolaDesignSystem
  import TegolaDesignTokens

  @Suite(.serialized) struct FontTests {
    @Test func everyBundledFontRegisters() {
      #expect(TegolaFonts.register().isEmpty)
    }

    /// A style that silently falls back to the system face would report another family (review of M1, item 7).
    @Test(arguments: TegolaType.all.map(\.name))
    func everyStyleResolvesToItsOwnFace(_ name: String) throws {
      TegolaFonts.register()
      let style = try #require(TegolaType.all.first { $0.name == name }?.style)
      let font = TegolaFonts.ctFont(style, size: style.size)
      let family = CTFontCopyFamilyName(font) as String
      #expect(family.hasPrefix(style.family.familyName), "\(name) resolved to \(family)")
      let face = style.family.face(weight: style.weight, size: style.size)
      if let wanted = face.axes[.weight] {
        let variation = CTFontCopyVariation(font) as? [NSNumber: NSNumber]
        let weight = variation?[NSNumber(value: TegolaFontFace.Axis.weight.rawValue)]?.doubleValue
        #expect(weight == wanted, "\(name): wght \(String(describing: weight)), wanted \(wanted)")
      }
    }
  }
#endif
