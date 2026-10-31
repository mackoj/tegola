public import Foundation

/// A typed UUID, so an object's id can't be passed where a loan's is wanted. UUIDs rather than ULIDs: they're what
/// `SyncEngine` is proven with, and events are ordered by `at` then `seq` instead of by id (D-24). The model never
/// makes one; ids come from the caller (the `uuid` dependency in the app, a counter in tests).
public struct Identifier<Tag>: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
  public let rawValue: UUID

  public init(_ rawValue: UUID) {
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(UUID.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public var description: String { rawValue.uuidString.lowercased() }

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue.uuidString < rhs.rawValue.uuidString }
}

public enum ObjectTag {}
public enum CollectionTag {}
public enum WorkTag {}
public enum PlaceTag {}
public enum PersonTag {}
public enum LoanTag {}
public enum PhotoTag {}
public enum EventTag {}
public enum BatchTag {}

public typealias ObjectID = Identifier<ObjectTag>
public typealias CollectionID = Identifier<CollectionTag>
public typealias WorkID = Identifier<WorkTag>
public typealias PlaceID = Identifier<PlaceTag>
public typealias PersonID = Identifier<PersonTag>
public typealias LoanID = Identifier<LoanTag>
public typealias PhotoID = Identifier<PhotoTag>
public typealias EventID = Identifier<EventTag>
public typealias BatchID = Identifier<BatchTag>
