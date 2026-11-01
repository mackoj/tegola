public import ComposableArchitecture
public import Foundation
public import SQLiteData
import TegolaCatalogue
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// Sharing one object (F14, D-78): **Share the record** or **Share my copy**, as a card image through the share sheet.
/// One-sided: no link, nothing to revoke (PD-160). My copy is offered only for something the collector owns, and an
/// asking price only with money on.
@Reducer
public struct ShareFeature {
  @ObservableState
  public struct State: Equatable {
    public let objectID: ObjectID
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    public var kind: ShareCard.Kind = .record
    /// The asking price as typed, in the collector's currency.
    public var asking: Decimal?

    public init(objectID: ObjectID) {
      self.objectID = objectID
    }

    public var object: ShelfObject? { snapshot.shelf.objects[objectID] }

    /// My copy is the collector's own: not something wanted or borrowed.
    public var offersMyCopy: Bool { object?.ownership == .owned }

    /// The asking price field shows only on my copy with money on (F14, promise 5).
    public var asksForPrice: Bool { kind == .myCopy && snapshot.money == .on }

    /// The asking price as money, in the collector's currency.
    public var askingPrice: Money? {
      @Dependency(\.locale) var locale
      guard let asking, let currency = Currency(locale.currency?.identifier ?? "EUR") else { return nil }
      return Money(amount: asking, currency: currency)
    }

    public var card: ShareCard? {
      @Dependency(\.catalogue) var catalogue
      guard let object, let manifest = catalogue.manifest(object.typeID),
        let type = try? catalogue.resolve(object.typeID, subtype: object.subtype)
      else { return nil }
      return ShareCard(
        kind,
        object: object,
        type: type,
        manifest: manifest,
        shelf: snapshot.shelf,
        money: snapshot.money,
        askingPrice: askingPrice
      )
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.objectID == rhs.objectID && lhs.kind == rhs.kind && lhs.asking == rhs.asking
    }
  }

  public enum Action: ViewAction {
    case view(View)

    public enum View: Equatable {
      case askingChanged(Decimal?)
      case closeTapped
      case kindTapped(ShareCard.Kind)
    }
  }

  @Dependency(\.dismiss) var dismiss

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.askingChanged(let asking)):
        state.asking = asking
        return .none
      case .view(.closeTapped):
        return .run { [dismiss] _ in await dismiss() }
      case .view(.kindTapped(let kind)):
        guard kind == .record || state.offersMyCopy else { return .none }
        state.kind = kind
        return .none
      }
    }
  }
}
