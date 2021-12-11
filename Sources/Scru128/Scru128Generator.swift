import Foundation

/// Represents a SCRU128 ID generator that encapsulates the monotonic counter and other internal
/// states.
public class Scru128Generator {
  /// Timestamp at last generation.
  private var tsLastGen: UInt64 = 0

  /// Counter at last generation.
  private var counter: UInt32 = 0

  /// Timestamp at last renewal of perSecRandom.
  private var tsLastSec: UInt64 = 0

  /// Per-second random value at last generation.
  private var perSecRandom: UInt32 = 0

  /// Maximum number of checking the system clock until it goes forward.
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
    // update timestamp and counter
    var tsNow = UInt64(Date().timeIntervalSince1970 * 1_000)
    if tsNow > tsLastGen {
      tsLastGen = tsNow
      counter = rng.next() & maxCounter
    } else {
      counter += 1
      if counter > maxCounter {
        logger?.info("counter limit reached; will wait until clock goes forward")
        var nClockCheck = 0
        while tsNow <= tsLastGen {
          tsNow = UInt64(Date().timeIntervalSince1970 * 1_000)
          nClockCheck += 1
          if nClockCheck > nClockCheckMax {
            logger?.notice("reset state as clock did not go forward")
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

/// Defines the logger interface used in the package.
public protocol Scru128Logging {
  /// Logs message at error level.
  func error(_ message: String)

  /// Logs message at default level.
  func notice(_ message: String)

  /// Logs message at info level.
  func info(_ message: String)
}

/// Logger object used in the package.
var logger: Scru128Logging? = nil

/// Specifies the logger object used in the package.
///
/// Logging is disabled by default. Set a thread-safe logger to enable logging.
public func setScru128Logger(_ newLogger: Scru128Logging) {
  logger = newLogger
}
