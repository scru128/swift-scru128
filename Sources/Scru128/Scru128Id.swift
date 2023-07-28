/// Represents a SCRU128 ID and provides converters and comparison operators.
public struct Scru128Id: LosslessStringConvertible {
  /// Returns a 16-byte byte tuple containing the 128-bit unsigned integer representation in the
  /// big-endian (network) byte order.
  public let bytes:
    (
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

  /// Creates an object from a byte tuple that represents a 128-bit unsigned integer.
  ///
  /// - Parameter bytes: A 16-byte byte array that represents a 128-bit unsigned integer in the
  ///                    big-endian (network) byte order.
  public init(
    _ bytes: (
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )
  ) {
    self.bytes = bytes
  }

  /// Creates an object from a byte array that represents a 128-bit unsigned integer.
  ///
  /// - Parameter byteArray: A 16-byte byte array that represents a 128-bit unsigned integer in the
  ///                        big-endian (network) byte order.
  /// - Precondition: The byte length of the argument must be 16.
  public init(_ byteArray: [UInt8]) {
    precondition(byteArray.count == 16)
    bytes = (
      byteArray[0], byteArray[1], byteArray[2], byteArray[3],
      byteArray[4], byteArray[5], byteArray[6], byteArray[7],
      byteArray[8], byteArray[9], byteArray[10], byteArray[11],
      byteArray[12], byteArray[13], byteArray[14], byteArray[15]
    )
  }

  /// Creates an object from field values.
  ///
  /// - Parameters:
  ///   - timestamp: A 48-bit `timestamp` field value.
  ///   - counterHi: A 24-bit `counter_hi` field value.
  ///   - counterLo: A 24-bit `counter_lo` field value.
  ///   - entropy: A 32-bit `entropy` field value.
  /// - Precondition: Each argument must be within the value range of the field.
  public init(
    _ timestamp: UInt64, _ counterHi: UInt32, _ counterLo: UInt32, _ entropy: UInt32
  ) {
    precondition(timestamp <= maxTimestamp)
    precondition(counterHi <= maxCounterHi)
    precondition(counterLo <= maxCounterLo)
    bytes = (
      UInt8(truncatingIfNeeded: timestamp >> 40),
      UInt8(truncatingIfNeeded: timestamp >> 32),
      UInt8(truncatingIfNeeded: timestamp >> 24),
      UInt8(truncatingIfNeeded: timestamp >> 16),
      UInt8(truncatingIfNeeded: timestamp >> 8),
      UInt8(truncatingIfNeeded: timestamp),
      UInt8(truncatingIfNeeded: counterHi >> 16),
      UInt8(truncatingIfNeeded: counterHi >> 8),
      UInt8(truncatingIfNeeded: counterHi),
      UInt8(truncatingIfNeeded: counterLo >> 16),
      UInt8(truncatingIfNeeded: counterLo >> 8),
      UInt8(truncatingIfNeeded: counterLo),
      UInt8(truncatingIfNeeded: entropy >> 24),
      UInt8(truncatingIfNeeded: entropy >> 16),
      UInt8(truncatingIfNeeded: entropy >> 8),
      UInt8(truncatingIfNeeded: entropy)
    )
  }

  /// Creates an object from a 25-digit string representation.
  public init?(_ description: String) {
    guard let byteArray = Self.parse(description) else {
      return nil
    }
    self.init(byteArray)
  }

  /// Builds the 16-byte big-endian byte array representation from a string.
  private static func parse(_ description: String) -> [UInt8]? {
    var desc = description
    return desc.withUTF8 {
      if $0.count != 25 {
        return nil  // invalid length
      }

      var src = [UInt8](repeating: 0, count: 25)
      for i in 0..<src.count {
        src[i] = decodeMap[Int($0[i])]
        if src[i] == 0xff {
          return nil  // invalid digit
        }
      }

      var dst = [UInt8](repeating: 0, count: 16)
      var minIndex = 99  // any number greater than size of output array
      for i in stride(from: -5, to: 25, by: 10) {
        // implement Base36 using 10-digit words
        var carry: UInt64 = 0
        for e in src[(i < 0 ? 0 : i)..<(i + 10)] {
          carry = (carry * 36) + UInt64(e)
        }

        // iterate over output array from right to left while carry != 0 but at least up to place
        // already filled
        var j = dst.count - 1
        while carry > 0 || j > minIndex {
          if j < 0 {
            return nil  // out of 128-bit value range
          }
          carry += UInt64(dst[j]) * 3_656_158_440_062_976  // 36^10
          dst[j] = UInt8(truncatingIfNeeded: carry)
          carry = carry >> 8
          j -= 1
        }
        minIndex = j
      }
      return dst
    }
  }

  /// Returns a 16-byte byte array containing the 128-bit unsigned integer representation in the
  /// big-endian (network) byte order.
  public var byteArray: [UInt8] {
    [
      bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
      bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
    ]
  }

  /// Returns the 48-bit `timestamp` field value.
  public var timestamp: UInt64 { subUInt(0..<6) }

  /// Returns the 24-bit `counter_hi` field value.
  public var counterHi: UInt32 { subUInt(6..<9) }

  /// Returns the 24-bit `counter_lo` field value.
  public var counterLo: UInt32 { subUInt(9..<12) }

  /// Returns the 32-bit `entropy` field value.
  public var entropy: UInt32 { subUInt(12..<16) }

  /// Returns the 25-digit canonical string representation.
  public var description: String {
    func buildUtf8Bytes(_ dst: UnsafeMutableBufferPointer<UInt8>) -> Int {
      dst.initialize(repeating: 0)
      var minIndex = 99  // any number greater than size of output array
      for i in stride(from: -5, to: 16, by: 7) {
        // implement Base36 using 56-bit words
        var carry: UInt64 = subUInt((i < 0 ? 0 : i)..<(i + 7))

        // iterate over output array from right to left while carry != 0 but at least up to place
        // already filled
        var j = 24
        while carry > 0 || j > minIndex {
          carry += UInt64(dst[j]) << 56
          dst[j] = UInt8(truncatingIfNeeded: carry % 36)
          carry = carry / 36
          j -= 1
        }
        minIndex = j
      }

      for i in 0..<25 {
        dst[i] = digits[Int(dst[i])]
      }
      return dst.count
    }

    if #available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *) {
      return String(unsafeUninitializedCapacity: 25, initializingUTF8With: buildUtf8Bytes)
    } else {
      return String(cString: [UInt8](unsafeUninitializedCapacity: 26) { $1 = buildUtf8Bytes($0) })
    }
  }

