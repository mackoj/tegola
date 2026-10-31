#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignTokens

  // Signature renderers (board 34): a signature renders, it never collects. At most two per type, each 64 pt tall
  // at most, between status and fields. The type's accent is allowed here.

  /// The ladder: each graded part on the type's one scale, best on the left (43, the CIB ladder).
  public struct LadderSignature: View {
    public struct Rung: Hashable, Sendable {
      public let label: String
      /// The part's step on the scale, from 0 (best); nil when ungraded or missing.
      public let step: Int?
      /// The grade as written, read by VoiceOver.
      public let grade: String?
      /// The part isn't there at all: drawn as a dashed, empty rung.
      public let isMissing: Bool

      public init(label: String, step: Int?, grade: String? = nil, isMissing: Bool = false) {
        self.label = label
        self.step = step
        self.grade = grade
        self.isMissing = isMissing
      }
    }

    let rungs: [Rung]
    let steps: Int
    let accent: TegolaRole
    @Environment(\.tegolaTheme) private var theme

    public init(rungs: [Rung], steps: Int, accent: TegolaRole = .accentConfirm) {
      self.rungs = rungs
      self.steps = max(steps, 1)
      self.accent = accent
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        ForEach(rungs, id: \.self) { rung in
          HStack(spacing: TegolaSpace.s) {
            Text(verbatim: rung.label)
              .tegolaTextStyle(TegolaType.metaSmall)
              .foregroundStyle(TegolaRole.textMeta)
              .frame(minWidth: 84, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 3) {
              ForEach(0..<steps, id: \.self) { index in
                // Filled up to the grade, counted from the worst end: a better grade is a longer bar.
                let filled = rung.step.map { index < steps - $0 } ?? false
                RoundedRectangle(cornerRadius: 2)
                  .fill(theme[filled ? accent : .surfaceSunken].color)
                  .overlay {
                    if rung.isMissing {
                      RoundedRectangle(cornerRadius: 2).strokeBorder(
                        theme[.edgeNotYours].color,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                      )
                    } else {
                      RoundedRectangle(cornerRadius: 2).strokeBorder(theme[.edge].color, lineWidth: 1.5)
                    }
                  }
                  .frame(height: 12)
              }
            }
            .accessibilityHidden(true)
          }
          .accessibilityElement(children: .combine)
          .accessibilityValue(Text(verbatim: rung.grade ?? "—"))
        }
      }
    }
  }

  /// The set: which parts are present, as slots (43's "What's inside": 4 of 6).
  public struct SetSignature: View {
    let slots: [String]
    let present: Set<String>
    @Environment(\.tegolaTheme) private var theme

    public init(slots: [String], present: Set<String>) {
      self.slots = slots
      self.present = present
    }

    public var body: some View {
      HStack(spacing: TegolaSpace.xs) {
        ForEach(slots, id: \.self) { slot in
          let isPresent = present.contains(slot)
          Text(verbatim: slot)
            .tegolaTextStyle(TegolaType.metaSmall)
            .foregroundStyle(isPresent ? TegolaRole.onAccentHighlight : TegolaRole.textMeta)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(theme[isPresent ? .accentHighlight : .surface].color)
            .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.badge))
            .overlay {
              if isPresent {
                RoundedRectangle(cornerRadius: TegolaRadius.badge)
                  .strokeBorder(theme[.edge].color, lineWidth: TegolaBorder.chip)
              } else {
                RoundedRectangle(cornerRadius: TegolaRadius.badge)
                  .strokeBorder(
                    theme[.edgeNotYours].color,
                    style: StrokeStyle(lineWidth: TegolaBorder.chip, dash: TegolaBorder.dash.map { CGFloat($0) })
                  )
              }
            }
        }
      }
      .frame(maxHeight: 64)
      .accessibilityElement(children: .combine)
    }
  }

  /// The History slot's timeline (board 36): a rule down the left, a ringed dot per entry, a mono date and the line.
  public struct Timeline: View {
    public struct Entry: Identifiable {
      public let id: String
      public let date: Text
      public let line: Text

      public init(id: String, date: Text, line: Text) {
        self.id = id
        self.date = date
        self.line = line
      }
    }

    let entries: [Entry]
    @Environment(\.tegolaTheme) private var theme

    public init(_ entries: [Entry]) {
      self.entries = entries
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          HStack(alignment: .top, spacing: TegolaSpace.m) {
            VStack(spacing: 0) {
              Circle()
                .fill(theme[index == 0 ? .accentHighlight : .surfaceRaised].color)
                .overlay(Circle().strokeBorder(theme[.edge].color, lineWidth: TegolaBorder.standard))
                .frame(width: 14, height: 14)
              if index < entries.count - 1 {
                Rectangle().fill(theme[.hairline].color).frame(width: 2).frame(maxHeight: .infinity)
              }
            }
            VStack(alignment: .leading, spacing: 2) {
              entry.date.tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
              entry.line.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, TegolaSpace.l)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
#endif
