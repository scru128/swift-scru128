import XCTest

@testable import Scru128

final class Scru128GeneratorTests: XCTestCase {
  /// Generates increasing IDs even with decreasing or constant timestamp
  func testDecreasingOrConstantTimestamp() throws {
    let ts: UInt64 = 0x0123_4567_89ab
    let g = Scru128Generator()
    var (prev, status) = g.generateCore(ts)
    XCTAssertEqual(status, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)
    for i in UInt64(0)..<100_000 {
      let (curr, status) = g.generateCore(ts - min(9_998, i))
      XCTAssertTrue(
        status == Scru128Generator.Status.counterLoInc
          || status == Scru128Generator.Status.counterHiInc
          || status == Scru128Generator.Status.timestampInc)
      XCTAssertLessThan(prev, curr)
      prev = curr
    }
    XCTAssertGreaterThanOrEqual(prev.timestamp, ts)
  }

  /// Breaks increasing order of IDs if timestamp moves backward a lot
  func testTimestampRollback() throws {
    let ts: UInt64 = 0x0123_4567_89ab
    let g = Scru128Generator()
    let (prev, prevStatus) = g.generateCore(ts)
    XCTAssertEqual(prevStatus, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)
    let (curr, currStatus) = g.generateCore(ts - 10_000)
    XCTAssertEqual(currStatus, Scru128Generator.Status.clockRollback)
    XCTAssertGreaterThan(prev, curr)
    XCTAssertEqual(curr.timestamp, ts - 10_000)
  }
}