  /// Returns a part of `bytes` as an unsigned integer.
  private func subUInt<T: UnsignedInteger>(_ range: Range<Int>) -> T {
    var buffer: T = 0
    for i in range {
      buffer <<= 8
      switch i {
      case 0: buffer |= T(bytes.0)
      case 1: buffer |= T(bytes.1)
      case 2: buffer |= T(bytes.2)
      case 3: buffer |= T(bytes.3)
      case 4: buffer |= T(bytes.4)
      case 5: buffer |= T(bytes.5)
      case 6: buffer |= T(bytes.6)
      case 7: buffer |= T(bytes.7)
      case 8: buffer |= T(bytes.8)
      case 9: buffer |= T(bytes.9)
      case 10: buffer |= T(bytes.10)
      case 11: buffer |= T(bytes.11)
      case 12: buffer |= T(bytes.12)
      case 13: buffer |= T(bytes.13)
      case 14: buffer |= T(bytes.14)
      case 15: buffer |= T(bytes.15)
      default: fatalError("unreachable")
      }
    }
    return buffer
  }
}

/// Digit characters used in the Base36 notation.
private let digits = [UInt8]("0123456789abcdefghijklmnopqrstuvwxyz".utf8)

/// An O(1) map from ASCII code points to Base36 digit values.
private let decodeMap: [UInt8] = [
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
  0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
  0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
]

