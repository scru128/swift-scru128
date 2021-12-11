/// Represents a SCRU128 ID and provides various converters and comparison operators.
public struct Scru128Id: LosslessStringConvertible {
  /// Returns a 16-byte byte array containing the 128-bit unsigned integer representation in the
  /// big-endian (network) byte order.
  public let bytes: [UInt8]

  /// Creates an object from a byte array that represents a 128-bit unsigned integer.
  ///
  /// - Parameter bytes: A 16-byte byte array that represents a 128-bit unsigned integer in the
  ///                    big-endian (network) byte order.
  /// - Precondition: The byte array must be 16-byte length.
  public init(_ bytes: [UInt8]) {
    precondition(bytes.count == 16)
    self.bytes = bytes
  }

  /// Creates an object from field values.
  ///
  /// - Parameters:
  ///   - timestamp: 44-bit millisecond timestamp field value.
  ///   - counter: 28-bit per-timestamp monotonic counter field value.
  ///   - perSecRandom: 24-bit per-second randomness field value.
  ///   - perGenRandom: 32-bit per-generation randomness field value.
  /// - Precondition: Each argument must be within the value range of the field.
  public init(
    _ timestamp: UInt64, _ counter: UInt32, _ perSecRandom: UInt32, _ perGenRandom: UInt32
  ) {
    precondition(timestamp <= 0xFFF_FFFF_FFFF)
    precondition(counter <= maxCounter)
    precondition(perSecRandom <= maxPerSecRandom)
    bytes = [
      UInt8(truncatingIfNeeded: timestamp >> 36),
      UInt8(truncatingIfNeeded: timestamp >> 28),
      UInt8(truncatingIfNeeded: timestamp >> 20),
      UInt8(truncatingIfNeeded: timestamp >> 12),
      UInt8(truncatingIfNeeded: timestamp >> 4),
      UInt8(truncatingIfNeeded: timestamp << 4) | UInt8(truncatingIfNeeded: counter >> 24),
      UInt8(truncatingIfNeeded: counter >> 16),
      UInt8(truncatingIfNeeded: counter >> 8),
      UInt8(truncatingIfNeeded: counter),
      UInt8(truncatingIfNeeded: perSecRandom >> 16),
      UInt8(truncatingIfNeeded: perSecRandom >> 8),
      UInt8(truncatingIfNeeded: perSecRandom),
      UInt8(truncatingIfNeeded: perGenRandom >> 24),
      UInt8(truncatingIfNeeded: perGenRandom >> 16),
      UInt8(truncatingIfNeeded: perGenRandom >> 8),
      UInt8(truncatingIfNeeded: perGenRandom),
    ]
  }

  /// Creates an object from a 26-digit string representation.
  public init?(_ description: String) {
    if description.count != 26
      || description.first! > "7"
      || description.uppercased().contains(
        where: { $0 < "0" || $0 > "V" || ($0 > "9" && $0 < "A") }
      )
    {
      return nil
    }

    var bytes = [UInt8](repeating: 0, count: 16)
    var posS = description.startIndex
    var posE = description.index(posS, offsetBy: 2)
    bytes[0] = UInt8(description[posS..<posE], radix: 32)!

    // process three 40-bit (5-byte / 8-digit) groups
    for i in 0..<3 {
      posS = posE
      posE = description.index(posS, offsetBy: 8)
      var buffer = UInt64(description[posS..<posE], radix: 32)!
      for j in 0..<5 {
        bytes[5 + i * 5 - j] = UInt8(truncatingIfNeeded: buffer)
        buffer >>= 8
      }
    }
    self.bytes = bytes
  }

  /// Returns the 44-bit millisecond timestamp field value.
  public var timestamp: UInt64 { subUInt(0..<6) >> 4 }

  /// Returns the 28-bit per-timestamp monotonic counter field value.
  public var counter: UInt32 { subUInt(5..<9) & maxCounter }

  /// Returns the 24-bit per-second randomness field value.
  public var perSecRandom: UInt32 { subUInt(9..<12) }

  /// Returns the 32-bit per-generation randomness field value.
  public var perGenRandom: UInt32 { subUInt(12..<16) }

  /// Returns the 26-digit canonical string representation.
  public var description: String {
    var cstr = [UInt8](repeating: 0, count: 27)
    cstr[0] = digits[Int(bytes[0] >> 5)]
    cstr[1] = digits[Int(bytes[0] & 31)]

    // process three 40-bit (5-byte / 8-digit) groups
    for i in 0..<3 {
      var buffer: UInt64 = subUInt((1 + i * 5)..<(6 + i * 5))
      for j in 0..<8 {
        cstr[9 + i * 8 - j] = digits[Int(buffer & 31)]
        buffer >>= 5
      }
    }
    assert(cstr.last == 0)
    return String(cString: cstr)
  }

  /// Returns a part of `bytes` as an unsigned integer.
  private func subUInt<T: UnsignedInteger>(_ range: Range<Int>) -> T {
    var buffer: T = 0
    for e in bytes[range] {
      buffer <<= 8
      buffer |= T(e)
    }
    return buffer
  }
}

/// Digit characters used in the base 32 notation.
private let digits = [UInt8]("0123456789ABCDEFGHIJKLMNOPQRSTUV".utf8)

extension Scru128Id: Comparable, Hashable {
  public static func == (lhs: Scru128Id, rhs: Scru128Id) -> Bool {
    return lhs.bytes == rhs.bytes
  }

  public static func < (lhs: Scru128Id, rhs: Scru128Id) -> Bool {
    for i in 0..<lhs.bytes.count {
      if lhs.bytes[i] != rhs.bytes[i] {
        return lhs.bytes[i] < rhs.bytes[i]
      }
    }
    return false
  }
}

extension Scru128Id: Codable {
  /// Encodes the object as a 26-digit canonical string representation.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  /// Decodes the object from a 26-digit canonical string representation.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(try container.decode(String.self))!
  }
}
