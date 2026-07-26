import XCTest
@testable import OrdoCore

final class StatsTests: CoreTestCase {

    private func summary(_ day: DayKey, completed: Int, open: Int) -> DaySummary {
        DaySummary(day: day, completed: completed, stillOpen: open,
                   fullyCleared: completed > 0 && open == 0)
    }
    private func doneToday() -> OrdoTask {
        OrdoTask(title: "d", list: .today, done: true,
                 createdAt: Date(), addedToTodayOn: T.day(2026, 7, 30),
                 completedAt: Date(), order: 1)
    }
    private func openToday() -> OrdoTask {
        OrdoTask(title: "o", list: .today, createdAt: Date(),
                 addedToTodayOn: T.day(2026, 7, 30), order: 1)
    }

    // §7: cleared-day definition.
    func testClearedDayDefinition() {
        XCTAssertTrue(summary(T.day(2026, 7, 1), completed: 2, open: 0).fullyCleared)
        XCTAssertFalse(summary(T.day(2026, 7, 1), completed: 0, open: 0).fullyCleared) // no tasks
        XCTAssertFalse(summary(T.day(2026, 7, 1), completed: 1, open: 1).fullyCleared) // leftovers
    }

    // PLAN §5 / §7: zero-task days are neutral — a weekend off neither breaks nor
    // extends a streak.
    func testStreakZeroTaskDayNeutrality() {
        let today = T.day(2026, 7, 30)
        let summaries = [
            summary(T.day(2026, 7, 27), completed: 1, open: 0), // cleared
            // 07-28 has NO summary — a zero-task day (neutral)
            summary(T.day(2026, 7, 29), completed: 1, open: 0), // cleared
        ]
        let stats = StatsEngine.compute(liveTodayTasks: [doneToday()], today: today,
                                        summaries: summaries, archivedCount: 0)
        XCTAssertEqual(stats.currentStreak, 3) // today + 29 + (28 skipped) + 27
    }

    func testStreakBreaksOnNotClearedPastDay() {
        let today = T.day(2026, 7, 30)
        let summaries = [
            summary(T.day(2026, 7, 28), completed: 1, open: 0), // cleared
            summary(T.day(2026, 7, 29), completed: 1, open: 1), // NOT cleared → breaks
        ]
        let stats = StatsEngine.compute(liveTodayTasks: [doneToday()], today: today,
                                        summaries: summaries, archivedCount: 0)
        XCTAssertEqual(stats.currentStreak, 1) // only today
    }

    func testTodayInProgressGetsGraceAndStreakEndsYesterday() {
        let today = T.day(2026, 7, 30)
        let summaries = [
            summary(T.day(2026, 7, 28), completed: 1, open: 0),
            summary(T.day(2026, 7, 29), completed: 1, open: 0),
        ]
        // Today still has an open task (not cleared): grace pass, streak = 28+29.
        let stats = StatsEngine.compute(liveTodayTasks: [openToday()], today: today,
                                        summaries: summaries, archivedCount: 0)
        XCTAssertEqual(stats.currentStreak, 2)
    }

    func testStreakEndsYesterdayWhenTodayHasNoTasks() {
        let today = T.day(2026, 7, 30)
        let summaries = [
            summary(T.day(2026, 7, 28), completed: 1, open: 0),
            summary(T.day(2026, 7, 29), completed: 1, open: 0),
        ]
        // Today is a zero-task day (neutral); yesterday's cleared streak still shows.
        let stats = StatsEngine.compute(liveTodayTasks: [], today: today,
                                        summaries: summaries, archivedCount: 0)
        XCTAssertEqual(stats.currentStreak, 2)
    }

    func testNoStreakWhenNothingCleared() {
        let stats = StatsEngine.compute(liveTodayTasks: [], today: T.day(2026, 7, 30),
                                        summaries: [], archivedCount: 0)
        XCTAssertEqual(stats.currentStreak, 0)
    }

    func testDuplicateSummaryDaysAreDeduped() {
        let today = T.day(2026, 7, 30)
        // A crash-retry could append two lines for the same day; last wins, count once.
        let summaries = [
            summary(T.day(2026, 7, 29), completed: 1, open: 0),
            summary(T.day(2026, 7, 29), completed: 1, open: 0),
        ]
        let stats = StatsEngine.compute(liveTodayTasks: [doneToday()], today: today,
                                        summaries: summaries, archivedCount: 0)
        XCTAssertEqual(stats.currentStreak, 2) // today + 29 (counted once)
        XCTAssertEqual(stats.clearedDays, 1)
    }

    // Live today ratio.
    func testTodayLiveRatio() {
        let store = makeStore()
        let a = store.add("a", to: .today).inserted[0]
        store.add("b", to: .today)
        store.add("c", to: .today)
        store.setDone(a, true)
        let stats = store.stats()
        XCTAssertEqual(stats.todayDone, 1)
        XCTAssertEqual(stats.todayOpen, 2)
        XCTAssertEqual(stats.todayTotal, 3)
        XCTAssertFalse(stats.todayCleared)
    }

    // Integration: completing everything then rolling over builds a real streak.
    func testStreakIntegrationAcrossRollovers() {
        let store = makeStore() // starts 2026-07-26
        // Day 26: one task, cleared.
        let t1 = store.add("mon", to: .today).inserted[0]
        store.setDone(t1, true)
        clock.set(year: 2026, month: 7, day: 27, hour: 8)
        store.catchUp()
        // Day 27: one task, cleared.
        let t2 = store.add("tue", to: .today).inserted[0]
        store.setDone(t2, true)
        clock.set(year: 2026, month: 7, day: 28, hour: 8)
        store.catchUp()
        // Day 28 (today): one task, cleared live.
        let t3 = store.add("wed", to: .today).inserted[0]
        store.setDone(t3, true)

        let stats = store.stats()
        XCTAssertEqual(stats.currentStreak, 3)
        XCTAssertEqual(stats.lifetimeCompleted, 2) // t1, t2 archived; t3 still live
        XCTAssertTrue(stats.todayCleared)
    }
}
