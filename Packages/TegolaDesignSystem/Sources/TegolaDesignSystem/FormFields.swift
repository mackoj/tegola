#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignTokens

  // Form fields (boards 12, 13): 2.5 pt ink, radius 11, white, Archivo 600 13; a mono label above with the field's
  // kind or an AUTO badge. Fields are typed, never free (board 33's principles).

  /// A field's mono label, with an AUTO badge while a lookup's value is untouched (PD-042).
  public struct FieldLabel: View {
    let label: Text
    let isAuto: Bool

    public init(_ label: Text, isAuto: Bool = false) {
      self.label = label
      self.isAuto = isAuto
    }

    public var body: some View {
      HStack(spacing: TegolaSpace.xs) {
        label.tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        if isAuto {
          Chip(Text("Auto", bundle: .module), fill: .accentHighlight, ink: .onAccentHighlight)
        }
      }
    }
  }

  /// The boxed text input every typed field uses.
  public struct FieldBox<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
      self.content = content()
    }

    public var body: some View {
      content
        .tegolaTextStyle(TegolaType.label)
        .foregroundStyle(TegolaRole.text)
        .padding(.horizontal, TegolaSpace.m)
        .frame(minHeight: TegolaMetrics.minimumHitTarget)
        .printed(radius: TegolaRadius.input, shadow: TegolaShadow.small)
    }
  }

  /// A choice as chips (board 13): one picked, or several for a set. Tapping the picked one again clears it.
  public struct ChoiceChips: View {
    let options: [String]
    let selected: Set<String>
    let toggle: (String) -> Void
    @Environment(\.tegolaTheme) private var theme

    public init(options: [String], selected: Set<String>, toggle: @escaping (String) -> Void) {
      self.options = options
      self.selected = selected
      self.toggle = toggle
    }

    public var body: some View {
      FlowLayout(spacing: TegolaSpace.xs) {
        ForEach(options, id: \.self) { option in
          let isOn = selected.contains(option)
          Button {
            toggle(option)
          } label: {
            Text(verbatim: option)
              .tegolaTextStyle(TegolaType.label)
              .foregroundStyle(isOn ? TegolaRole.textOnStage : TegolaRole.text)
              .padding(.horizontal, TegolaSpace.m)
              .frame(minHeight: 36)
              .printed(fill: isOn ? .surfaceStage : .surfaceRaised, radius: TegolaRadius.pill, shadow: 0)
              .frame(minHeight: TegolaMetrics.minimumHitTarget)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isOn ? .isSelected : [])
        }
      }
    }
  }

  /// Yes or No, with neither picked until the collector says (board 13's yes/no segment).
  public struct YesNoField: View {
    let value: Bool?
    let set: (Bool?) -> Void

    public init(value: Bool?, set: @escaping (Bool?) -> Void) {
      self.value = value
      self.set = set
    }

    public var body: some View {
      HStack(spacing: TegolaSpace.xs) {
        Pill(Text("Yes", bundle: .module), isActive: value == true) { set(value == true ? nil : true) }
        Pill(Text("No", bundle: .module), isActive: value == false) { set(value == false ? nil : false) }
      }
    }
  }

  /// Lays its children out in rows, wrapping at the proposed width: chips that never scroll sideways.
  public struct FlowLayout: Layout {
    let spacing: Double

    public init(spacing: Double) {
      self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
      let width = rows.map { $0.width }.max() ?? 0
      let height = rows.reduce(0) { $0 + $1.height } + spacing * Double(max(rows.count - 1, 0))
      return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
      var y = bounds.minY
      for row in arrange(width: bounds.width, subviews: subviews) {
        var x = bounds.minX
        for index in row.indices {
          let size = subviews[index].sizeThatFits(.unspecified)
          subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
          x += size.width + spacing
        }
        y += row.height + spacing
      }
    }

    struct Row {
      var indices: [Int] = []
      var width: Double = 0
      var height: Double = 0
    }

    func arrange(width: Double, subviews: Subviews) -> [Row] {
      var rows: [Row] = [Row()]
      for index in subviews.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        let added =
          rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
        if added > width, !rows[rows.count - 1].indices.isEmpty {
          rows.append(Row())
        }
        let last = rows.count - 1
        rows[last].width = rows[last].indices.isEmpty ? size.width : rows[last].width + spacing + size.width
        rows[last].height = max(rows[last].height, size.height)
        rows[last].indices.append(index)
      }
      return rows.filter { !$0.indices.isEmpty }
    }
  }
#endif
