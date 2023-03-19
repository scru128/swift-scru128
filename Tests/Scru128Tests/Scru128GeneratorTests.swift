import XCTest

@testable import Scru128

final class Scru128GeneratorGenerateCoreTests: XCTestCase {
  /// Generates increasing IDs even with decreasing or constant timestamp
  func testDecreasingOrConstantTimestamp() throws {
    let ts: UInt64 = 0x0123_4567_89ab
    let g = Scru128Generator()
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.notExecuted)

    var prev = g.generateCore(timestamp: ts, rollbackAllowance: 10_000)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)

    for i in UInt64(0)..<100_000 {
      let curr = g.generateCore(timestamp: ts - min(9_998, i), rollbackAllowance: 10_000)
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

    var prev = g.generateCore(timestamp: ts, rollbackAllowance: 10_000)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)

    var curr = g.generateCore(timestamp: ts - 10_000, rollbackAllowance: 10_000)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.clockRollback)
    XCTAssertGreaterThan(prev, curr)
    XCTAssertEqual(curr.timestamp, ts - 10_000)

    prev = curr
    curr = g.generateCore(timestamp: ts - 10_001, rollbackAllowance: 10_000)
    XCTAssertTrue(
      g.lastStatus == Scru128Generator.Status.counterLoInc
        || g.lastStatus == Scru128Generator.Status.counterHiInc
        || g.lastStatus == Scru128Generator.Status.timestampInc)
    XCTAssertLessThan(prev, curr)
  }
}

final class Scru128GeneratorGenerateCoreNoRewindTests: XCTestCase {
  /// Generates increasing IDs even with decreasing or constant timestamp
  func testDecreasingOrConstantTimestamp() throws {
    let ts: UInt64 = 0x0123_4567_89ab
    let g = Scru128Generator()
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.notExecuted)

    var prev = g.generateCoreNoRewind(timestamp: ts, rollbackAllowance: 10_000)!
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)

    for i in UInt64(0)..<100_000 {
      let curr = g.generateCoreNoRewind(timestamp: ts - min(9_998, i), rollbackAllowance: 10_000)!
      XCTAssertTrue(
        g.lastStatus == Scru128Generator.Status.counterLoInc
          || g.lastStatus == Scru128Generator.Status.counterHiInc
          || g.lastStatus == Scru128Generator.Status.timestampInc)
      XCTAssertLessThan(prev, curr)
      prev = curr
    }
    XCTAssertGreaterThanOrEqual(prev.timestamp, ts)
  }

  /// Returns nil if timestamp moves backward a lot
  func testTimestampRollback() throws {
    let ts: UInt64 = 0x0123_4567_89ab
    let g = Scru128Generator()
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.notExecuted)

    let prev = g.generateCoreNoRewind(timestamp: ts, rollbackAllowance: 10_000)!
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)
    XCTAssertEqual(prev.timestamp, ts)

    var curr = g.generateCoreNoRewind(timestamp: ts - 10_000, rollbackAllowance: 10_000)
    XCTAssertNil(curr)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)

    curr = g.generateCoreNoRewind(timestamp: ts - 10_001, rollbackAllowance: 10_000)
    XCTAssertNil(curr)
    XCTAssertEqual(g.lastStatus, Scru128Generator.Status.newTimestamp)
  }
}

final class Scru128GeneratorTests: XCTestCase {
  /// Is iterable with for-in loop
  func testSequenceImplementation() throws {
    var i = 0
    for e in Scru128Generator() {
      XCTAssertGreaterThan(e.timestamp, 0)
      i += 1
      if i > 100 {
        break
      }
    }
    XCTAssertEqual(i, 101)
  }
}