extension Scru128Id: Comparable, Hashable {
  private static func compare(_ lhs: Scru128Id, _ rhs: Scru128Id) -> Int {
    if lhs.bytes.0 != rhs.bytes.0 { return lhs.bytes.0 < rhs.bytes.0 ? -1 : 1 }
    if lhs.bytes.1 != rhs.bytes.1 { return lhs.bytes.1 < rhs.bytes.1 ? -1 : 1 }
    if lhs.bytes.2 != rhs.bytes.2 { return lhs.bytes.2 < rhs.bytes.2 ? -1 : 1 }
    if lhs.bytes.3 != rhs.bytes.3 { return lhs.bytes.3 < rhs.bytes.3 ? -1 : 1 }
    if lhs.bytes.4 != rhs.bytes.4 { return lhs.bytes.4 < rhs.bytes.4 ? -1 : 1 }
    if lhs.bytes.5 != rhs.bytes.5 { return lhs.bytes.5 < rhs.bytes.5 ? -1 : 1 }
    if lhs.bytes.6 != rhs.bytes.6 { return lhs.bytes.6 < rhs.bytes.6 ? -1 : 1 }
    if lhs.bytes.7 != rhs.bytes.7 { return lhs.bytes.7 < rhs.bytes.7 ? -1 : 1 }
    if lhs.bytes.8 != rhs.bytes.8 { return lhs.bytes.8 < rhs.bytes.8 ? -1 : 1 }
    if lhs.bytes.9 != rhs.bytes.9 { return lhs.bytes.9 < rhs.bytes.9 ? -1 : 1 }
    if lhs.bytes.10 != rhs.bytes.10 { return lhs.bytes.10 < rhs.bytes.10 ? -1 : 1 }
    if lhs.bytes.11 != rhs.bytes.11 { return lhs.bytes.11 < rhs.bytes.11 ? -1 : 1 }
    if lhs.bytes.12 != rhs.bytes.12 { return lhs.bytes.12 < rhs.bytes.12 ? -1 : 1 }
    if lhs.bytes.13 != rhs.bytes.13 { return lhs.bytes.13 < rhs.bytes.13 ? -1 : 1 }
    if lhs.bytes.14 != rhs.bytes.14 { return lhs.bytes.14 < rhs.bytes.14 ? -1 : 1 }
    if lhs.bytes.15 != rhs.bytes.15 { return lhs.bytes.15 < rhs.bytes.15 ? -1 : 1 }
    return 0
  }

  public static func == (lhs: Scru128Id, rhs: Scru128Id) -> Bool {
    compare(lhs, rhs) == 0
  }

  public static func < (lhs: Scru128Id, rhs: Scru128Id) -> Bool {
    compare(lhs, rhs) < 0
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(bytes.0)
    hasher.combine(bytes.1)
    hasher.combine(bytes.2)
    hasher.combine(bytes.3)
    hasher.combine(bytes.4)
    hasher.combine(bytes.5)
    hasher.combine(bytes.6)
    hasher.combine(bytes.7)
    hasher.combine(bytes.8)
    hasher.combine(bytes.9)
    hasher.combine(bytes.10)
    hasher.combine(bytes.11)
    hasher.combine(bytes.12)
    hasher.combine(bytes.13)
    hasher.combine(bytes.14)
    hasher.combine(bytes.15)
  }
}

extension Scru128Id: Codable {
  /// Encodes the object as a 25-digit canonical string representation.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  /// Decodes the object from a 25-digit canonical string representation or  a 16-byte big-endian
  /// byte array.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let strValue = try? container.decode(String.self) {
      guard let bs = Self.parse(strValue) else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "could not parse string as Scru128Id")
      }
      self.init(bs)
    } else if let byteArray = try? container.decode([UInt8].self) {
      if byteArray.count == 16 {
        self.init(byteArray)
      } else if byteArray.allSatisfy({ $0 < 0x80 }) {
        let strValue = String(cString: byteArray + [0])
        guard let bs = Self.parse(strValue) else {
          throw DecodingError.dataCorruptedError(
            in: container, debugDescription: "could not parse byte array as Scru128Id")
        }
        self.init(bs)
      } else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "could not parse byte array as Scru128Id")
      }
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "expected string or byte array but found neither")
    }
  }
}

extension Scru128Id: Sendable {}
