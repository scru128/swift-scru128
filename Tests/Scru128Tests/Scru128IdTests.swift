import XCTest

@testable import Scru128

let maxUint48: UInt64 = (1 << 48) - 1
let maxUint24: UInt32 = (1 << 24) - 1
let maxUint32: UInt32 = UInt32.max

final class Scru128IdTests: XCTestCase {
  /// Encodes and decodes prepared cases correctly
  func testEncodeDecode() throws {
    let cases: [((UInt64, UInt32, UInt32, UInt32), String)] = [
      ((0, 0, 0, 0), "0000000000000000000000000"),
      ((maxUint48, 0, 0, 0), "F5LXX1ZZ5K6TP71GEEH2DB7K0"),
      ((maxUint48, 0, 0, 0), "f5lxx1zz5k6tp71geeh2db7k0"),
      ((0, maxUint24, 0, 0), "0000000005GV2R2KJWR7N8XS0"),
      ((0, maxUint24, 0, 0), "0000000005gv2r2kjwr7n8xs0"),
      ((0, 0, maxUint24, 0), "00000000000000JPIA7QL4HS0"),
      ((0, 0, maxUint24, 0), "00000000000000jpia7ql4hs0"),
      ((0, 0, 0, maxUint32), "0000000000000000001Z141Z3"),
      ((0, 0, 0, maxUint32), "0000000000000000001z141z3"),
      ((maxUint48, maxUint24, maxUint24, maxUint32), "F5LXX1ZZ5PNORYNQGLHZMSP33"),
      ((maxUint48, maxUint24, maxUint24, maxUint32), "f5lxx1zz5pnorynqglhzmsp33"),
    ]

    for e in cases {
      let fromFields = Scru128Id(e.0.0, e.0.1, e.0.2, e.0.3)
      let fromString = Scru128Id(e.1)!

      XCTAssertEqual(fromFields, fromString)
      XCTAssertEqual(fromFields.timestamp, e.0.0)
      XCTAssertEqual(fromString.timestamp, e.0.0)
      XCTAssertEqual(fromFields.counterHi, e.0.1)
      XCTAssertEqual(fromString.counterHi, e.0.1)
      XCTAssertEqual(fromFields.counterLo, e.0.2)
      XCTAssertEqual(fromString.counterLo, e.0.2)
      XCTAssertEqual(fromFields.entropy, e.0.3)
      XCTAssertEqual(fromString.entropy, e.0.3)
      XCTAssertEqual(fromFields.description, e.1.lowercased())
      XCTAssertEqual(fromString.description, e.1.lowercased())
    }
  }

  /// Returns error if an invalid string representation is supplied
  func testStringValidation() throws {
    let cases = [
      "",
      " 036z8puq4tsxsigk6o19y164q",
      "036z8puq54qny1vq3hcbrkweb ",
      " 036z8puq54qny1vq3helivwax ",
      "+036z8puq54qny1vq3hfcv3ss0",
      "-036z8puq54qny1vq3hhy8u1ch",
      "+36z8puq54qny1vq3hjq48d9p",
      "-36z8puq5a7j0ti08oz6zdrdy",
      "036z8puq5a7j0t_08p2cdz28v",
      "036z8pu-5a7j0ti08p3ol8ool",
      "036z8puq5a7j0ti08p4j 6cya",
      "f5lxx1zz5pnorynqglhzmsp34",
      "zzzzzzzzzzzzzzzzzzzzzzzzz",
      "039o\tvvklfmqlqe7fzllz7c7t",
      "039onvvklfmqlq漢字fgvd1",
      "039onvvkl🤣qe7fzr2hdoqu",
      "頭onvvklfmqlqe7fzrhtgcfz",
      "039onvvklfmqlqe7fztft5尾",
      "039漢字a52xp4bvf4sn94e09cja",
      "039ooa52xp4bv😘sn97642mwl",
    ]

    for e in cases {
      XCTAssertNil(Scru128Id(e))
    }
  }

  /// Has symmetric converters from/to various values
  func testSymmetricConverters() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    var cases = [
      Scru128Id(0, 0, 0, 0),
      Scru128Id(maxUint48, 0, 0, 0),
      Scru128Id(0, maxUint24, 0, 0),
      Scru128Id(0, 0, maxUint24, 0),
      Scru128Id(0, 0, 0, maxUint32),
      Scru128Id(maxUint48, maxUint24, maxUint24, maxUint32),
    ]

    let g = Scru128Generator()
    for _ in 0..<1_000 {
      cases.append(g.generate())
    }

    for e in cases {
      XCTAssertEqual(Scru128Id(e.description)!, e)
      XCTAssertEqual(Scru128Id(e.bytes), e)
      XCTAssertEqual(Scru128Id(e.timestamp, e.counterHi, e.counterLo, e.entropy), e)
      XCTAssertEqual(try decoder.decode(Scru128Id.self, from: try encoder.encode(e)), e)
    }
  }

  /// Supports comparison operators
  func testComparisonOperators() throws {
    var ordered = [
      Scru128Id(0, 0, 0, 0),
      Scru128Id(0, 0, 0, 1),
      Scru128Id(0, 0, 0, maxUint32),
      Scru128Id(0, 0, 1, 0),
      Scru128Id(0, 0, maxUint24, 0),
      Scru128Id(0, 1, 0, 0),
      Scru128Id(0, maxUint24, 0, 0),
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
      XCTAssertEqual(String(data: try encoder.encode(obj), encoding: .utf8), strJson)
      XCTAssertEqual(try decoder.decode(Scru128Id.self, from: strJson.data(using: .utf8)!), obj)
    }
  }

  /// Decodes an object from string and binary representations
  func testDecodable() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let g = Scru128Generator()
    for _ in 0..<1_000 {
      let obj = g.generate()
      let desc = obj.description
      let asStr = try encoder.encode(desc)
      let asBytes = try encoder.encode(obj.bytes)
      let asStrBytes = try encoder.encode([UInt8](desc.utf8))

      XCTAssertEqual(try decoder.decode(Scru128Id.self, from: asStr), obj)
      XCTAssertEqual(try decoder.decode(Scru128Id.self, from: asBytes), obj)
      XCTAssertEqual(try decoder.decode(Scru128Id.self, from: asStrBytes), obj)
    }
  }
}
