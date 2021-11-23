let maxCounter: UInt32 = 0xFFF_FFFF
let maxPerSecRandom: UInt32 = 0xFF_FFFF

private let defaultGenerator = Scru128Generator()

/// Generates a new SCRU128 ID encoded in a string.
///
/// Use this function to quickly get a new SCRU128 ID as a string. Use ``Scru128Generator`` to do
/// more.
public func scru128() -> String {
  return defaultGenerator.generate().description
}
