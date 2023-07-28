/// Represents a SCRU128 ID and provides converters and comparison operators.
public struct Scru128Id: LosslessStringConvertible {
  /// **Deprecated.** Use ``byteArray`` instead. From v3.0.0, this property will return a tuple of
  /// 16 byte values instead of a byte array.
  ///
  /// Returns a 16-byte byte array containing the 128-bit unsigned integer representation in the
  /// big-endian (network) byte order.
  public let bytes: [UInt8]

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
    self.bytes = [
      bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
      bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
    ]
  }

  /// Creates an object from a byte array that represents a 128-bit unsigned integer.
  ///
  /// - Parameter byteArray: A 16-byte byte array that represents a 128-bit unsigned integer in the
  ///                        big-endian (network) byte order.
  /// - Precondition: The byte length of the argument must be 16.
  public init(_ byteArray: [UInt8]) {
    precondition(byteArray.count == 16)
    bytes = byteArray
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
    bytes = [
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
      UInt8(truncatingIfNeeded: entropy),
    ]
  }

  /// Creates an object from a 25-digit string representation.
  public init?(_ description: String) {
    guard let bs = Self.parse(description) else {
      return nil
    }
    bytes = bs
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
  public var byteArray: [UInt8] { bytes }

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
    for e in bytes[range] {
      buffer = (buffer << 8) | T(e)
    }
    return buffer
  }
}

/// Digit characters used in the Base36 notation.
private let digits = [UInt8]("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)

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
