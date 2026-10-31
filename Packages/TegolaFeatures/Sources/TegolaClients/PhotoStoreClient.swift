public import Dependencies
import DependenciesMacros
public import Foundation
import Synchronization

/// The photos' files, outside the database (PLAN §3.2): the database records a photo, this keeps its image. A file
/// is written before the command that records it, so a refused command leaves an unused file, never a missing one.
@DependencyClient
public struct PhotoStoreClient: Sendable {
  /// Saves an image and returns its file name.
  public var save: @Sendable (_ data: Data) throws -> String
  /// The image a file name holds, if it's there.
  public var load: @Sendable (_ fileName: String) -> Data? = { _ in nil }
}

extension PhotoStoreClient: DependencyKey {
  /// Files in Application Support/Photos, named by a new id.
  public static var liveValue: PhotoStoreClient {
    @Dependency(\.uuid) var uuid
    let folder = URL.applicationSupportDirectory.appending(path: "Photos", directoryHint: .isDirectory)
    return PhotoStoreClient(
      save: { data in
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(uuid().uuidString.lowercased()).jpg"
        try data.write(to: folder.appending(path: name), options: [.atomic, .completeFileProtection])
        return name
      },
      load: { name in try? Data(contentsOf: folder.appending(path: name)) }
    )
  }

  public static let testValue = PhotoStoreClient()

  /// Files kept in memory, for previews and tests.
  public static func inMemory() -> PhotoStoreClient {
    let files = Mutex<[String: Data]>([:])
    return PhotoStoreClient(
      save: { data in
        files.withLock { files in
          let name = "photo-\(files.count + 1).jpg"
          files[name] = data
          return name
        }
      },
      load: { name in files.withLock { $0[name] } }
    )
  }
}

extension DependencyValues {
  public var photoStore: PhotoStoreClient {
    get { self[PhotoStoreClient.self] }
    set { self[PhotoStoreClient.self] = newValue }
  }
}
