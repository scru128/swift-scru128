import XCTest

@testable import Scru128

final class Scru128Tests: XCTestCase {
  static let samples: [String] = (0..<100_000).map { _ in scru128String() }

  /// Generates 25-digit canonical string
  func testFormat() throws {
    for e in Self.samples {
      XCTAssertNotNil(e.range(of: "^[0-9a-z]{25}$", options: .regularExpression))
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
      let tsNow = Int64(Date().timeIntervalSince1970 * 1_000)
      let timestamp = Int64(g.generate().timestamp)
      XCTAssertLessThan(abs(tsNow - timestamp), 16)
    }
  }

  /// Encodes unique sortable tuple of timestamp and counters
  func testTimestampAndCounters() throws {
    var prev = Scru128Id(Self.samples[0])!
    for i in 1..<Self.samples.count {
      let curr = Scru128Id(Self.samples[i])!
      XCTAssertTrue(
        prev.timestamp < curr.timestamp
          || (prev.timestamp == curr.timestamp && prev.counterHi < curr.counterHi)
          || (prev.timestamp == curr.timestamp && prev.counterHi == curr.counterHi
            && prev.counterLo < curr.counterLo)
      )
      prev = curr
    }
  }

  /// Generates no IDs sharing same timestamp and counters under multithreading
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
  func testThreading() async throws {
    let results = await withTaskGroup(of: [Scru128Id].self) { group in
      for _ in 0..<4 {
        group.addTask { (0..<10_000).map { _ in scru128() } }
      }

      var results: [Scru128Id] = []
      for await xs in group {
        results.append(contentsOf: xs)
      }
      return results
    }

    let set = Set<String>(results.map { "\($0.timestamp)-\($0.counterHi)-\($0.counterLo)" })
    XCTAssertEqual(set.count, results.count)
  }
}
