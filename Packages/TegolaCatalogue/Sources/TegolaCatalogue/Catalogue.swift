import Foundation
import Yams

/// The type files bundled with the app, decoded and validated.
public struct Catalogue: Sendable {
  public let manifests: [TypeManifest]
  /// The fields every type inherits (page 48).
  public let item: ItemLevel

  /// The types a collector can choose in v1 (PLAN §3.3, D-23). Every other file ships as data for the release train
  /// (PD-111): enabling one is adding its id here.
  public static let enabledInV1: [TypeManifest.ID] = ["music", "video-game", "board-games", "thing"]

  public init(manifests: [TypeManifest], item: ItemLevel = .none) {
    self.manifests = manifests
    self.item = item
  }

  /// The one function every screen and the import read a type through (PLAN §3.3): the type, its subtype's presets
  /// and additions, and the item level.
  public func resolve(_ type: TypeManifest.ID, subtype: String?) throws(ResolveError) -> EffectiveType {
    guard let manifest = manifest(type) else { throw .unknownType(type) }
    return try manifest.resolve(subtype: subtype, item: item)
  }

  public func manifest(_ id: TypeManifest.ID) -> TypeManifest? {
    manifests.first { $0.id == id }
  }

  public var enabled: [TypeManifest] {
    Self.enabledInV1.compactMap { manifest($0) }
  }

  /// Decodes every `.yml` file in the bundle's `Types` folder, sorted by id.
  public static func bundled() throws -> Catalogue {
    guard let folder = Bundle.module.url(forResource: "Types", withExtension: nil) else {
      throw CatalogueError.missingTypesFolder
    }
    let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "yml" }
    let manifests = try files.map { file in
      let manifest = try decode(Data(contentsOf: file), file: file.lastPathComponent)
      // The file name is how a type is found on disk and in reviews; it must say which type it holds.
      guard manifest.id.rawValue + ".yml" == file.lastPathComponent else {
        throw CatalogueError.fileNameMismatch(file: file.lastPathComponent, id: manifest.id.rawValue)
      }
      return manifest
    }
    guard let itemFile = Bundle.module.url(forResource: "item", withExtension: "yml", subdirectory: "Item") else {
      throw CatalogueError.missingTypesFolder
    }
    let item: ItemLevel
    do {
      item = try YAMLDecoder().decode(ItemLevel.self, from: Data(contentsOf: itemFile))
    } catch {
      throw CatalogueError.undecodable(file: "item.yml", reason: String(describing: error))
    }
    return Catalogue(manifests: manifests.sorted { $0.id.rawValue < $1.id.rawValue }, item: item)
  }

  static func decode(_ data: Data, file: String) throws -> TypeManifest {
    do {
      return try YAMLDecoder().decode(TypeManifest.self, from: data)
    } catch {
      throw CatalogueError.undecodable(file: file, reason: String(describing: error))
    }
  }
}

public enum CatalogueError: Error, Equatable, Sendable {
  case missingTypesFolder
  case undecodable(file: String, reason: String)
  case fileNameMismatch(file: String, id: String)
}
