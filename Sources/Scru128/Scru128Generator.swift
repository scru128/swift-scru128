import Foundation

/// Represents a SCRU128 ID generator that encapsulates the monotonic counters and other internal
/// states.
public class Scru128Generator {
  private var timestamp: UInt64 = 0
  private var counterHi: UInt32 = 0
  private var counterLo: UInt32 = 0

  /// Timestamp at the last renewal of `counter_hi` field.
  private var tsCounterHi: UInt64 = 0

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

  /// Generates a new SCRU128 ID object.
  ///
  /// This method is thread-safe; multiple threads can call it concurrently.
  public func generate() -> Scru128Id {
    lock.lock()
    defer { lock.unlock() }
    return generateCore(UInt64(Date().timeIntervalSince1970 * 1_000)).0
  }

  /// Generates a new SCRU128 ID object with the `timestamp` passed.
  ///
  /// Unlike ``generate()``, this method is NOT thread-safe. The generator object should be
  /// protected from concurrent accesses using a mutex or other synchronization mechanism to avoid
  /// race conditions.
  ///
  /// This method returns a generated ID and a ``Status`` code that indicates the internal state
  /// involved in the generation. Callers can usually ignore the status unless the monotonic order
  /// of generated IDs is critically important.
  public func generateCore(_ timestamp: UInt64) -> (Scru128Id, Status) {
    precondition(timestamp <= maxTimestamp)

    var status = Status.newTimestamp
    if timestamp > self.timestamp {
      self.timestamp = timestamp
      counterLo = rng.next() & maxCounterLo
    } else if timestamp + 10_000 > self.timestamp {
      counterLo += 1
      status = Status.counterLoInc
      if counterLo > maxCounterLo {
        counterLo = 0
        counterHi += 1
        status = Status.counterHiInc
        if counterHi > maxCounterHi {
          counterHi = 0
          // increment timestamp at counter overflow
          self.timestamp += 1
          counterLo = rng.next() & maxCounterLo
          status = Status.timestampInc
        }
      }
    } else {
      // reset state if clock moves back by ten seconds or more
      tsCounterHi = 0
      self.timestamp = timestamp
      counterLo = rng.next() & maxCounterLo
      status = Status.clockRollback
    }

    if self.timestamp - tsCounterHi >= 1_000 {
      tsCounterHi = self.timestamp
      counterHi = rng.next() & maxCounterHi
    }

    return (Scru128Id(self.timestamp, counterHi, counterLo, rng.next()), status)
  }

  /// Status code reported by ``generateCore(_:)`` method.
  public enum Status {
    /// Indicates that the `timestamp` passed was used because it was greater than the previous
    /// one.
    case newTimestamp

    /// Indicates that `counter_lo` was incremented because the `timestamp` passed was no greater
    /// than the previous one.
    case counterLoInc

    /// Indicates that `counter_hi` was incremented because `counter_lo` reached its maximum value.
    case counterHiInc

    /// Indicates that the previous `timestamp` was incremented because `counter_hi` reached its
    /// maximum value.
    case timestampInc

    /// Indicates that the monotonic order of generated IDs was broken because the `timestamp`
    /// passed was less than the previous one by ten seconds or more.
    case clockRollback
  }
}
