import XCTest

@testable import Scru128

final class Scru128IdTests: XCTestCase {
  /// Encodes and decodes prepared cases correctly
  func testEncodeDecode() throws {
    let cases: [((UInt64, UInt32, UInt32, UInt32), String)] = [
      ((0, 0, 0, 0), "00000000000000000000000000"),
      (((1 << 44) - 1, 0, 0, 0), "7VVVVVVVVG0000000000000000"),
      (((1 << 44) - 1, 0, 0, 0), "7vvvvvvvvg0000000000000000"),
      ((0, (1 << 28) - 1, 0, 0), "000000000FVVVVU00000000000"),
      ((0, (1 << 28) - 1, 0, 0), "000000000fvvvvu00000000000"),
      ((0, 0, (1 << 24) - 1, 0), "000000000000001VVVVS000000"),
      ((0, 0, (1 << 24) - 1, 0), "000000000000001vvvvs000000"),
      ((0, 0, 0, 0xFFFF_FFFF), "00000000000000000003VVVVVV"),
      ((0, 0, 0, 0xFFFF_FFFF), "00000000000000000003vvvvvv"),
      (((1 << 44) - 1, (1 << 28) - 1, (1 << 24) - 1, 0xFFFF_FFFF), "7VVVVVVVVVVVVVVVVVVVVVVVVV"),
      (((1 << 44) - 1, (1 << 28) - 1, (1 << 24) - 1, 0xFFFF_FFFF), "7vvvvvvvvvvvvvvvvvvvvvvvvv"),
    ]

    for e in cases {
      let fromFields = Scru128Id(e.0.0, e.0.1, e.0.2, e.0.3)
      let fromString = Scru128Id(e.1)!

      XCTAssertEqual(fromFields, fromString)
      XCTAssertEqual(fromFields.timestamp, e.0.0)
      XCTAssertEqual(fromString.timestamp, e.0.0)
      XCTAssertEqual(fromFields.counter, e.0.1)
      XCTAssertEqual(fromString.counter, e.0.1)
      XCTAssertEqual(fromFields.perSecRandom, e.0.2)
      XCTAssertEqual(fromString.perSecRandom, e.0.2)
      XCTAssertEqual(fromFields.perGenRandom, e.0.3)
      XCTAssertEqual(fromString.perGenRandom, e.0.3)
      XCTAssertEqual(fromFields.description, e.1.uppercased())
      XCTAssertEqual(fromString.description, e.1.uppercased())
    }
  }

  /// Returns error if an invalid string representation is supplied
  func testStringValidation() throws {
    let cases = [
      "",
      " 00SCT4FL89GQPRHN44C4LFM0OV",
      "00SCT4FL89GQPRJN44C7SQO381 ",
      " 00SCT4FL89GQPRLN44C4BGCIIO ",
      "+00SCT4FL89GQPRNN44C4F3QD24",
      "-00SCT4FL89GQPRPN44C7H4E5RC",
      "+0SCT4FL89GQPRRN44C55Q7RVC",
      "-0SCT4FL89GQPRTN44C6PN0A2R",
      "00SCT4FL89WQPRVN44C41RGVMM",
      "00SCT4FL89GQPS1N4_C54QDC5O",
      "00SCT4-L89GQPS3N44C602O0K8",
      "00SCT4FL89GQPS N44C7VHS5QJ",
      "80000000000000000000000000",
      "VVVVVVVVVVVVVVVVVVVVVVVVVV",
    ]

    for e in cases {
      XCTAssertNil(Scru128Id(e))
    }
  }

  /// Has symmetric converters from/to String, byte array, fields, and serialized form
  func testSymmetricConverters() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let g = Scru128Generator()
    for _ in 0..<1_000 {
      let obj = g.generate()
      XCTAssertEqual(Scru128Id(obj.description)!, obj)
      XCTAssertEqual(Scru128Id(obj.bytes), obj)
      XCTAssertEqual(
        Scru128Id(obj.timestamp, obj.counter, obj.perSecRandom, obj.perGenRandom),
        obj
      )
      XCTAssertEqual(
        try decoder.decode(Scru128Id.self, from: try encoder.encode(obj)),
        obj
      )
    }
  }

  /// Supports comparison operators
  func testComparisonOperators() throws {
    var ordered = [
      Scru128Id(0, 0, 0, 0),
      Scru128Id(0, 0, 0, 1),
      Scru128Id(0, 0, 0, 0xFFFF_FFFF),
      Scru128Id(0, 0, 1, 0),
      Scru128Id(0, 0, 0xFF_FFFF, 0),
      Scru128Id(0, 1, 0, 0),
      Scru128Id(0, 0xFFF_FFFF, 0, 0),
      Scru128Id(1, 0, 0, 0),
      Scru128Id(2, 0, 0, 0),
    ]

    let g = Scru128Generator()
    for _ in 0..<1_000 {
      ordered.append(g.generate())
    }

    var prev = ordered.removeFirst()
    for curr in ordered {
      XCTAssertNotEqual(curr, prev)
      XCTAssertNotEqual(prev, curr)
      XCTAssertNotEqual(curr.hashValue, prev.hashValue)
      XCTAssertGreaterThan(curr, prev)
      XCTAssertGreaterThanOrEqual(curr, prev)
      XCTAssertLessThan(prev, curr)
      XCTAssertLessThanOrEqual(prev, curr)

      let clone = curr
      XCTAssertEqual(curr, clone)
      XCTAssertEqual(clone, curr)
      XCTAssertEqual(curr.hashValue, clone.hashValue)
      XCTAssertGreaterThanOrEqual(curr, clone)
      XCTAssertGreaterThanOrEqual(clone, curr)
      XCTAssertLessThanOrEqual(curr, clone)
      XCTAssertLessThanOrEqual(clone, curr)

      prev = curr
    }
  }

  /// Serializes and deserializes an object using the canonical string representation
  func testSerializedForm() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let g = Scru128Generator()
    for _ in 0..<1_000 {
      let obj = g.generate()
      let strJson = "\"\(obj)\""
      XCTAssertEqual(
        String(data: try encoder.encode(obj), encoding: .utf8),
        strJson
      )
      XCTAssertEqual(
        try decoder.decode(Scru128Id.self, from: strJson.data(using: .utf8)!),
        obj
      )
    }
  }
}
