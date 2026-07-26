import XCTest
@testable import OrdoCore

/// Exhaustive coverage of ARCHITECTURE §3.4's day-boundary table, plus offset,
/// idempotence, DST, and timezone behavior. Uses the pure `DayEngine` and
/// integration through `TaskStore`.
final class DayEngineTests: CoreTestCase {

    private let engine = DayEngine(dayStartOffset: 0)

    // Builds a state whose lastProcessedDay is `last`.
    private func state(last: DayKey, tasks: [OrdoTask] = []) -> StoreState {
        StoreState(lastProcessedDay: last, tasks: tasks)
    }

    private func todayTask(_ title: String, added: DayKey,
                           done: Bool = false, completed: Date? = nil,
                           order: Double = 1) -> OrdoTask {
        OrdoTask(title: title, list: .today, done: done,
                 createdAt: added.utcDate(), addedToTodayOn: added,
                 completedAt: completed, order: order)
    }

    // §3.4: First launch — lastProcessedDay = today, no catch-up.
    func testFirstLaunchSetsTodayNoCatchUp() {
        let store = makeStore()
        XCTAssertTrue(store.isFirstLaunch)
        XCTAssertEqual(store.lastProcessedDay, T.day(2026, 7, 26))
        XCTAssertTrue(store.catchUp().isEmpty) // no-op: today == lastProcessed
    }

    // §3.4: Clock set backwards — monotonic guard no-op, never un-archives.
    func testClockBackwardsIsNoOp() {
        let s = state(last: T.day(2026, 7, 26))
        let earlier = FixedClock(year: 2026, month: 7, day: 25, timeZone: T.utc)
        XCTAssertNil(engine.computeCatchUp(state: s, now: earlier.now,
                                           timeZone: T.utc, undoWindow: 10))
        // same day is also a no-op
        let same = FixedClock(year: 2026, month: 7, day: 26, timeZone: T.utc)
        XCTAssertNil(engine.computeCatchUp(state: s, now: same.now,
                                           timeZone: T.utc, undoWindow: 10))
    }

    // §3.4: Timezone change making it "yesterday" locally — no-op; "tomorrow" — catch up.
    func testTimezoneBackwardNoOpForwardCatchesUp() {
        // Instant: 2026-07-27 02:00 UTC. lastProcessed = 07-27 (as seen in UTC).
        let clockUTC = FixedClock(year: 2026, month: 7, day: 27, hour: 2, timeZone: T.utc)
        let s = state(last: T.day(2026, 7, 27))
        // Travel west to Honolulu (-10): locally it's 07-26 16:00 → yesterday → no-op.
        XCTAssertNil(engine.computeCatchUp(state: s, now: clockUTC.now,
                                           timeZone: T.honolulu, undoWindow: 10))

        // Forward: instant 2026-07-26 20:00 UTC, lastProcessed 07-26. Travel east to
        // Tokyo (+9): locally 07-27 05:00 → tomorrow → normal catch-up.
        let clock2 = FixedClock(year: 2026, month: 7, day: 26, hour: 20, timeZone: T.utc)
        let s2 = state(last: T.day(2026, 7, 26))
        let out = engine.computeCatchUp(state: s2, now: clock2.now,
                                        timeZone: T.tokyo, undoWindow: 10)
        XCTAssertEqual(out?.newLastProcessedDay, T.day(2026, 7, 27))
    }

    // §3.4: DST transition — day identity stable across the spring-forward day.
    func testDSTStability() {
        // US spring-forward 2026 is March 8. Day identity must be calendar-based.
        let e = DayEngine(dayStartOffset: 0)
        let mar8 = FixedClock(year: 2026, month: 3, day: 8, hour: 12, timeZone: T.ny)
        let mar9 = FixedClock(year: 2026, month: 3, day: 9, hour: 12, timeZone: T.ny)
        XCTAssertEqual(e.dayKey(for: mar8.now, timeZone: T.ny), T.day(2026, 3, 8))
        XCTAssertEqual(e.dayKey(for: mar9.now, timeZone: T.ny), T.day(2026, 3, 9))
        // A rollover spanning the DST day advances exactly one day.
        let s = state(last: T.day(2026, 3, 8))
        let out = e.computeCatchUp(state: s, now: mar9.now, timeZone: T.ny, undoWindow: 10)
        XCTAssertEqual(out?.newLastProcessedDay, T.day(2026, 3, 9))
    }

    // §3.4: dayStartOffset 03:00 — 1 a.m. counts as the previous logical day.
    func testDayStartOffset0300Semantics() {
        let e = DayEngine(dayStartOffset: 3 * 3600) // 03:00
        // 01:00 on the 27th belongs to logical day 26.
        let oneAM = FixedClock(year: 2026, month: 7, day: 27, hour: 1, timeZone: T.utc)
        XCTAssertEqual(e.dayKey(for: oneAM.now, timeZone: T.utc), T.day(2026, 7, 26))
        // 03:00 exactly starts the new logical day.
        let threeAM = FixedClock(year: 2026, month: 7, day: 27, hour: 3, timeZone: T.utc)
        XCTAssertEqual(e.dayKey(for: threeAM.now, timeZone: T.utc), T.day(2026, 7, 27))
        // 02:59 still previous day.
        let almost = FixedClock(year: 2026, month: 7, day: 27, hour: 2, minute: 59, timeZone: T.utc)
        XCTAssertEqual(e.dayKey(for: almost.now, timeZone: T.utc), T.day(2026, 7, 26))
    }

