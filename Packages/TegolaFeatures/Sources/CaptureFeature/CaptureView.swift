#if canImport(SwiftUI)
  public import ComposableArchitecture
  import ShelfViews
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  #if canImport(VisionKit) && os(iOS)
    import VisionKit
  #endif

  /// The Scan sheet (board 06's camera, PLAN F6): Add to, the live scanner, Identify?, the shutter, and the tray.
  @ViewAction(for: CaptureFeature.self)
  public struct CaptureView: View {
    @Bindable public var store: StoreOf<CaptureFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme
    @State private var shutter = ShutterTrigger()

    public init(store: StoreOf<CaptureFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        ModalBar(Text("Scan", bundle: .module), dismissLabel: Text("Close", bundle: .module)) { send(.closeTapped) }
        ScrollView {
          VStack(alignment: .leading, spacing: TegolaSpace.l) {
            addTo
            if store.type != nil {
              scanner
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.cardLarge))
                .printed(radius: TegolaRadius.cardLarge)
              seenLine
              controls
            }
            if !store.tray.isEmpty { tray }
            Button {
              send(.typeItTapped)
            } label: {
              Text("Type it", bundle: .module)
            }
            .buttonStyle(.tegola(.quiet))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("capture.typeIt")
          }
          .padding(.horizontal, TegolaSpace.gutter)
          .padding(.vertical, TegolaSpace.l)
        }
      }
      .background(theme[.surface].color)
    }

    /// **Add to**: the type, then where it goes, remembered from last time (F6).
    var addTo: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("Add to", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        FlowLayout(spacing: TegolaSpace.xs) {
          ForEach(Catalogue.enabledInV1, id: \.self) { type in
            Pill(
              Text(verbatim: catalogue.manifest(type).map { $0.name.hobby ?? $0.name.plural } ?? type.rawValue),
              isActive: store.type == type
            ) { send(.typeTapped(type)) }
            .accessibilityIdentifier("capture.type.\(type.rawValue)")
          }
        }
        if case .existing(let id) = store.collection, let collection = store.snapshot.shelf.collections[id] {
          Text(verbatim: "→ \(collection.name)").tegolaTextStyle(TegolaType.label).foregroundStyle(TegolaRole.text)
        } else if case .new(let name) = store.collection {
          Text("→ \(name) (new)", bundle: .module).tegolaTextStyle(TegolaType.label).foregroundStyle(TegolaRole.text)
        }
      }
    }

    var hasScanner: Bool {
      #if canImport(VisionKit) && os(iOS)
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
      #else
        false
      #endif
    }

    @ViewBuilder
    var scanner: some View {
      #if canImport(VisionKit) && os(iOS)
        if hasScanner {
          LiveScanner(trigger: shutter, recognised: { send(.recognised($0)) }, shot: { send(.shutterTapped(photo: $0)) })
        } else {
          noCamera
        }
      #else
        noCamera
      #endif
    }

    var noCamera: some View {
      theme[.surfaceCamera].color.overlay {
        Text("No camera here. Type it instead.", bundle: .module)
          .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textOnStage)
      }
    }

    @ViewBuilder
    var seenLine: some View {
      switch store.seen {
      case .barcode(let code):
        Text("Barcode \(code)", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
      case .text(let text):
        Text(verbatim: text.split(separator: "\n").prefix(2).joined(separator: " · "))
          .tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
      case nil:
        Text("Point it at a barcode or a label.", bundle: .module)
          .tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
      }
    }

    var controls: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Toggle(isOn: $store.identify.sending(\.view.identifyToggled)) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Identify?", bundle: .module).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
            Text("Sends this photo to look it up. Off again after the shot.", bundle: .module)
              .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.textMuted)
          }
        }
        .accessibilityIdentifier("capture.identify")
        Button {
          // With the live scanner, its photo; without one (the simulator), the object is saved from what was read.
          if hasScanner { shutter.fire() } else { send(.shutterTapped(photo: nil)) }
        } label: {
          Text("Save this one", bundle: .module)
        }
        .buttonStyle(.tegola(.accent))
        .disabled(store.isSaving)
        .accessibilityIdentifier("capture.shutter")
      }
    }

    /// The tray (F6): the camera stays open, and each saved object waits here with what its lookup said.
    var tray: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("\(store.tray.count) saved", bundle: .module)
          .tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
          .accessibilityIdentifier("capture.trayCount")
        ForEach(store.tray) { item in
          Button {
            send(.trayItemTapped(item.id))
          } label: {
            HStack {
              status(item.status).tegolaTextStyle(TegolaType.label).foregroundStyle(TegolaRole.text)
              Spacer()
              Text(verbatim: "→").foregroundStyle(TegolaRole.textMuted)
            }
            .padding(TegolaSpace.m)
            .frame(minHeight: TegolaMetrics.minimumHitTarget)
            .printed(radius: TegolaRadius.card)
          }
          .buttonStyle(.plain)
        }
      }
    }

    func status(_ status: CaptureFeature.TrayItem.Status) -> Text {
      switch status {
      case .queued: Text("Saved · looking it up when there's a signal", bundle: .module)
      case .identifying: Text("Saved · identifying…", bundle: .module)
      case .proposed(let title): Text("Maybe \(title)? Confirm it in Review.", bundle: .module)
      case .nothingFound: Text("Saved · needs details", bundle: .module)
      }
    }
  }

  /// Fires the live scanner's capture from the Save button.
  @Observable
  final class ShutterTrigger {
    var count = 0
    func fire() { count += 1 }
  }

  #if canImport(VisionKit) && os(iOS)
    /// VisionKit's data scanner: barcodes and text, recognised live; the shutter takes a photo of what it sees.
    struct LiveScanner: UIViewControllerRepresentable {
      let trigger: ShutterTrigger
      let recognised: (CaptureFeature.Seen?) -> Void
      let shot: (Data?) -> Void

      func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
          recognizedDataTypes: [.barcode(), .text()],
          qualityLevel: .balanced,
          isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
      }

      func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard trigger.count != context.coordinator.fired else { return }
        context.coordinator.fired = trigger.count
        let shot = shot
        Task { @MainActor in
          let image = try? await scanner.capturePhoto()
          shot(image.flatMap { JPEGEncoding.encoded($0) })
        }
      }

      static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
      }

      func makeCoordinator() -> Coordinator { Coordinator(recognised: recognised) }

      @MainActor
      final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let recognised: (CaptureFeature.Seen?) -> Void
        var fired = 0

        init(recognised: @escaping (CaptureFeature.Seen?) -> Void) { self.recognised = recognised }

        func dataScanner(
          _ scanner: DataScannerViewController,
          didUpdate updated: [RecognizedItem],
          allItems: [RecognizedItem]
        ) {
          report(allItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
          report(allItems)
        }

        func dataScanner(
          _ scanner: DataScannerViewController,
          didRemove removed: [RecognizedItem],
          allItems: [RecognizedItem]
        ) {
          report(allItems)
        }

        /// A barcode wins over text: it's the surer lookup.
        func report(_ items: [RecognizedItem]) {
          var barcode: String?
          var lines: [String] = []
          for item in items {
            switch item {
            case .barcode(let code): barcode = barcode ?? code.payloadStringValue
            case .text(let text): lines.append(text.transcript)
            @unknown default: continue
            }
          }
          if let barcode {
            recognised(.barcode(barcode))
          } else if !lines.isEmpty {
            recognised(.text(lines.prefix(12).joined(separator: "\n")))
          } else {
            recognised(nil)
          }
        }
      }
    }

    /// A shot as the shelf keeps it: 2048 px, JPEG, without the original's metadata (D-72).
    enum JPEGEncoding {
      static func encoded(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 2048 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { _ in
          image.draw(in: CGRect(origin: .zero, size: size))
        }
      }
    }
  #endif
#endif
