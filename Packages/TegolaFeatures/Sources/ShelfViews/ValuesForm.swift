#if canImport(SwiftUI)
  public import Dependencies
  public import SwiftUI
  public import TegolaCatalogue
  import TegolaDesignSystem
  import TegolaDesignTokens
  public import TegolaModel

  /// The fields of one object as a form: one control per field kind over the resolved type (F5, board 13). The edit
  /// form and Add by hand both use it; it holds no state, and every change goes back through its closures.
  public struct ValuesForm: View {
    let manifest: TypeManifest
    let type: EffectiveType
    let money: MoneyVisibility
    let draft: [FieldKey: FieldValue]
    let original: [FieldKey: FieldValue]
    let auto: Set<FieldKey>
    let place: String
    let revealed: Set<String>
    let change: (FieldKey, FieldValue?) -> Void
    let changePlace: (String) -> Void
    let reveal: (String) -> Void
    @Dependency(\.locale) var locale

    public init(
      manifest: TypeManifest,
      type: EffectiveType,
      money: MoneyVisibility,
      draft: [FieldKey: FieldValue],
      original: [FieldKey: FieldValue] = [:],
      auto: Set<FieldKey> = [],
      place: String,
      revealed: Set<String>,
      change: @escaping (FieldKey, FieldValue?) -> Void,
      changePlace: @escaping (String) -> Void,
      reveal: @escaping (String) -> Void
    ) {
      self.manifest = manifest
      self.type = type
      self.money = money
      self.draft = draft
      self.original = original
      self.auto = auto
      self.place = place
      self.revealed = revealed
      self.change = change
      self.changePlace = changePlace
      self.reveal = reveal
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        spine(manifest)
        condition(type)
        ForEach(type.visibleFields.filter { $0.field.kind != .scale }, id: \.key) { field in
          row(field.field, key: .field(field.key))
        }
        placeField(manifest)
        notes
        itemLevel(type)
      }
    }

    // The spine, relabelled by the type (PD-129). Paid and value only with money on (PD-080).
    @ViewBuilder
    func spine(_ manifest: TypeManifest) -> some View {
      textRow(Text(verbatim: manifest.spine.title), key: .title, identifier: "edit.title")
      if let subtitle = manifest.spine.subtitle { textRow(Text(verbatim: subtitle), key: .subtitle) }
      labelled(Text(verbatim: manifest.spine.year ?? String(localized: "Year", bundle: .module)), key: .year) {
        yearField(.year)
      }
      labelled(
        Text(verbatim: manifest.spine.acquired ?? String(localized: "Acquired", bundle: .module)),
        key: .acquired
      ) {
        dateField(.acquired)
      }
      if money == .on {
        labelled(Text(verbatim: manifest.spine.paid ?? String(localized: "Paid", bundle: .module)), key: .paid) {
          moneyField(.paid)
        }
        labelled(Text(verbatim: manifest.spine.value ?? String(localized: "Value", bundle: .module)), key: .value) {
          moneyField(.value)
        }
      }
    }

    // The hobby's real scale: one grade, or one per ladder part (43).
    @ViewBuilder
    func condition(_ type: EffectiveType) -> some View {
      let steps = type.conditions
      let axes = type.signatures.first { $0.renderer == SignatureRenderer.ladder.rawValue }?.axes ?? []
      if axes.isEmpty {
        labelled(Text("Condition", bundle: .module), key: .condition) { scaleChips(.condition, steps: steps) }
      } else {
        ForEach(axes, id: \.self) { axis in
          labelled(Text(verbatim: type.field(axis)?.field.label ?? axis), key: .axis(axis)) {
            scaleChips(.axis(axis), steps: type.ladderSteps)
          }
        }
      }
    }

    func placeField(_ manifest: TypeManifest) -> some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        FieldLabel(Text(verbatim: manifest.placeLabel ?? String(localized: "Place", bundle: .module)))
        FieldBox {
          TextField(
            text: Binding(get: { place }, set: { changePlace($0) }),
            prompt: Text("Office › Shelf 2", bundle: .module),
            label: { Text("Place", bundle: .module) }
          )
        }
        .accessibilityIdentifier("edit.place")
      }
    }

    var notes: some View {
      labelled(Text("Notes", bundle: .module), key: .notes) {
        FieldBox {
          TextField(
            text: textBinding(.notes),
            axis: .vertical,
            label: { Text("Notes", bundle: .module) }
          )
          .lineLimit(3...8)
          .padding(.vertical, TegolaSpace.s)
        }
      }
    }

    // The item level: shown once it has a value, otherwise "+ Add" (page 48).
    @ViewBuilder
    func itemLevel(_ type: EffectiveType) -> some View {
      ForEach(type.addableFields, id: \.key) { field in
        let key = FieldKey.field(field.key)
        if draft[key] != nil || revealed.contains(field.key) {
          row(field.field, key: key)
        } else {
          DashedButton(Text("+ \(field.field.label)", bundle: .module)) { reveal(field.key) }
            .accessibilityIdentifier("edit.add.\(field.key)")
        }
      }
    }

    // One control per field kind (board 13, one roof's shared kit).
    @ViewBuilder
    func row(_ field: TypeManifest.Field, key: FieldKey) -> some View {
      labelled(Text(verbatim: field.label), key: key) {
        switch field.kind {
        case .text, .dims:
          FieldBox { TextField(text: textBinding(key), label: { Text(verbatim: field.label) }) }
        case .number:
          numberField(key, unit: field.unit)
        case .choice:
          let picked: Set<String> = if case .text(let v) = draft[key] { [v] } else { [] }
          ChoiceChips(options: field.options, selected: picked) { option in
            change(key, picked.contains(option) ? nil : .text(option))
          }
        case .set:
          let picked: Set<String> = if case .options(let v) = draft[key] { Set(v) } else { [] }
          ChoiceChips(options: field.options, selected: picked) { option in
            let next = picked.symmetricDifference([option])
            change(key, next.isEmpty ? nil : .options(field.options.filter(next.contains)))
          }
        case .yesNo:
          let value: Bool? = if case .flag(let v) = draft[key] { v } else { nil }
          YesNoField(value: value) { change(key, $0.map(FieldValue.flag)) }
        case .date, .event:
          dateField(key)
        case .year:
          yearField(key)
        case .yearRange:
          yearRangeField(key)
        case .list, .log:
          EntriesEditor(
            parts: field.entry.isEmpty ? ["note"] : field.entry,
            entries: { if case .entries(let e) = draft[key] { e } else { [] } }(),
            set: { change(key, $0.isEmpty ? nil : .entries($0)) }
          )
        case .money:
          moneyField(key)
        case .photo, .composite, .files, .scale:
          Text("Not editable here yet", bundle: .module)
            .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMeta)
        }
      }
    }

    func labelled(_ label: Text, key: FieldKey, @ViewBuilder content: () -> some View) -> some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        FieldLabel(label, isAuto: auto.contains(key) && draft[key] == original[key])
        content()
      }
    }

    func textRow(_ label: Text, key: FieldKey, identifier: String? = nil) -> some View {
      labelled(label, key: key) {
        FieldBox { TextField(text: textBinding(key), label: { label }) }
          .accessibilityIdentifier(identifier ?? "edit.\(key)")
      }
    }

    func textBinding(_ key: FieldKey) -> Binding<String> {
      Binding(
        get: { if case .text(let t) = draft[key] { t } else { "" } },
        set: { change(key, $0.isEmpty ? nil : .text($0)) }
      )
    }

    func scaleChips(_ key: FieldKey, steps: [String]) -> some View {
      let picked: Set<String> = if case .text(let v) = draft[key] { [v] } else { [] }
      return ChoiceChips(options: steps, selected: picked) { step in
        change(key, picked.contains(step) ? nil : .text(step))
      }
    }

    func numberField(_ key: FieldKey, unit: String?) -> some View {
      FieldBox {
        HStack {
          TextField(
            value: Binding(
              get: { if case .number(let n) = draft[key] { n } else { nil } },
              set: { change(key, $0.map(FieldValue.number)) }
            ),
            format: .number,
            label: { Text(verbatim: unit ?? "") }
          )
          if let unit { Text(verbatim: unit).foregroundStyle(TegolaRole.textMeta) }
        }
      }
    }

    func yearField(_ key: FieldKey) -> some View {
      FieldBox {
        TextField(
          value: Binding(
            get: { if case .year(let y) = draft[key] { y } else { nil } },
            set: { change(key, $0.map(FieldValue.year)) }
          ),
          format: .number.grouping(.never),
          label: { Text("Year", bundle: .module) }
        )
      }
      .accessibilityIdentifier("edit.\(key)")
    }

    func yearRangeField(_ key: FieldKey) -> some View {
      let range: (Int, Int)? = if case .yearRange(let a, let b) = draft[key] { (a, b) } else { nil }
      return HStack {
        FieldBox {
          TextField(
            value: Binding(
              get: { range?.0 },
              set: { change(key, $0.map { .yearRange(from: $0, to: range?.1 ?? $0) }) }
            ),
            format: .number.grouping(.never),
            label: { Text("From", bundle: .module) }
          )
        }
        FieldBox {
          TextField(
            value: Binding(
              get: { range?.1 },
              set: { change(key, $0.map { .yearRange(from: range?.0 ?? $0, to: $0) }) }
            ),
            format: .number.grouping(.never),
            label: { Text("To", bundle: .module) }
          )
        }
      }
    }

    @ViewBuilder
    func dateField(_ key: FieldKey) -> some View {
      if case .date(let date) = draft[key] {
        HStack {
          DatePicker(
            selection: Binding(get: { date }, set: { change(key, .date($0)) }),
            displayedComponents: .date,
            label: { EmptyView() }
          )
          .labelsHidden()
          Button {
            change(key, nil)
          } label: {
            Text("Clear", bundle: .module)
          }
          .buttonStyle(.tegola(.quiet)).fixedSize()
        }
      } else {
        // The app never fills a date by itself (PD-165): an empty date stays empty until the collector picks one.
        DashedButton(Text("Pick a date", bundle: .module)) {
          @Dependency(\.date.now) var now
          change(key, .date(now))
        }
      }
    }

    func moneyField(_ key: FieldKey) -> some View {
      let money: Money? = if case .money(let m) = draft[key] { m } else { nil }
      let code = money?.currency.code ?? locale.currency?.identifier ?? "EUR"
      return FieldBox {
        HStack {
          Text(verbatim: code).foregroundStyle(TegolaRole.textMeta)
          TextField(
            value: Binding(
              get: { money?.amount },
              set: { amount in
                let currency = Currency(code)
                change(
                  key,
                  amount.flatMap { a in currency.map { Money(amount: a, currency: $0) } }.map(FieldValue.money)
                )
              }
            ),
            format: .number,
            label: { Text(verbatim: code) }
          )
        }
      }
    }
  }

  /// A list's or a log's entries: one row per entry, a field per part, "+ Add entry" (board 13's ListField).
  struct EntriesEditor: View {
    let parts: [String]
    let entries: [[String: String]]
    let set: ([[String: String]]) -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        ForEach(entries.indices, id: \.self) { index in
          HStack(spacing: TegolaSpace.xs) {
            ForEach(parts, id: \.self) { part in
              FieldBox {
                TextField(
                  text: Binding(
                    get: { entries[index][part] ?? "" },
                    set: { value in
                      var next = entries
                      next[index][part] = value.isEmpty ? nil : value
                      set(next)
                    }
                  ),
                  label: { Text(verbatim: part) }
                )
              }
            }
            Button {
              var next = entries
              next.remove(at: index)
              set(next)
            } label: {
              Image(systemName: "xmark").frame(
                width: TegolaMetrics.minimumHitTarget,
                height: TegolaMetrics.minimumHitTarget
              )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove", bundle: .module))
          }
        }
        DashedButton(Text("+ Add entry", bundle: .module)) { set(entries + [[:]]) }
      }
    }
  }

#endif
