public import Foundation
import Synchronization

/// Ids from a counter, so a plan is the same on every run.
public final class Counter: Sendable {
  public init() {}

  private let value = Mutex(0)

  public func next() -> UUID {
    let n = value.withLock { value in
      value += 1
      return value
    }
    return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
  }
}