    // §3.4: Double catch-up is idempotent.
    func testDoubleCatchUpIdempotent() {
        let store = makeStore()
        store.add("carry", to: .today)
        let a = store.add("done today then archived", to: .today)
        store.setDone(a.inserted[0], true) // completed 07-26

        clock.set(year: 2026, month: 7, day: 27, hour: 9)
        let first = store.catchUp()
        XCTAssertFalse(first.isEmpty)
        let afterFirst = store.snapshot
        let second = store.catchUp()
        XCTAssertTrue(second.isEmpty) // second run is a pure no-op
        XCTAssertEqual(store.snapshot, afterFirst)
    }

    // §3.4: Away N days — one pass, true completion day archiving, no empty-day noise.
    func testAwayManyDaysOnePassTrueDayNoNoise() throws {
        let store = makeStore()
        let a = store.add("finish report", to: .today)
        store.setDone(a.inserted[0], true) // completed on 07-26, list becomes empty of open

        // Mac off for 07-27, 07-28; wake on 07-29.
        clock.set(year: 2026, month: 7, day: 29, hour: 8)
        let change = store.catchUp()

        // Archived and removed from live.
        XCTAssertEqual(change.removed, [a.inserted[0]])
        XCTAssertTrue(store.tasks(in: .today).isEmpty)
        XCTAssertEqual(store.lastProcessedDay, T.day(2026, 7, 29))

        // History: task archived under its TRUE completion day (07-26), and exactly
        // one summary (07-26). Empty gap days 07-27/07-28 add no noise.
        let history = Persistence(directory: dir).readHistory()
        let archived = history.compactMap { if case .task(let t) = $0 { return t } else { return nil } }
        XCTAssertEqual(archived.count, 1)
        XCTAssertEqual(archived.first?.archivedDay, T.day(2026, 7, 26))

        let summaries = history.compactMap { if case .summary(let s) = $0 { return s } else { return nil } }
        XCTAssertEqual(summaries.map { $0.day }, [T.day(2026, 7, 26)])
        XCTAssertEqual(summaries.first?.fullyCleared, true)
    }

    // Carried-over (still open) gap days DO get summaries — they are not empty.
    func testGapDaysWithCarriedTaskProduceStillOpenSummaries() {
        let s = state(last: T.day(2026, 7, 26),
                      tasks: [todayTask("carry", added: T.day(2026, 7, 26))])
        let now = FixedClock(year: 2026, month: 7, day: 29, timeZone: T.utc)
        let out = engine.computeCatchUp(state: s, now: now.now, timeZone: T.utc, undoWindow: 10)!
        // 07-26, 07-27, 07-28 each had the open task → three not-cleared summaries.
        XCTAssertEqual(out.summaries.map { $0.day },
                       [T.day(2026, 7, 26), T.day(2026, 7, 27), T.day(2026, 7, 28)])
        XCTAssertTrue(out.summaries.allSatisfy { !$0.fullyCleared && $0.stillOpen == 1 })
    }

    // True-completion-day archiving with the app running across distinct days.
    func testArchivesUnderTrueCompletionDayNotProcessingDay() {
        let store = makeStore()
        let a = store.add("A", to: .today)
        store.setDone(a.inserted[0], true) // completed 07-26

        clock.set(year: 2026, month: 7, day: 27, hour: 10) // move forward, no catchUp
        let b = store.add("B", to: .today)                 // added 07-27
        store.setDone(b.inserted[0], true)                 // completed 07-27

        clock.set(year: 2026, month: 7, day: 28, hour: 9)
        store.catchUp() // processing day is 07-28

        let archived = Persistence(directory: dir).readHistory()
            .compactMap { if case .task(let t) = $0 { return t } else { return nil } }
        let byId = Dictionary(uniqueKeysWithValues: archived.map { ($0.task.id, $0.archivedDay) })
        XCTAssertEqual(byId[a.inserted[0]], T.day(2026, 7, 26)) // true day, not 07-28
        XCTAssertEqual(byId[b.inserted[0]], T.day(2026, 7, 27))
    }

