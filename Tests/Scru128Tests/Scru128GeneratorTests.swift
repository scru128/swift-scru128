import XCTest

@testable import Scru128

final class Scru128GeneratorTests: XCTestCase {
  /// Generates increasing IDs even with decreasing or constant timestamp
  func testDecreasingOrConstantTimestamp() throws {
    let ts: UInt64 = 0x0123_4567_89ab
    let g = Scru128Generator()
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.notExecuted)

    var prev = g.generateCore(ts)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)

    for i in UInt64(0)..<100_000 {
      let curr = g.generateCore(ts - min(9_998, i))
      XCTAssertTrue(
        g.lastStatus == Scru128Generator.Status.counterLoInc
          || g.lastStatus == Scru128Generator.Status.counterHiInc
          || g.lastStatus == Scru128Generator.Status.timestampInc)
      XCTAssertLessThan(prev, curr)
      prev = curr
    }
    XCTAssertGreaterThanOrEqual(prev.timestamp, ts)
  }

  /// Breaks increasing order of IDs if timestamp moves backward a lot
  func testTimestampRollback() throws {
    let ts: UInt64 = 0x0123_4567_89ab
    let g = Scru128Generator()
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.notExecuted)

    let prev = g.generateCore(ts)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)

    let curr = g.generateCore(ts - 10_000)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.clockRollback)
    XCTAssertGreaterThan(prev, curr)
    XCTAssertEqual(curr.timestamp, ts - 10_000)
  }
}
