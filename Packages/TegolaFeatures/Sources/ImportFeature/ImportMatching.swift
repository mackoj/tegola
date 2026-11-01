public import ComposableArchitecture
import Foundation
public import TegolaClients
public import TegolaInterchange
public import TegolaModel

extension ImportFeature {
  /// Step 4 (49): the rows go to the server 50 at a time, by type. A match or a question is kept on its object as an
  /// answered lookup, for the review queue; a row nobody knows stays as written (49 Q2). Offline or refused, the rows
  /// stay as written too: matching never holds the import up.
  public static func match(_ rows: [ImportPlan.Row], objects: [ObjectID]) async throws -> Int {
    @Dependency(\.lookup) var lookup
    @Dependency(\.lookupQueue) var lookupQueue
    @Dependency(\.date.now) var now
    do {
      let pairs = Array(zip(rows, objects))
      var answered = 0
      for (type, group) in Dictionary(grouping: pairs, by: { $0.0.draft.type }) {
        for start in stride(from: 0, to: group.count, by: 50) {
          let chunk = Array(group[start..<min(start + 50, group.count)])
          let requests = chunk.compactMap { row, id -> MatchRow? in
            guard case .text(let title) = row.draft.values[.title] else { return nil }
            let subtitle: String? = if case .text(let text) = row.draft.values[.subtitle] { text } else { nil }
            let year: Int? = if case .year(let year) = row.draft.values[.year] { year } else { nil }
            return MatchRow(
              ref: id.rawValue.uuidString,
              title: title,
              subtitle: subtitle,
              year: year,
              subtype: row.draft.subtype
            )
          }
          guard let outcomes = try? await lookup.match(type, requests) else { continue }
          for (_, id) in chunk {
            switch outcomes[id.rawValue.uuidString] {
            case .matched(let candidate):
              try lookupQueue.answer(id, [candidate], now)
              answered += 1
            case .ambiguous(let candidates):
              try lookupQueue.answer(id, candidates, now)
              answered += 1
            case .unknown, nil:
              continue
            }
          }
        }
      }
      return answered
    }
  }
}
