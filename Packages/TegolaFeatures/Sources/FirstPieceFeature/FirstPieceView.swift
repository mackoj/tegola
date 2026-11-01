#if canImport(SwiftUI)
  public import ComposableArchitecture
  import PhotosUI
  import ShelfViews
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel

  /// The first piece's screens (PLAN F2, page 46; D-72). Page 46's board is missing from the archive, so the layout
  /// follows the shared components: display titles, printed cards, pills and the dashed field.
  @ViewAction(for: FirstPieceFeature.self)
  public struct FirstPieceView: View {
    @Bindable public var store: StoreOf<FirstPieceFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme
    @State private var library: PhotosPickerItem?
    @FocusState private var nameFocused: Bool

    public init(store: StoreOf<FirstPieceFeature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.xl) {
          if [.recognised, .whatIsIt, .story].contains(store.step) {
            HStack {
              Spacer()
              ActionButton(.close, id: "firstPiece.close") { send(.closeTapped) }
            }
          }
          switch store.step {
          case .ask: ask
          case .reading: reading
          case .recognised: recognised
          case .whatIsIt: whatIsIt
          case .story: story
          case .notShipped: notShipped
          case .payoff: payoff
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.l)
        .padding(.bottom, TegolaSpace.xxl)
      }
      .background(theme[.surface].color)
      .onChange(of: library) { _, item in
        guard let item else { return }
        Task {
          // A library photo is re-encoded like a shot: 2048 px, and none of its metadata, location included (D-72).
          if let data = try? await item.loadTransferable(type: Data.self), let jpeg = reencoded(data) {
            send(.photoTaken(jpeg))
          }
          library = nil
        }
      }
    }

    // MARK: 1 · One question

    var ask: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        ScreenHeader(
          eyebrow: Text("Welcome to Tegola", bundle: .module),
          title: [
            Text("Show us", bundle: .module), Text("something", bundle: .module), Text("you love", bundle: .module),
          ],
          body: Text("Just one thing, the one with a story. Hold it up.", bundle: .module)
        )
        camera
          .frame(height: 360)
          .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.cardLarge))
          .printed(radius: TegolaRadius.cardLarge)
        ButtonPair {
          Button {
            send(.typeItTapped)
          } label: {
            Text("Type it", bundle: .module)
          }
          .buttonStyle(.tegola(.primary))
          .accessibilityIdentifier("firstPiece.typeIt")
        } trailing: {
          PhotosPicker(selection: $library, matching: .images) {
            Text("Library", bundle: .module)
          }
          .buttonStyle(.tegola(.secondary))
          .accessibilityIdentifier("firstPiece.library")
        }
        Button {
          send(.lookAroundTapped)
        } label: {
          Text("Just look around first", bundle: .module)
        }
        .buttonStyle(.tegola(.quiet))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("firstPiece.lookAround")
      }
    }

    @ViewBuilder
    var camera: some View {
      #if os(iOS)
        CameraView { data in send(.photoTaken(data)) }
      #else
        theme[.surfaceCamera].color
      #endif
    }

    var reading: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        photo
        HStack(spacing: TegolaSpace.s) {
          ProgressView()
          Text("Having a look…", bundle: .module).tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
        }
      }
    }

    @ViewBuilder
    var photo: some View {
      #if os(iOS)
        if let data = store.photo, let image = UIImage(data: data) {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.card))
            .printed(radius: TegolaRadius.card)
            .accessibilityHidden(true)
        }
      #endif
    }

    // MARK: 2 · Recognise, then ask why

    var recognised: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        photo
        Text("Is this it?", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        VStack(alignment: .leading, spacing: TegolaSpace.s) {
          Text(verbatim: store.name)
            .tegolaTextStyle(TegolaType.displaySmall)
            .foregroundStyle(TegolaRole.text)
            .accessibilityIdentifier("firstPiece.guessName")
          HStack(spacing: TegolaSpace.xs) {
            if let type = store.type { Chip(typeName(type)) }
            if let year = store.year { Chip(Text(verbatim: String(year))) }
          }
        }
        ButtonPair {
          Button {
            send(.thatsItTapped)
          } label: {
            Text("That's it", bundle: .module)
          }
          .buttonStyle(.tegola(.confirm))
          .accessibilityIdentifier("firstPiece.thatsIt")
        } trailing: {
          Button {
            send(.notQuiteTapped)
          } label: {
            Text("Not quite", bundle: .module)
          }
          .buttonStyle(.tegola(.secondary))
          .accessibilityIdentifier("firstPiece.notQuite")
        }
      }
    }

    var whatIsIt: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        photo
        DisplayTitle([Text("What is it?", bundle: .module)], style: TegolaType.displaySmall)
        TextField(text: $store.name.sending(\.view.nameChanged)) {
          Text("Its name, as you'd say it", bundle: .module)
        }
        .tegolaTextStyle(TegolaType.label)
        .padding(.horizontal, TegolaSpace.m)
        .frame(minHeight: TegolaMetrics.minimumHitTarget)
        .notYours(radius: TegolaRadius.input)
        .focused($nameFocused)
        .submitLabel(.next)
        .onSubmit { send(.nextTapped) }
        .accessibilityIdentifier("firstPiece.name")
        TextField(text: Binding(get: { store.year.map(String.init) ?? "" }, set: { send(.yearChanged($0)) })) {
          Text("Year, if you know it", bundle: .module)
        }
        #if os(iOS)
          .keyboardType(.numberPad)
        #endif
        .tegolaTextStyle(TegolaType.label)
        .padding(.horizontal, TegolaSpace.m)
        .frame(minHeight: TegolaMetrics.minimumHitTarget)
        .printed(radius: TegolaRadius.input, shadow: TegolaShadow.small)
        .accessibilityIdentifier("firstPiece.year")
        VStack(alignment: .leading, spacing: TegolaSpace.s) {
          Text("It's…", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
          FlowLayout(spacing: TegolaSpace.xs) {
            ForEach(typeChoices, id: \.self) { type in
              Pill(typeName(type), isActive: store.type == type) { send(.typeTapped(type)) }
                .accessibilityIdentifier("firstPiece.type.\(type.rawValue)")
            }
          }
        }
        Button {
          send(.nextTapped)
        } label: {
          Text("Next", bundle: .module)
        }
        .buttonStyle(.tegola(.accent))
        .disabled(!store.canContinue)
        .accessibilityIdentifier("firstPiece.next")
        if !store.canContinue {
          Text("Give it a name to go on.", bundle: .module)
            .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMeta)
        }
      }
      .onAppear { nameFocused = true }
    }

    /// The types a piece can be picked as: v1's three, then the guess when it hasn't shipped, then Thing.
    var typeChoices: [TypeManifest.ID] {
      var types: [TypeManifest.ID] = ["music", "video-game", "board-games"]
      if let guess = store.guess?.type, !types.contains(guess), guess != "thing" { types.append(guess) }
      return types + ["thing"]
    }

    func typeName(_ type: TypeManifest.ID) -> Text {
      Text(verbatim: catalogue.manifest(type).map { $0.name.hobby ?? $0.name.plural } ?? type.rawValue)
    }

    var story: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        Text(verbatim: store.name).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        DisplayTitle(
          [Text("How did it", bundle: .module), Text("come to you?", bundle: .module)],
          style: TegolaType.displaySmall
        )
        FlowLayout(spacing: TegolaSpace.xs) {
          ForEach(FirstPieceFeature.StoryChip.allCases, id: \.self) { chip in
            Pill(Text(verbatim: chip.words), isActive: store.chip == chip) { send(.chipTapped(chip)) }
              .accessibilityIdentifier("firstPiece.story.\(chip.rawValue)")
          }
        }
        TextField(text: $store.line.sending(\.view.lineChanged), axis: .vertical) {
          Text("A line about it, if you like", bundle: .module)
        }
        .tegolaTextStyle(TegolaType.label)
        .padding(TegolaSpace.m)
        .frame(minHeight: TegolaMetrics.minimumHitTarget)
        .printed(radius: TegolaRadius.input, shadow: TegolaShadow.small)
        .accessibilityIdentifier("firstPiece.line")
        Text("It's the first line of its history. It isn't when you got it.", bundle: .module)
          .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMeta)
        Button {
          send(.saveTapped)
        } label: {
          Text("Put it on the shelf", bundle: .module)
        }
        .buttonStyle(.tegola(.accent))
        .disabled(store.isSaving)
        .accessibilityIdentifier("firstPiece.save")
        if store.saveFailed || (store.refusal != nil && store.refusal != .notTheFirstPiece) {
          Text("That didn't save. Try once more.", bundle: .module)
            .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMeta)
        }
      }
    }

    // MARK: 2B · Type not shipped yet

    var notShipped: some View {
      let type = store.awaiting.flatMap { catalogue.manifest($0)?.name.plural } ?? ""
      return VStack(alignment: .leading, spacing: TegolaSpace.l) {
        DisplayTitle([Text(verbatim: store.name)], style: TegolaType.displaySmall)
        Text("\(type) aren't a full type yet. It's saved safely as a Thing.", bundle: .module)
          .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.text)
          .fixedSize(horizontal: false, vertical: true)
        Text(
          "Want to test \(type) when they're ready? Your pieces will be the first offered the upgrade.",
          bundle: .module
        )
        .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
        .fixedSize(horizontal: false, vertical: true)
        ButtonPair {
          Button {
            send(.countMeInTapped)
          } label: {
            Text("Count me in", bundle: .module)
          }
          .buttonStyle(.tegola(.primary))
          .accessibilityIdentifier("firstPiece.countMeIn")
        } trailing: {
          ActionButton(.notNow, id: "firstPiece.notNow") { send(.notNowTapped) }
        }
      }
      .padding(TegolaSpace.l)
      .printed(fill: .accentHighlight, radius: TegolaRadius.card)
    }

    // MARK: 3 · The payoff, then momentum

    var payoff: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        ScreenHeader(
          eyebrow: Text("Your shelf · 1 piece", bundle: .module),
          title: [Text(verbatim: store.name)]
        )
        VStack(alignment: .leading, spacing: TegolaSpace.s) {
          payoffLine
          if !store.story.isEmpty {
            Text(verbatim: store.story)
              .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
              .accessibilityIdentifier("firstPiece.payoff.story")
          }
        }
        .padding(TegolaSpace.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printed(radius: TegolaRadius.card)
        HStack(spacing: TegolaSpace.m) {
          ForEach(0..<3, id: \.self) { _ in
            RoundedRectangle(cornerRadius: TegolaRadius.card).fill(.clear)
              .frame(height: 72)
              .notYours(radius: TegolaRadius.card)
          }
        }
        .accessibilityHidden(true)
        Button {
          send(.oneAtATimeTapped)
        } label: {
          Text("One at a time", bundle: .module)
        }
        .buttonStyle(.tegola(.accent))
        .accessibilityIdentifier("firstPiece.oneAtATime")
        Button {
          send(.thatsEnoughTapped)
        } label: {
          Text("That's enough for today", bundle: .module)
        }
        .buttonStyle(.tegola(.quiet))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("firstPiece.enough")
      }
    }

    @ViewBuilder
    var payoffLine: some View {
      switch store.payoff?.line {
      case .now(let signal):
        HStack(spacing: TegolaSpace.s) {
          StatusChip(signal.status.swatch, label: signal.title)
          EstimateLabel()
        }
        signal.reasonText.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
      case .later(_, let from):
        HStack(spacing: TegolaSpace.s) {
          Text("Not yet. Soon.", bundle: .module).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
          EstimateLabel()
        }
        Text("Around \(from, format: .dateTime.month(.wide).year()). We'll tell you when it's time.", bundle: .module)
          .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.text)
      case nil:
        Text("It's on the shelf.", bundle: .module).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
      }
    }
  }

  /// A library photo, as the camera would have kept it.
  func reencoded(_ data: Data) -> Data? {
    #if os(iOS)
      JPEG.resized(data)
    #else
      data
    #endif
  }

  #Preview("One question") {
    FirstPieceView(store: Store(initialState: FirstPieceFeature.State()) { FirstPieceFeature() })
  }
#endif
