import Foundation

/// One colour, as 0xRRGGBB. The only place a colour literal may appear is this file and `Theme.swift`
/// (`DesignTokenGuardTests` fails on a hex value anywhere else in `Sources/`).
public struct TegolaRGB: Hashable, Sendable, CustomStringConvertible {
  public let hex: UInt32

  public init(_ hex: UInt32) {
    self.hex = hex
  }

  public var red: Double { Double((hex >> 16) & 0xFF) / 255 }
  public var green: Double { Double((hex >> 8) & 0xFF) / 255 }
  public var blue: Double { Double(hex & 0xFF) / 255 }

  public var description: String {
    let digits = String(hex, radix: 16, uppercase: true)
    return "#" + String(repeating: "0", count: max(0, 6 - digits.count)) + digits
  }

  /// WCAG 2.x relative luminance.
  public var relativeLuminance: Double {
    func linear(_ channel: Double) -> Double {
      channel <= 0.040_45 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  /// WCAG 2.x contrast ratio, from 1 to 21.
  public func contrast(with other: TegolaRGB) -> Double {
    let (lighter, darker) = (
      max(relativeLuminance, other.relativeLuminance), min(relativeLuminance, other.relativeLuminance)
    )
    return (lighter + 0.05) / (darker + 0.05)
  }
}

/// The archive's palette, exactly as `original-spec/design_handoff_clctn/README.md` and `docs/design/BOARDS.md`
/// § Token table give it. Views never use these directly: they use a `TegolaRole`, which a theme maps to one of
/// these (PLAN §4.0, D-26).
public enum TegolaPalette {
  public static let ink = TegolaRGB(0x17130F)
  public static let inkSoft = TegolaRGB(0x241F19)
  public static let paper = TegolaRGB(0xF3ECE0)
  public static let sand = TegolaRGB(0xEDE4D6)
  public static let paperDeep = TegolaRGB(0xDDD2C0)
  public static let card = TegolaRGB(0xFFFFFF)
  public static let muted = TegolaRGB(0x6E6458)
  public static let meta = TegolaRGB(0x8A7F70)
  public static let rule = TegolaRGB(0xC9BFB0)
  public static let ruleDark = TegolaRGB(0xB9AC99)
  public static let yellow = TegolaRGB(0xFFD24A)
  public static let orange = TegolaRGB(0xFF5B2E)
  public static let orangeSoft = TegolaRGB(0xFF8A4C)
  public static let pink = TegolaRGB(0xE5457B)
  public static let green = TegolaRGB(0x0E6E5E)
  public static let teal = TegolaRGB(0x12A594)
  public static let cobalt = TegolaRGB(0x2B44D6)
  public static let rust = TegolaRGB(0xC2371F)
  public static let mint = TegolaRGB(0xB9F0C9)
  public static let camera = TegolaRGB(0x0C0A08)
  public static let cameraTop = TegolaRGB(0x2A231C)

  /// Derived, not in the archive: the archive's meta grey (#8A7F70) is 3.34:1 on paper, under WCAG AA for the 9–11 pt
  /// mono labels that use it. This is the same hue, darkened until it passes 4.5:1 on every light surface the boards
  /// put it on (PLAN §10 answer 8; BOARDS.md lists each board this changes).
  public static let metaText = TegolaRGB(0x645A4E)
}
