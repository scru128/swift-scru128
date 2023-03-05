import Foundation

/// Represents a SCRU128 ID generator that encapsulates the monotonic counters and other internal
/// states.
public class Scru128Generator {
  private var timestamp: UInt64 = 0
  private var counterHi: UInt32 = 0
  private var counterLo: UInt32 = 0

  /// Timestamp at the last renewal of `counter_hi` field.
  private var tsCounterHi: UInt64 = 0

  /// ``Status`` code that indicates the internal state involved in the last generation of ID.
  ///
  /// Note that the generator object should be protected from concurrent accesses during the
  /// sequential calls to a generation method and this property to avoid race conditions.
  @available(*, deprecated, message: "Use `generateNoRewind()` to guarantee monotonicity.")
  public var lastStatus: Status { lastStatusInternal }

  /// For internal use to supress deprecation warnings
  internal var lastStatusInternal: Status = Status.notExecuted

  /// Random number generator used by the generator.
  private var rng: RandomNumberGenerator

  private let lock: NSLocking = NSLock()

  /// Creates a generator object with the default random number generator.
  public convenience init() {
    self.init(rng: SystemRandomNumberGenerator())
  }

  /// Creates a generator object with a specified random number generator. The specified random
  /// number generator should be cryptographically strong and securely seeded.
  public init(rng: RandomNumberGenerator) {
    self.rng = rng
  }

  /// Generates a new SCRU128 ID object from the current `timestamp`.
  ///
  /// This method returns monotonically increasing IDs unless the up-to-date `timestamp` is
  /// significantly (by ten seconds or more) smaller than the one embedded in the immediately
  /// preceding ID. If such a significant clock rollback is detected, this method rewinds the
  /// generator state and returns a new ID based on the up-to-date `timestamp`.
  ///
  /// This method is thread-safe; multiple threads can call it concurrently.
  public func generate() -> Scru128Id {
    lock.lock()
    defer { lock.unlock() }
    return generateCore(UInt64(Date().timeIntervalSince1970 * 1_000))
  }

  /// Generates a new SCRU128 ID object from the current `timestamp`, guaranteeing the monotonic
  /// order of generated IDs despite a significant timestamp rollback.
  ///
  /// This method returns monotonically increasing IDs unless the up-to-date `timestamp` is
  /// significantly (by ten seconds or more) smaller than the one embedded in the immediately
  /// preceding ID. If such a significant clock rollback is detected, this method returns `nil` and
  /// keeps the generator state untouched.
  ///
  /// This method is thread-safe; multiple threads can call it concurrently.
  public func generateNoRewind() -> Scru128Id? {
    lock.lock()
    defer { lock.unlock() }
    return generateCoreNoRewind(UInt64(Date().timeIntervalSince1970 * 1_000))
  }

  /// Generates a new SCRU128 ID object from the `timestamp` passed.
  ///
  /// This method returns monotonically increasing IDs unless a given `timestamp` is significantly
  /// (by ten seconds or more) smaller than the one embedded in the immediately preceding ID. If
  /// such a significant clock rollback is detected, this method rewinds the generator state and
  /// returns a new ID based on the given argument.
  ///
  /// Unlike ``generate()``, this method is NOT thread-safe. The generator object should be
  /// protected from concurrent accesses using a mutex or other synchronization mechanism to avoid
  /// race conditions.
  ///
  /// - Precondition: The argument must be a 48-bit positive integer.
  public func generateCore(_ timestamp: UInt64) -> Scru128Id {
    if let value = generateCoreNoRewind(timestamp) {
      return value
    } else {
      // reset state and resume
      self.timestamp = 0
      tsCounterHi = 0
      let value = generateCoreNoRewind(timestamp)!
      lastStatusInternal = Status.clockRollback
      return value
    }
  }

  /// Generates a new SCRU128 ID object from the `timestamp` passed, guaranteeing the monotonic
  /// order of generated IDs despite a significant timestamp rollback.
  ///
  /// This method returns monotonically increasing IDs unless a given `timestamp` is significantly
  /// (by ten seconds or more) smaller than the one embedded in the immediately preceding ID. If
  /// such a significant clock rollback is detected, this method returns `nil` and keeps the
  /// generator state untouched.
  ///
  /// Unlike ``generateNoRewind()``, this method is NOT thread-safe. The generator object should be
  /// protected from concurrent accesses using a mutex or other synchronization mechanism to avoid
  /// race conditions.
  ///
  /// - Precondition: The argument must be a 48-bit positive integer.
  public func generateCoreNoRewind(_ timestamp: UInt64) -> Scru128Id? {
    let rollbackAllowance: UInt64 = 10_000  // 10 seconds

    precondition(timestamp != 0 && timestamp <= maxTimestamp)

    if timestamp > self.timestamp {
      self.timestamp = timestamp
      counterLo = rng.next() & maxCounterLo
      lastStatusInternal = Status.newTimestamp
    } else if timestamp + rollbackAllowance > self.timestamp {
      // go on with previous timestamp if new one is not much smaller
      counterLo += 1
      lastStatusInternal = Status.counterLoInc
      if counterLo > maxCounterLo {
        counterLo = 0
        counterHi += 1
        lastStatusInternal = Status.counterHiInc
        if counterHi > maxCounterHi {
          counterHi = 0
          // increment timestamp at counter overflow
          self.timestamp += 1
          counterLo = rng.next() & maxCounterLo
          lastStatusInternal = Status.timestampInc
        }
      }
    } else {
      // abort if clock moves back to unbearable extent
      return nil
    }

    if self.timestamp - tsCounterHi >= 1_000 || tsCounterHi == 0 {
      tsCounterHi = self.timestamp
      counterHi = rng.next() & maxCounterHi
    }

    return Scru128Id(self.timestamp, counterHi, counterLo, rng.next())
  }

  /// _Deprecated_. Status code returned by ``lastStatus`` property.
  public enum Status {
    /// Indicates that the generator has yet to generate an ID.
    case notExecuted

    /// Indicates that the latest `timestamp` was used because it was greater than the previous one.
    case newTimestamp

    /// Indicates that `counter_lo` was incremented because the latest `timestamp` was no greater
    /// than the previous one.
    case counterLoInc

    /// Indicates that `counter_hi` was incremented because `counter_lo` reached its maximum value.
    case counterHiInc

    /// Indicates that the previous `timestamp` was incremented because `counter_hi` reached its
    /// maximum value.
    case timestampInc

    /// Indicates that the monotonic order of generated IDs was broken because the latest
    /// `timestamp` was less than the previous one by ten seconds or more.
    case clockRollback
  }
}

extension Scru128Generator: IteratorProtocol, Sequence {
  /// Returns a new SCRU128 ID object for each call, infinitely.
  ///
  /// This method is a synonym for ``generate()`` to use `self` as an infinite iterator that
  /// produces a new ID for each call of `next()`.
  public func next() -> Scru128Id? {
    return generate()
  }
}
