/// Maximum value of 24-bit `counter_hi` field.
let maxCounterHi: UInt32 = 0xff_ffff

/// Maximum value of 24-bit `counter_lo` field.
let maxCounterLo: UInt32 = 0xff_ffff

private let defaultGenerator = Scru128Generator()

/// Generates a new SCRU128 ID object.
///
/// This function is thread safe; multiple threads can call it concurrently.
public func scru128() -> Scru128Id { defaultGenerator.generate() }

/// Generates a new SCRU128 ID encoded in the 25-digit canonical string representation.
///
/// This function is thread safe. Use this to quickly get a new SCRU128 ID as a string.
public func scru128String() -> String { scru128().description }
