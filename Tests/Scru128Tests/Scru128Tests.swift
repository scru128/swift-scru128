import XCTest

@testable import Scru128

final class Scru128Tests: XCTestCase {
  static let samples: [String] = (0..<100_000).map { _ in scru128String() }

  /// Generates 26-digit canonical string
  func testFormat() throws {
    for e in Self.samples {
      XCTAssertNotNil(e.range(of: "^[0-7][0-9A-V]{25}$", options: .regularExpression))
    }
  }

  /// Generates 100k identifiers without collision
  func testUniqueness() throws {
    let set = Set(Self.samples)
    XCTAssertEqual(set.count, Self.samples.count)
  }

  /// Generates sortable string representation by creation time
  func testOrder() throws {
    for i in 1..<Self.samples.count {
      XCTAssertLessThan(Self.samples[i - 1], Self.samples[i])
    }
  }

  /// Encodes up-to-date timestamp
  func testTimestamp() throws {
    let g = Scru128Generator()
    for _ in 0..<10_000 {
      let tsNow = Int64(Date().timeIntervalSince1970 * 1_000) - 1_577_836_800_000
      let timestamp = Int64(g.generate().timestamp)
      XCTAssertLessThan(abs(tsNow - timestamp), 16)
    }
  }

  /// Encodes unique sortable pair of timestamp and counter
  func testTimestampAndCounter() throws {
    var prev = Scru128Id(Self.samples[0])!
    for i in 1..<Self.samples.count {
      let curr = Scru128Id(Self.samples[i])!
      XCTAssertTrue(
        prev.timestamp < curr.timestamp
          || (prev.timestamp == curr.timestamp && prev.counter < curr.counter)
      )
      prev = curr
    }
  }

  /// Generates no IDs sharing same timestamp and counter under multithreading
  func testThreading() throws {
    var results: [Scru128Id] = []
    let resultsQueue = DispatchQueue(label: "serial queue to protect array")

    let group = DispatchGroup()
    for _ in 0..<4 {
      DispatchQueue.global().async(group: group) {
        let xs = (0..<10_000).map { _ in scru128() }
        resultsQueue.sync { results.append(contentsOf: xs) }
      }
    }
    group.wait()

    let set = Set<String>(results.map { "\($0.timestamp)-\($0.counter)" })
    XCTAssertEqual(set.count, results.count)
  }
}
