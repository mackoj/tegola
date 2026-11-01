public import Foundation
public import TegolaCatalogue

/// The inventory document (F17): a dated list of what the collector owns, for an insurer. Each object with its photo,
/// condition, provenance, place and the price paid. It says plainly that it isn't an appraisal; there are no market
/// values in v1 (PD-138). Only what counts is on it: wanted, borrowed and let-go objects never are (promise 4).
public struct InventoryDocument: Hashable, Sendable {
  public struct Item: Hashable, Sendable, Identifiable {
    public let id: ObjectID
    public let title: String
    public let typeID: TypeManifest.ID
    public let subtype: String?
    /// Copies, for a count; 1 for a row.
    public let quantity: Int
    /// The hero photo's file name in the photo store.
    public let photo: String?
    /// The condition as graded: the single grade, or each ladder part's ("Box: Very good").
    public let condition: [String]
    /// When it was acquired, when the collector said.
    public let acquired: Date?
    /// Where it lives, as a path.
    public let place: String?
    /// What was paid, when recorded.
    public let paid: Money?
  }

  public struct Section: Hashable, Sendable, Identifiable {
    public let id: CollectionID
    public let name: String
    public let items: [Item]
  }

  public let date: Date
  /// One section per collection with something in it, by the shelf's order.
  public let sections: [Section]
  /// What was paid, added per currency, never across currencies.
  public let paidTotals: [Money]
  /// Objects on the document, copies counted.
  public let count: Int

  public init(shelf: Shelf, catalogue: Catalogue, date: Date) {
    self.date = date
    let counted = shelf.objects.values.filter(\.counts)
    sections = shelf.collections.values
      .sorted { ($0.sortKey, $0.name) < ($1.sortKey, $1.name) }
      .compactMap { collection in
        let items = counted.filter { $0.collectionID == collection.id }
          .sorted { ($0.title.localizedLowercase, $0.id) < ($1.title.localizedLowercase, $1.id) }
          .map { Self.item($0, shelf: shelf, catalogue: catalogue) }
        return items.isEmpty ? nil : Section(id: collection.id, name: collection.name, items: items)
      }
    let items = sections.flatMap(\.items)
    paidTotals = Money.totals(items.compactMap(\.paid))
    count = TegolaModel.count(counted)
  }

  static func item(_ object: ShelfObject, shelf: Shelf, catalogue: Catalogue) -> Item {
    var condition: [String] = []
    if case .text(let grade) = object.values[.condition] { condition.append(grade) }
    if let type = try? catalogue.resolve(object.typeID, subtype: object.subtype) {
      for axis in type.signatures.flatMap(\.axes) {
        guard case .text(let grade) = object.values[.axis(axis)] else { continue }
        condition.append("\(type.field(axis)?.field.label ?? axis): \(grade)")
      }
    }
    let paid: Money? = if case .money(let money) = object.values[.paid] { money } else { nil }
    return Item(
      id: object.id,
      title: object.title,
      typeID: object.typeID,
      subtype: object.subtype,
      quantity: object.quantity,
      photo: shelf.photos(of: object.id).first?.fileName,
      condition: condition,
      acquired: object.acquiredAt,
      place: object.placeID.flatMap { shelf.placePath(of: $0) },
      paid: paid
    )
  }
}
