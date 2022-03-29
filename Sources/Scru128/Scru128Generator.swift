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

  /// Logger object used by the generator.
  private var logger: Scru128Logging?

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
    while true {
      do {
        return try generateCore()
      } catch is CounterOverflowError {
        handleCounterOverflow()
      } catch {
        fatalError("unexpected error")
      }
    }
  }

  /// Generates a new SCRU128 ID object, while delegating the caller to take care of thread safety
  /// and counter overflows.
  private func generateCore() throws -> Scru128Id {
    let ts = UInt64(Date().timeIntervalSince1970 * 1_000)
    if ts > timestamp {
      timestamp = ts
      counterLo = rng.next() & maxCounterLo
      if ts - tsCounterHi >= 1000 {
        tsCounterHi = ts
        counterHi = rng.next() & maxCounterHi
      }
    } else {
      counterLo += 1
      if counterLo > maxCounterLo {
        counterLo = 0
        counterHi += 1
        if counterHi > maxCounterHi {
          counterHi = 0
          throw CounterOverflowError()
        }
      }
    }

    return Scru128Id(timestamp, counterHi, counterLo, rng.next())
  }

  /// Defines the behavior on counter overflow.
  ///
  /// Currently, this method waits for the next clock tick and, if the clock does not move forward
  /// for a while, reinitializes the generator state.
  private func handleCounterOverflow() {
    logger?.notice("counter overflowing; will wait for next clock tick")
    tsCounterHi = 0
    for _ in 0..<10_000 {
      Thread.sleep(forTimeInterval: 0.0001)  // 100 microseconds
      if UInt64(Date().timeIntervalSince1970 * 1_000) > timestamp {
        return
      }
    }
    logger?.notice("reset state as clock did not move for a while")
    timestamp = 0
  }

  /// Specifies the logger object used by the generator.
  ///
  /// Logging is disabled by default. Set a logger object to enable logging.
  public func setLogger(_ newLogger: Scru128Logging) {
    logger = newLogger
  }
}

/// Defines the logger interface used by the generator.
public protocol Scru128Logging {
  /// Logs message at default level.
  func notice(_ message: String)
}

/// Error thrown when the monotonic counters can no more be incremented.
private struct CounterOverflowError: Error {}
