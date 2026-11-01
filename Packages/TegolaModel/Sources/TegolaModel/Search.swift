import Foundation
public import TegolaCatalogue

/// What Find asks for (F11): words, and filters that stack as chips. Everything runs on the phone, offline, and
/// nothing searched leaves it.
public struct SearchQuery: Hashable, Sendable {
  public var text: String
  public var types: Set<TypeManifest.ID>
  /// Only objects lent out right now.
  public var lentOut: Bool
  public var place: PlaceID?
  /// Include let-go objects (the archive), so "did I ever own this?" has an answer.
  public var includeArchive: Bool
  public var view: SavedView?

  public init(
    text: String = "",
    types: Set<TypeManifest.ID> = [],
    lentOut: Bool = false,
    place: PlaceID? = nil,
    includeArchive: Bool = false,
    view: SavedView? = nil
  ) {
    self.text = text
    self.types = types
    self.lentOut = lentOut
    self.place = place
    self.includeArchive = includeArchive
    self.view = view
  }

  /// Nothing asked yet: Find shows its saved views instead of every object.
  public var isEmpty: Bool {
    text.trimmingCharacters(in: .whitespaces).isEmpty && types.isEmpty && !lentOut && place == nil && view == nil
      && !includeArchive
  }
}

/// A live query with a name (F11, PLAN §4.1): never a copy, always today's answer.
public enum SavedView: String, CaseIterable, Hashable, Sendable {
  /// Any ladder part at Missing or at the bottom two steps of the type's scale ("worn").
  case imperfect
  /// Two or more owned copies of the same title, type and subtype.
  case duplicates
  /// Signed, from the item level.
  case signed
  case mightLetGo
}

/// One result, and the fields that matched, so the row can say why it's there.
public struct SearchHit: Hashable, Sendable, Identifiable {
  public let object: ObjectID
  /// What the words matched, as the collector knows them: the type's labels, the place, "notes".
  public let matched: [String]

  public var id: ObjectID { object }
}

/// Finds objects for a query. Every word must appear somewhere on the object (case and accents ignored): the spine,
/// a field, an entry of a list or log (one track on an LP), the notes, the place. Results are the most recently
/// changed first.
public func search(_ query: SearchQuery, in shelf: Shelf, catalogue: Catalogue) -> [SearchHit] {
  let words = query.text.split(whereSeparator: \.isWhitespace).map { normalize(String($0)) }.filter { !$0.isEmpty }
  let lent = Set(shelf.loans.values.filter { $0.isOpen && $0.direction == .out }.map(\.objectID))
  let places = query.place.map { shelf.placeAndInside($0) }
  let duplicates = query.view == .duplicates ? shelf.duplicateObjects() : []
  var hits: [(ShelfObject, [String])] = []
  for object in shelf.objects.values {
    if object.letGo != nil && !query.includeArchive { continue }
    if !query.types.isEmpty && !query.types.contains(object.typeID) { continue }
    if query.lentOut && !lent.contains(object.id) { continue }
    if let places, !(object.placeID.map(places.contains) ?? false) { continue }
    if let view = query.view {
      let type = try? catalogue.resolve(object.typeID, subtype: object.subtype)
      guard object.matches(view, type: type, duplicates: duplicates) else { continue }
    }
    if words.isEmpty {
      hits.append((object, []))
      continue
    }
    let texts = object.searchableTexts(shelf: shelf, catalogue: catalogue)
    var matched: [String] = []
    var all = true
    for word in words {
      let found = texts.filter { $0.text.contains(word) }.map(\.label)
      if found.isEmpty {
        all = false
        break
      }
      matched += found
    }
    if all { hits.append((object, matched.uniqued())) }
  }
  return hits.sorted { ($0.0.updatedAt, $0.0.id) > ($1.0.updatedAt, $1.0.id) }
    .map { SearchHit(object: $0.0.id, matched: $0.1) }
}

/// Lowercased, accents and width folded: "Björk" finds "bjork".
func normalize(_ text: String) -> String {
  text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
}

extension ShelfObject {
  /// Every piece of text on the object, each with the label a collector knows it by.
  func searchableTexts(shelf: Shelf, catalogue: Catalogue) -> [(label: String, text: String)] {
    let type = try? catalogue.resolve(typeID, subtype: subtype)
    let manifest = catalogue.manifest(typeID)
    var texts: [(String, String)] = []
    for (key, value) in values {
      let label: String =
        switch key {
        case .title: manifest?.spine.title ?? "title"
        case .subtitle: manifest?.spine.subtitle ?? "subtitle"
        case .year: manifest?.spine.year ?? "year"
        case .notes: "notes"
        case .field(let name), .axis(let name): type?.field(name)?.field.label ?? name
        default: key.description
        }
      for text in value.searchTexts { texts.append((label, normalize(text))) }
    }
    if let placeID, let path = shelf.placePath(of: placeID) {
      texts.append((manifest?.placeLabel ?? "place", normalize(path)))
    }
    if let label = subtype.flatMap({ key in manifest?.subtypes.first { $0.key == key }?.label }) {
      texts.append((manifest?.spine.subtitle ?? "subtype", normalize(label)))
    }
    return texts
  }

  func matches(_ view: SavedView, type: EffectiveType?, duplicates: Set<ObjectID>) -> Bool {
    switch view {
    case .imperfect:
      guard let type else { return false }
      let worn = Set(type.conditions.suffix(2)).union(["Missing"])
      return values.contains { key, value in
        if case .axis = key, case .text(let grade) = value { worn.contains(grade) } else { false }
      }
    case .duplicates:
      return duplicates.contains(id)
    case .signed:
      return isSigned
    case .mightLetGo:
      return mightLetGo && counts
    }
  }
}

extension ShelfObject {
  /// Signed by someone: an item-level signature with a name in it.
  public var isSigned: Bool {
    guard case .entries(let signatures) = values[.field("signed")] else { return false }
    return signatures.contains { !($0["by"] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
  }
}

extension FieldValue {
  var searchTexts: [String] {
    switch self {
    case .text(let text): [text]
    case .number(let number): [String(number)]
    case .year(let year): [String(year)]
    case .yearRange(let from, let to): [String(from), String(to)]
    case .options(let options): options
    case .entries(let entries): entries.flatMap { $0.values }
    case .flag, .date, .money, .photo: []
    }
  }
}

extension Shelf {
  /// A place and every place inside it.
  public func placeAndInside(_ id: PlaceID) -> Set<PlaceID> {
    var found: Set<PlaceID> = [id]
    var frontier = [id]
    while let next = frontier.popLast() {
      for place in places.values where place.parentID == next && !found.contains(place.id) {
        found.insert(place.id)
        frontier.append(place.id)
      }
    }
    return found
  }

  /// Owned, kept objects that share a type, subtype and title with another one. A signed object is one of a kind,
  /// never a duplicate (48, item.yml).
  func duplicateObjects() -> Set<ObjectID> {
    let groups = Dictionary(grouping: objects.values.filter { $0.counts && !$0.isSigned }) { object in
      "\(object.typeID.rawValue)|\(object.subtype ?? "")|\(normalize(object.title))"
    }
    return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.id) })
  }
}

extension Array where Element: Hashable {
  func uniqued() -> [Element] {
    var seen: Set<Element> = []
    return filter { seen.insert($0).inserted }
  }
}
