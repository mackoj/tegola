#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaInterchange
  import TegolaModel
  import UniformTypeIdentifiers

  /// **Bring your list** (page 49): the file, the one sentence, the payoff.
  @ViewAction(for: ImportFeature.self)
  public struct ImportView: View {
    @Bindable public var store: StoreOf<ImportFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme
    @State private var picking = false

    public init(store: StoreOf<ImportFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        ModalBar(Text("Bring your list", bundle: .module), dismissLabel: Text("Close", bundle: .module)) {
          send(.closeTapped)
        }
        ScrollView {
          VStack(alignment: .leading, spacing: TegolaSpace.l) {
            switch store.step {
            case .pick: pick
            case .reading, .building: progress
            case .sentence: sentence
            case .payoff: payoff
            }
          }
          .padding(.horizontal, TegolaSpace.gutter)
          .padding(.vertical, TegolaSpace.l)
        }
      }
      .background(theme[.surface].color)
      .fileImporter(
        isPresented: $picking,
        allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .utf8PlainText]
      ) { result in
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url) { send(.fileChosen(name: url.lastPathComponent, data: data)) }
      }
    }

    var pick: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        DisplayTitle(
          [Text("Bring your", bundle: .module), Text("list", bundle: .module)],
          style: TegolaType.displaySmall
        )
        Text(
          "A spreadsheet saved as CSV, a Discogs export, or Tegola's own template. Nothing is changed in your file.",
          bundle: .module
        )
        .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
        .fixedSize(horizontal: false, vertical: true)
        Button {
          picking = true
        } label: {
          Text("Choose a file", bundle: .module)
        }
        .buttonStyle(.tegola(.accent))
        .accessibilityIdentifier("import.choose")
        if store.failed {
          Text("That file has nothing Tegola can read. Try a CSV.", bundle: .module)
            .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMeta)
        }
      }
    }

    var progress: some View {
      HStack(spacing: TegolaSpace.s) {
        ProgressView()
        Group {
          if store.step == .reading {
            Text("Reading your list…", bundle: .module)
          } else {
            Text("Building your shelf…", bundle: .module)
          }
        }
        .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
      }
    }

    // MARK: The one sentence (49 §02)

    @ViewBuilder
    var sentence: some View {
      if let plan = store.plan {
        let count = plan.rows.count
        let kind =
          plan.types.first.flatMap { catalogue.manifest($0) }.map { $0.name.plural.lowercased() }
          ?? String(localized: "objects", bundle: .module)
        let shelves = plan.shelves.count
        VStack(alignment: .leading, spacing: TegolaSpace.m) {
          Text(verbatim: store.fileName).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
          Group {
            if shelves > 1 {
              Text("\(count) \(kind) on \(shelves) shelves, into a collection called", bundle: .module)
            } else {
              Text("\(count) \(kind), into a collection called", bundle: .module)
            }
          }
          .tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
          .accessibilityIdentifier("import.sentence")
          TextField(text: $store.collectionName.sending(\.view.renamed)) { Text(verbatim: plan.collectionName) }
            .tegolaTextStyle(TegolaType.displaySmall)
            .padding(.horizontal, TegolaSpace.m)
            .frame(minHeight: TegolaMetrics.minimumHitTarget)
            .notYours(radius: TegolaRadius.input)
            .accessibilityIdentifier("import.name")
          if !plan.guessed.isEmpty {
            Text("Read as", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
            FlowLayout(spacing: TegolaSpace.xs) {
              ForEach(plan.guessed, id: \.self) { guess in
                Chip(Text(verbatim: "\(guess.written) → \(guess.readAs)"))
              }
            }
          }
          Text(
            "They land unconfirmed, as you wrote them. Nothing is merged or invented, and you can undo the whole import for 30 days.",
            bundle: .module
          )
          .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMuted)
          .fixedSize(horizontal: false, vertical: true)
          Button {
            send(.buildTapped)
          } label: {
            Text("Build my shelf", bundle: .module)
          }
          .buttonStyle(.tegola(.accent))
          .accessibilityIdentifier("import.build")
          if store.importers.count > 1 {
            somethingsOff
          }
          if store.failed {
            Text("That didn't save. Try once more.", bundle: .module)
              .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMeta)
          }
        }
      }
    }

    /// **Something's off**: read the file another way.
    var somethingsOff: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("Something's off? Read it as", bundle: .module)
          .tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        FlowLayout(spacing: TegolaSpace.xs) {
          ForEach(store.importers, id: \.self) { importer in
            Pill(name(importer), isActive: store.plan?.importer == importer) { send(.importerTapped(importer)) }
              .accessibilityIdentifier("import.importer.\(importer.rawValue)")
          }
        }
      }
    }

    func name(_ importer: ImporterID) -> Text {
      switch importer.rawValue {
      case "tegola-template": Text("Tegola template", bundle: .module)
      case "discogs-csv": Text("Discogs export", bundle: .module)
      case "spreadsheet": Text("A spreadsheet", bundle: .module)
      default: Text(verbatim: importer.rawValue)
      }
    }

    // MARK: The payoff (49 §05)

    @ViewBuilder
    var payoff: some View {
      if let plan = store.plan {
        VStack(alignment: .leading, spacing: TegolaSpace.m) {
          ScreenHeader(
            eyebrow: Text("On your shelf", bundle: .module),
            title: [Text(verbatim: plan.collectionName)]
          )
          VStack(alignment: .leading, spacing: TegolaSpace.s) {
            Text("\(store.objects.count) objects, unconfirmed until you look", bundle: .module)
              .tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
              .accessibilityIdentifier("import.payoff.count")
            line(
              plan.count(.imperfect),
              Text("\(plan.count(.imperfect)) with something damaged or missing", bundle: .module)
            )
            line(
              plan.count(.duplicate),
              Text("^[\(plan.count(.duplicate)) second copy](inflect: true)", bundle: .module)
            )
            line(plan.count(.signed), Text("\(plan.count(.signed)) signed", bundle: .module))
            line(plan.toSort.count, Text("\(plan.toSort.count) to sort, one tap each", bundle: .module))
            if let matched = store.matched {
              line(matched, Text("\(matched) matched, to confirm in Review", bundle: .module))
            }
          }
          .padding(TegolaSpace.l)
          .frame(maxWidth: .infinity, alignment: .leading)
          .printed(radius: TegolaRadius.card)
          if let undone = store.undone {
            Text("Undone: \(undone.removed) removed, \(undone.kept) kept because you changed them.", bundle: .module)
              .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.text)
              .accessibilityIdentifier("import.undone")
          } else {
            Button {
              send(.undoTapped)
            } label: {
              Text("Undo this import", bundle: .module)
            }
            .buttonStyle(.tegola(.secondary))
            .accessibilityIdentifier("import.undo")
          }
          Button {
            send(.doneTapped)
          } label: {
            Text("See my shelf", bundle: .module)
          }
          .buttonStyle(.tegola(.accent))
          .accessibilityIdentifier("import.done")
        }
      }
    }

    @ViewBuilder
    func line(_ count: Int, _ text: Text) -> some View {
      if count > 0 { text.tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.text) }
    }
  }
#endif
