public import Foundation

/// The wishlist (F16): wanted objects, which are ordinary objects with ownership `wanted`. Grails first, then by
/// priority (1 is the most wanted; none comes last), then by title. A price cap shows only with money on (promise 5).
/// Wanted objects never count (promise 4).
public struct Wishlist: Hashable, Sendable {
  public struct Want: Hashable, Sendable, Identifiable {
    public let object: ShelfObject
    /// The most the collector would pay, only with money on.
    public let priceCap: Money?
    public var id: ObjectID { object.id }
  }

  public let wants: [Want]

  public init(shelf: Shelf, money: MoneyVisibility) {
    wants = shelf.objects.values
      .filter { $0.ownership == .wanted && $0.letGo == nil }
      .sorted { lhs, rhs in
        if lhs.isGrail != rhs.isGrail { return lhs.isGrail }
        let l = lhs.priority ?? .max
        let r = rhs.priority ?? .max
        if l != r { return l < r }
        return (lhs.title.localizedLowercase, lhs.id) < (rhs.title.localizedLowercase, rhs.id)
      }
      .map { Want(object: $0, priceCap: money == .on ? $0.priceCap : nil) }
  }

  public var isEmpty: Bool { wants.isEmpty }
}

/// Might let go (F16): the private list of what the collector is thinking of parting with. Only what's owned and kept
/// can be on it; by title.
public struct MightLetGo: Hashable, Sendable {
  public let objects: [ShelfObject]

  public init(shelf: Shelf) {
    objects = shelf.objects.values
      .filter { $0.mightLetGo && $0.counts }
      .sorted { ($0.title.localizedLowercase, $0.id) < ($1.title.localizedLowercase, $1.id) }
  }
}

/// The archive (F16): everything let go, the most recent first, grouped by why. It answers *did I ever own this?*;
/// search reaches the same objects. A sale's price only with money on (promise 5).
public struct Archive: Hashable, Sendable {
  /// Why something left, without the price: the groups' keys.
  public enum Why: String, Hashable, Sendable, CaseIterable {
    case sold, gifted, traded, lost, broken
  }

  public struct Entry: Hashable, Sendable, Identifiable {
    public let object: ShelfObject
    public let why: Why
    public let at: Date
    /// What it sold for, only with money on.
    public let price: Money?
    public var id: ObjectID { object.id }
  }

  /// Every let-go object, the most recent first.
  public let entries: [Entry]

  public init(shelf: Shelf, money: MoneyVisibility) {
    entries = shelf.objects.values
      .compactMap { object -> Entry? in
        guard let letGo = object.letGo else { return nil }
        let (why, price): (Why, Money?) =
          switch letGo.reason {
          case .sold(let price): (.sold, price)
          case .gifted: (.gifted, nil)
          case .traded: (.traded, nil)
          case .lost: (.lost, nil)
          case .broken: (.broken, nil)
          }
        return Entry(object: object, why: why, at: letGo.at, price: money == .on ? price : nil)
      }
      .sorted { ($0.at, $0.id) > ($1.at, $1.id) }
  }

  /// The entries for one reason, in the same order; reasons with none are left out.
  public var groups: [(why: Why, entries: [Entry])] {
    Why.allCases.compactMap { why in
      let group = entries.filter { $0.why == why }
      return group.isEmpty ? nil : (why, group)
    }
  }
}
