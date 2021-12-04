let maxCounter: UInt32 = 0xFFF_FFFF
let maxPerSecRandom: UInt32 = 0xFF_FFFF

private let defaultGenerator = Scru128Generator()

/// Generates a new SCRU128 ID object.
///
/// This function is thread safe; multiple threads can call it concurrently.
public func scru128() -> Scru128Id { defaultGenerator.generate() }

/// Generates a new SCRU128 ID encoded in the 26-digit canonical string representation.
///
/// This function is thread safe. Use this to quickly get a new SCRU128 ID as a string.
public func scru128String() -> String { scru128().description }
