#if canImport(SwiftUI) && canImport(CoreText)
  public import CoreText
  public import SwiftUI
  public import TegolaDesignTokens
  import Foundation
  #if canImport(UIKit)
    import UIKit
  #endif

  /// Registers the bundled fonts and resolves text styles to CoreText faces.
  public enum TegolaFonts {
    /// Registers every bundled font with the process. Call once at launch (the app does, in its `init`). A font that's
    /// already registered is fine. Returns the files that failed, empty when all is well.
    @discardableResult
    public static func register() -> [String] {
      var failed: [String] = []
      for family in TegolaFontFamily.allCases {
        for file in family.files {
          guard let url = Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "Fonts") else {
            failed.append(file)
            continue
          }
          var error: Unmanaged<CFError>?
          if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
            if code != CTFontManagerError.alreadyRegistered.rawValue { failed.append(file) }
          }
        }
      }
      return failed
    }

    /// The CoreText font for a style at a point size: the face from `TegolaFontFamily.face(weight:size:)`, with its
    /// variation axes set.
    public static func ctFont(_ style: TegolaTextStyle, size: Double) -> CTFont {
      let face = style.family.face(weight: style.weight, size: size)
      var descriptor = CTFontDescriptorCreateWithNameAndSize(face.postScriptName as CFString, size)
      for (axis, value) in face.axes {
        descriptor = CTFontDescriptorCreateCopyWithVariation(descriptor, axis.rawValue as CFNumber, value)
      }
      return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
  }

  extension View {
    /// Applies a text style: face, size (scaled with Dynamic Type unless it's a display style), tracking, line height
    /// and case.
    public func tegolaTextStyle(_ style: TegolaTextStyle) -> some View {
      modifier(TextStyleModifier(style: style))
    }
  }

  private struct TextStyleModifier: ViewModifier {
    let style: TegolaTextStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
      let size = scaledSize
      let font = TegolaFonts.ctFont(style, size: size)
      let natural = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
      // SwiftUI can't set line spacing below the font's natural leading, so a line height under ~1.2 (the 0.96 of the
      // two-line display titles) is drawn by the DisplayTitle component, one Text per line (M3).
      return
        content
        .font(Font(font))
        .tracking(style.tracking * size)
        .lineSpacing(max(0, style.lineHeight * size - natural))
        .textCase(style.uppercased ? .uppercase : nil)
    }

    private var scaledSize: Double {
      guard style.scalesWithDynamicType else { return style.size }
      #if canImport(UIKit)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: .body).scaledValue(for: style.size, compatibleWith: traits)
      #else
        return style.size
      #endif
    }
  }
#endif
