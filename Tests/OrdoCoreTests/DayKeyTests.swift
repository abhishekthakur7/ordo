import XCTest
@testable import OrdoCore

final class DayKeyTests: XCTestCase {

    func testComparableAndDescription() {
        XCTAssertLessThan(T.day(2026, 7, 26), T.day(2026, 7, 27))
        XCTAssertLessThan(T.day(2026, 7, 31), T.day(2026, 8, 1))
        XCTAssertLessThan(T.day(2025, 12, 31), T.day(2026, 1, 1))
        XCTAssertEqual(T.day(2026, 7, 6).description, "2026-07-06")
        XCTAssertEqual(T.day(2026, 7, 6).monthKey, "2026-07")
    }

    func testAddingCrossesMonthAndYearBoundaries() {
        XCTAssertEqual(T.day(2026, 7, 31).adding(1), T.day(2026, 8, 1))
        XCTAssertEqual(T.day(2026, 12, 31).adding(1), T.day(2027, 1, 1))
        XCTAssertEqual(T.day(2026, 3, 1).adding(-1), T.day(2026, 2, 28))
        XCTAssertEqual(T.day(2024, 3, 1).adding(-1), T.day(2024, 2, 29)) // leap
    }

    func testDaysSince() {
        XCTAssertEqual(T.day(2026, 7, 26).days(since: T.day(2026, 7, 26)), 0)
        XCTAssertEqual(T.day(2026, 8, 2).days(since: T.day(2026, 7, 26)), 7)
        XCTAssertEqual(T.day(2026, 7, 26).days(since: T.day(2026, 8, 2)), -7)
    }

    func testCodableRoundTripAsISOString() throws {
        let key = T.day(2026, 7, 26)
        let data = try JSONEncoder().encode(key)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"2026-07-26\"")
        XCTAssertEqual(try JSONDecoder().decode(DayKey.self, from: data), key)
    }

    func testParsingMalformedStringsFails() {
        XCTAssertNil(DayKey(string: "not-a-date"))
        XCTAssertNil(DayKey(string: "2026-13-01"))
        XCTAssertNil(DayKey(string: "2026-07"))
        XCTAssertNotNil(DayKey(string: "2026-07-26"))
    }

    // dayKey math around midnight with explicit time zones (PLAN §5).
    func testDayKeyMidnightBoundaryExplicitTimeZones() {
        let engine = DayEngine(dayStartOffset: 0)

        // 23:30 in New York is still 07-26 locally...
        let lateNY = FixedClock(year: 2026, month: 7, day: 26, hour: 23, minute: 30, timeZone: T.ny)
        XCTAssertEqual(engine.dayKey(for: lateNY.now, timeZone: T.ny), T.day(2026, 7, 26))
        // ...but the same instant in UTC is already 07-27 (23:30 EDT == 03:30 UTC).
        XCTAssertEqual(engine.dayKey(for: lateNY.now, timeZone: T.utc), T.day(2026, 7, 27))

        // 00:30 NY is the next local day.
        let earlyNY = FixedClock(year: 2026, month: 7, day: 27, hour: 0, minute: 30, timeZone: T.ny)
        XCTAssertEqual(engine.dayKey(for: earlyNY.now, timeZone: T.ny), T.day(2026, 7, 27))
    }
}
