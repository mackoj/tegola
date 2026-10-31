#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignTokens

  extension TegolaRGB {
    /// The sRGB colour. Only the design system turns tokens into SwiftUI colours.
    public var color: Color {
      Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
  }

  extension EnvironmentValues {
    /// The theme every design-system component reads. Set once at the root; v1 sets `.board` (PLAN §4.0).
    @Entry public var tegolaTheme: TegolaTheme = .board
  }

  extension View {
    /// Fills with a role's colour in the current theme.
    public func foregroundStyle(_ role: TegolaRole) -> some View {
      modifier(RoleForeground(role: role))
    }

    /// Sets the theme for this view and everything inside it.
    public func tegolaTheme(_ theme: TegolaTheme) -> some View {
      environment(\.tegolaTheme, theme)
    }
  }

  private struct RoleForeground: ViewModifier {
    let role: TegolaRole
    @Environment(\.tegolaTheme) private var theme

    func body(content: Content) -> some View {
      content.foregroundStyle(theme[role].color)
    }
  }
#endif
