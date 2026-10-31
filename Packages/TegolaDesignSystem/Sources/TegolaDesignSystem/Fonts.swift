#if canImport(SwiftUI) && canImport(CoreText)
  public import SwiftUI
  public import TegolaDesignTokens
  import CoreText
  import Foundation

  /// Registers the bundled fonts with the process. Call once at launch (the app does, in its `init`). Registering a
  /// font twice is harmless: CoreText reports it as already registered, which is ignored.
  public enum TegolaFonts {
    /// The font files that failed to register, empty when all is well (`FontRegistrationTests`).
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
  }

  extension TegolaTextStyle {
    /// The SwiftUI font for this style. Body and label styles scale with Dynamic Type relative to `.body`; display
    /// styles keep their designed size.
    public var font: Font {
      let font: Font =
        scalesWithDynamicType
        ? .custom(family.familyName, size: size, relativeTo: .body)
        : .custom(family.familyName, fixedSize: size)
      return font.weight(Font.Weight(tegolaWeight: weight))
    }
  }

  extension Font.Weight {
    init(tegolaWeight: Int) {
      switch tegolaWeight {
      case ..<350: self = .light
      case ..<450: self = .regular
      case ..<550: self = .medium
      case ..<650: self = .semibold
      case ..<750: self = .bold
      default: self = .heavy
      }
    }
  }

  extension View {
    /// Applies a text style: family, size, weight, tracking and case.
    public func tegolaTextStyle(_ style: TegolaTextStyle) -> some View {
      font(style.font)
        .tracking(style.trackingPoints)
        .textCase(style.uppercased ? .uppercase : nil)
    }
  }
#endif
