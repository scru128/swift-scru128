import Foundation

/// Represents a SCRU128 ID generator and provides an interface to do more than just generate a
/// string representation.
public class Scru128Generator {
  /// Timestamp at last generation.
  private var tsLastGen: UInt64 = 0

  /// Counter at last generation.
  private var counter: UInt32 = 0

  /// Timestamp at last renewal of perSecRandom.
  private var tsLastSec: UInt64 = 0

  /// Per-second random value at last generation.
  private var perSecRandom: UInt32 = 0

  /// Maximum number of checking `Date()` until clock goes forward.
  private let nClockCheckMax = 1_000_000

  private let lock: NSLocking = NSLock()
  private var rng: RandomNumberGenerator

  /// Creates a generator object with the default random number generator.
  public convenience init() {
    self.init(rng: SystemRandomNumberGenerator())
  }

  /// Creates a generator object with a specified random number generator.
  ///
  /// The specified random number generator should be cryptographically strong and securely seeded.
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
    var tsNow = UInt64(Date().timeIntervalSince1970 * 1_000)

    // update timestamp and counter
    if tsNow > tsLastGen {
      tsLastGen = tsNow
      counter = rng.next() & maxCounter
    } else {
      counter += 1
      if counter > maxCounter {
        let logger: MinimumLogging? = getLogger()
        logger?.info("counter limit reached; will wait until clock goes forward")
        var nClockCheck = 0
        while tsNow <= tsLastGen {
          tsNow = UInt64(Date().timeIntervalSince1970 * 1_000)
          nClockCheck += 1
          if nClockCheck > nClockCheckMax {
            logger?.warning("reset state as clock did not go forward")
            tsLastSec = 0
            break
          }
        }

        tsLastGen = tsNow
        counter = rng.next() & maxCounter
      }
    }

    // update perSecRandom
    if tsLastGen - tsLastSec > 1_000 {
      tsLastSec = tsLastGen
      perSecRandom = rng.next() & maxPerSecRandom
    }

    return Scru128Id(tsNow - timestampBias, counter, perSecRandom, rng.next())
  }
}

/// Unix time in milliseconds at 2020-01-01 00:00:00+00:00.
private let timestampBias: UInt64 = 1_577_836_800_000

/// Minimum logger interface
private protocol MinimumLogging {
  func info(_ message: String)
  func warning(_ message: String)
}

// Ad-hoc logger wrapper
#if canImport(os)
  import os

  @available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
  private struct LoggerWrapper: MinimumLogging {
    let logger = Logger(subsystem: "io.github.scru128", category: "Scru128Generator")
    func info(_ message: String) { logger.info("\(message)") }
    func warning(_ message: String) { logger.warning("\(message)") }
  }

  private func getLogger() -> MinimumLogging? {
    if #available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *) {
      return LoggerWrapper()
    } else {
      return nil
    }
  }
#else
  private func getLogger() -> MinimumLogging? { nil }
#endif
