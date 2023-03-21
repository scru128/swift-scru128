import Foundation

/// The default timestamp rollback allowance.
let defaultRollbackAllowance: UInt64 = 10_000  // 10 seconds

/// Represents a SCRU128 ID generator that encapsulates the monotonic counters and other internal
/// states.
///
/// The generator offers four different methods to generate a SCRU128 ID:
///
/// | Flavor                                                | Timestamp | Thread- | On big clock rewind |
/// | ----------------------------------------------------- | --------- | ------- | ------------------- |
/// | ``generate()``                                        | Now       | Safe    | Resets generator    |
/// | ``generateOrAbort()``                                 | Now       | Safe    | Returns `nil`       |
/// | ``generateOrResetCore(timestamp:rollbackAllowance:)`` | Argument  | Unsafe  | Resets generator    |
/// | ``generateOrAbortCore(timestamp:rollbackAllowance:)`` | Argument  | Unsafe  | Returns `nil`       |
///
/// All of these methods return monotonically increasing IDs unless a `timestamp` provided is
/// significantly (by default, ten seconds or more) smaller than the one embedded in the immediately
/// preceding ID. If such a significant clock rollback is detected, the `generate` (OrReset) method
/// resets the generator and returns a new ID based on the given `timestamp`, while the `OrAbort`
/// variants abort and return `nil`. The `Core` functions offer low-level thread-unsafe primitives.
public class Scru128Generator {
  private var timestamp: UInt64 = 0
  private var counterHi: UInt32 = 0
  private var counterLo: UInt32 = 0

  /// The timestamp at the last renewal of `counter_hi` field.
  private var tsCounterHi: UInt64 = 0

  /// The ``Status`` code that indicates the internal state involved in the last generation of ID.
  ///
  /// Note that the generator object should be protected from concurrent accesses during the
  /// sequential calls to a generation method and this property to avoid race conditions.
  @available(*, deprecated, message: "Use `generateOrAbort()` to guarantee monotonicity.")
  public var lastStatus: Status { lastStatusInternal }

  /// For internal use to supress deprecation warnings
  internal var lastStatusInternal: Status = Status.notExecuted

  /// The random number generator used by the generator.
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

  /// Generates a new SCRU128 ID object from the current `timestamp`, or resets the generator upon
  /// significant timestamp rollback.
  ///
  /// See the ``Scru128Generator`` class documentation for the description.
  public func generate() -> Scru128Id {
    lock.lock()
    defer { lock.unlock() }
    return generateOrResetCore(
      timestamp: UInt64(Date().timeIntervalSince1970 * 1_000),
      rollbackAllowance: defaultRollbackAllowance)

  }

  /// Generates a new SCRU128 ID object from the current `timestamp`, or returns `nil` upon
  /// significant timestamp rollback.
  ///
  /// See the ``Scru128Generator`` class documentation for the description.
  public func generateOrAbort() -> Scru128Id? {
    lock.lock()
    defer { lock.unlock() }
    return generateOrAbortCore(
      timestamp: UInt64(Date().timeIntervalSince1970 * 1_000),
      rollbackAllowance: defaultRollbackAllowance)
  }

  /// Generates a new SCRU128 ID object from the `timestamp` passed, or resets the generator upon
  /// significant timestamp rollback.
  ///
  /// See the ``Scru128Generator`` class documentation for the description.
  ///
  /// The `rollbackAllowance` parameter specifies the amount of `timestamp` rollback that is
  /// considered significant. A suggested value is `10_000` (milliseconds).
  ///
  /// Unlike ``generate()``, this method is NOT thread-safe. The generator object should be
  /// protected from concurrent accesses using a mutex or other synchronization mechanism to avoid
  /// race conditions.
  ///
  /// - Precondition: `timestamp` must be a 48-bit positive integer.
  public func generateOrResetCore(timestamp: UInt64, rollbackAllowance: UInt64) -> Scru128Id {
    if let value = generateOrAbortCore(timestamp: timestamp, rollbackAllowance: rollbackAllowance) {
      return value
    } else {
      // reset state and resume
      self.timestamp = 0
      tsCounterHi = 0
      let value = generateOrAbortCore(timestamp: timestamp, rollbackAllowance: rollbackAllowance)!
      lastStatusInternal = Status.clockRollback
      return value
    }
  }

  /// A deprecated synonym for `generateOrResetCore(timestamp: timestamp, rollbackAllowance: 10_000)`.
  @available(
    *, deprecated,
    message: "Use `generateOrResetCore(timestamp: timestamp, rollbackAllowance: 10_000)` instead."
  )
  public func generateCore(_ timestamp: UInt64) -> Scru128Id {
    return generateOrResetCore(timestamp: timestamp, rollbackAllowance: defaultRollbackAllowance)
  }

  /// Generates a new SCRU128 ID object from the `timestamp` passed, or returns `nil` upon
  /// significant timestamp rollback.
  ///
  /// See the ``Scru128Generator`` class documentation for the description.
  ///
  /// The `rollbackAllowance` parameter specifies the amount of `timestamp` rollback that is
  /// considered significant. A suggested value is `10_000` (milliseconds).
  ///
  /// Unlike ``generateOrAbort()``, this method is NOT thread-safe. The generator object should be
  /// protected from concurrent accesses using a mutex or other synchronization mechanism to avoid
  /// race conditions.
  ///
  /// - Precondition: `timestamp` must be a 48-bit positive integer.
  public func generateOrAbortCore(timestamp: UInt64, rollbackAllowance: UInt64) -> Scru128Id? {
    precondition(timestamp != 0 && timestamp <= maxTimestamp)
    precondition(rollbackAllowance <= maxTimestamp)

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

  /// _Deprecated_: The status code returned by ``lastStatus`` property.
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