    // §3.4: Asleep-at-midnight equivalence — end state is independent of WHEN on the
    // new day catch-up runs.
    func testAsleepAtMidnightEquivalentToLiveRollover() {
        func run(wakeHour: Int) -> StoreState {
            let d = T.tempDir(); defer { T.cleanup(d) }
            let c = FixedClock(year: 2026, month: 7, day: 26, hour: 12, timeZone: T.utc)
            let store = TaskStore(clock: c, persistence: Persistence(directory: d),
                                  scheduler: ImmediateSaveScheduler())
            let done = store.add("done", to: .today)
            store.setDone(done.inserted[0], true)
            store.add("open", to: .today)
            c.set(year: 2026, month: 7, day: 27, hour: wakeHour)
            store.catchUp()
            return store.snapshot
        }
        // Waking at 00:01 vs 23:59 on the next day yields identical stored state
        // (ids are random per run, so compare structure).
        let early = run(wakeHour: 0)
        let late = run(wakeHour: 23)
        func shape(_ s: StoreState) -> [String] {
            s.tasks.sorted { $0.order < $1.order }.map { "\($0.title):\($0.done):\($0.list.rawValue)" }
        }
        XCTAssertEqual(shape(early), shape(late))
        XCTAssertEqual(early.lastProcessedDay, late.lastProcessedDay)
        XCTAssertEqual(shape(early), ["open:false:today"]) // done archived, open carried
    }

    // §3.4: Deferred (mid-interaction) catch-up run later yields the same end state.
    func testDeferredCatchUpLateRunEquivalence() {
        func run(deferHours: Int) -> StoreState {
            let d = T.tempDir(); defer { T.cleanup(d) }
            let c = FixedClock(year: 2026, month: 7, day: 26, hour: 12, timeZone: T.utc)
            let store = TaskStore(clock: c, persistence: Persistence(directory: d),
                                  scheduler: ImmediateSaveScheduler())
            let x = store.add("done", to: .today)
            store.setDone(x.inserted[0], true)
            store.add("carry", to: .today)
            c.set(year: 2026, month: 7, day: 27, hour: 0, minute: 5)
            c.advance(by: Double(deferHours) * 3600) // "defer" running catchUp
            store.catchUp()
            return store.snapshot
        }
        func shape(_ s: StoreState) -> [String] {
            s.tasks.map { "\($0.title):\($0.done)" }
        }
        // Running catchUp immediately vs 10 hours into the interaction is equivalent.
        XCTAssertEqual(shape(run(deferHours: 0)), shape(run(deferHours: 10)))
        XCTAssertEqual(shape(run(deferHours: 0)), ["carry:false"])
    }

    // §3.4: 11:59 pm complete, 12:01 am uncheck — rollover already ran.
    func testCompleteLateUncheckAfterRolloverIsFinal() {
        let store = makeStore()
        clock.set(year: 2026, month: 7, day: 26, hour: 23, minute: 59)
        let t = store.add("late", to: .today)
        store.setDone(t.inserted[0], true) // completed 07-26 23:59

        clock.set(year: 2026, month: 7, day: 27, hour: 0, minute: 1)
        store.catchUp() // archived — task leaves the live store

        XCTAssertNil(store.task(id: t.inserted[0]))
        XCTAssertTrue(store.setDone(t.inserted[0], false).isEmpty) // uncheck is a no-op
    }

    // §3.4: 11:59 pm complete, 12:01 am uncheck — rollover NOT yet run (deferred).
    func testCompleteLateUncheckBeforeRolloverWorks() {
        let store = makeStore()
        clock.set(year: 2026, month: 7, day: 26, hour: 23, minute: 59)
        let t = store.add("late", to: .today)
        store.setDone(t.inserted[0], true)

        clock.set(year: 2026, month: 7, day: 27, hour: 0, minute: 1)
        // Uncheck BEFORE catchUp runs.
        XCTAssertFalse(store.setDone(t.inserted[0], false).isEmpty)
        store.catchUp() // now open → stays in Today, not archived
        XCTAssertNotNil(store.task(id: t.inserted[0]))
        XCTAssertEqual(store.tasks(in: .today).count, 1)
        XCTAssertFalse(store.task(id: t.inserted[0])!.done)
    }

    // Panel-open-at-midnight (idle): catchUp applies immediately and returns an
    // animatable change set (removed archived + updated carried).
    func testPanelOpenAtMidnightReturnsAnimatableChangeSet() {
        let store = makeStore()
        let done = store.add("done", to: .today)
        store.setDone(done.inserted[0], true)
        let carry = store.add("carry", to: .today)

        clock.set(year: 2026, month: 7, day: 27, hour: 0, minute: 0, second: 1)
        let change = store.catchUp()
        XCTAssertEqual(change.removed, [done.inserted[0]])
        XCTAssertEqual(change.updated, [carry.inserted[0]]) // age ticked
    }

    // Expired soft-delete tombstones are purged during catch-up (§3.2 step 3).
    func testCatchUpPurgesExpiredTombstones() {
        let store = makeStore(undoWindow: 10)
        let t = store.add("temp", to: .today)
        store.delete(t.inserted[0])
        clock.advance(by: 20) // window closed
        clock.set(year: 2026, month: 7, day: 27, hour: 12)
        store.catchUp()
        // Fully gone from persisted state (not just hidden).
        XCTAssertFalse(store.snapshot.tasks.contains { $0.id == t.inserted[0] })
    }
}
