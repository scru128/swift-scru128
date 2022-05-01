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
  /// This method is thread safe; multiple threads can call it concurrently.
  public func generate() -> Scru128Id {
    lock.lock()
    defer { lock.unlock() }
    return generateThreadUnsafe()
  }

  /// Generates a new SCRU128 ID object without overhead for thread safety.
  private func generateThreadUnsafe() -> Scru128Id {
    let ts = UInt64(Date().timeIntervalSince1970 * 1_000)
    if ts > timestamp {
      timestamp = ts
      counterLo = rng.next() & maxCounterLo
    } else if ts + 10_000 > timestamp {
      counterLo += 1
      if counterLo > maxCounterLo {
        counterLo = 0
        counterHi += 1
        if counterHi > maxCounterHi {
          counterHi = 0
          // increment timestamp at counter overflow
          timestamp += 1
          counterLo = rng.next() & maxCounterLo
        }
      }
    } else {
      // reset state if clock moves back more than ten seconds
      tsCounterHi = 0
      timestamp = ts
      counterLo = rng.next() & maxCounterLo
    }

    if timestamp - tsCounterHi >= 1_000 {
      tsCounterHi = timestamp
      counterHi = rng.next() & maxCounterHi
    }

    return Scru128Id(timestamp, counterHi, counterLo, rng.next())
  }
}
