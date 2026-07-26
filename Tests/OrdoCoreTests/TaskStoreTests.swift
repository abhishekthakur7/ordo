import XCTest
@testable import OrdoCore

final class TaskStoreTests: CoreTestCase {

    // MARK: Add

    func testAddTrimsRejectsEmptyAndCaps() {
        let store = makeStore()
        XCTAssertTrue(store.add("   ", to: .today).isEmpty)      // whitespace only
        XCTAssertTrue(store.add("", to: .today).isEmpty)         // empty
        let c = store.add("  hello  ", to: .today)
        XCTAssertEqual(store.task(id: c.inserted[0])?.title, "hello") // trimmed
        let long = String(repeating: "x", count: 700)
        let c2 = store.add(long, to: .today)
        XCTAssertEqual(store.task(id: c2.inserted[0])?.title.count, 500) // capped
    }

    func testAddTodaySetsAddedToTodayOnLongtermDoesNot() {
        let store = makeStore()
        let today = store.add("t", to: .today)
        let long = store.add("l", to: .longterm)
        XCTAssertEqual(store.task(id: today.inserted[0])?.addedToTodayOn, T.day(2026, 7, 26))
        XCTAssertNil(store.task(id: long.inserted[0])?.addedToTodayOn)
    }

    // PLAN §5: batch add ordering — one task per line, appended bottom in order.
    func testBatchAddOrdering() {
        let store = makeStore()
        store.add("existing", to: .today)
        let change = store.addBatch(["first", "second", "third"], to: .today)
        XCTAssertEqual(change.inserted.count, 3)
        let titles = store.tasks(in: .today).map { $0.title }
        XCTAssertEqual(titles, ["existing", "first", "second", "third"])
        // orders strictly increasing in insertion order
        let orders = store.tasks(in: .today).map { $0.order }
        XCTAssertEqual(orders, orders.sorted())
    }

    func testAddLinesSplitsAndSkipsEmpty() {
        let store = makeStore()
        let change = store.addLines("one\n\n  \ntwo\nthree", to: .today)
        XCTAssertEqual(change.inserted.count, 3)
        XCTAssertEqual(store.tasks(in: .today).map { $0.title }, ["one", "two", "three"])
    }

    // MARK: Complete / edit

    func testToggleDoneSetsAndClearsCompletedAt() {
        let store = makeStore()
        let t = store.add("x", to: .today).inserted[0]
        XCTAssertFalse(store.toggleDone(t).isEmpty)
        XCTAssertNotNil(store.task(id: t)?.completedAt)
        XCTAssertTrue(store.task(id: t)!.done)
        store.toggleDone(t) // uncheck while live
        XCTAssertNil(store.task(id: t)?.completedAt)
        XCTAssertFalse(store.task(id: t)!.done)
    }

    func testEditTitleEmptyCommitIsNoOpNotDelete() {
        let store = makeStore()
        let t = store.add("keep", to: .today).inserted[0]
        XCTAssertTrue(store.editTitle(t, to: "   ").isEmpty) // empty commit
        XCTAssertEqual(store.task(id: t)?.title, "keep")     // still there, unchanged
        XCTAssertFalse(store.editTitle(t, to: "changed").isEmpty)
        XCTAssertEqual(store.task(id: t)?.title, "changed")
    }

    // MARK: Soft delete / undo / purge

    func testSoftDeleteHidesUndoRestoresWithinWindow() {
        let store = makeStore(undoWindow: 10)
        let t = store.add("gone", to: .today).inserted[0]
        XCTAssertEqual(store.delete(t).removed, [t])
        XCTAssertNil(store.task(id: t))                 // hidden immediately
        XCTAssertTrue(store.snapshot.tasks.contains { $0.id == t }) // tombstone persists
        clock.advance(by: 5)
        XCTAssertEqual(store.undoDelete(t).inserted, [t]) // within window
        XCTAssertNotNil(store.task(id: t))
    }

    func testUndoAfterWindowFails() {
        let store = makeStore(undoWindow: 10)
        let t = store.add("gone", to: .today).inserted[0]
        store.delete(t)
        clock.advance(by: 15) // window closed
        XCTAssertTrue(store.undoDelete(t).isEmpty)
    }

    func testExpiredTombstonePurgedAtNextSave() {
        let store = makeStore(undoWindow: 10)
        let t = store.add("gone", to: .today).inserted[0]
        store.delete(t)
        clock.advance(by: 15)
        store.flush() // first save after window closes → purge
        XCTAssertFalse(store.snapshot.tasks.contains { $0.id == t })
    }

    func testTombstoneNotPurgedBeforeWindow() {
        let store = makeStore(undoWindow: 10)
        let t = store.add("gone", to: .today).inserted[0]
        store.delete(t)
        clock.advance(by: 3)
        store.flush()
        XCTAssertTrue(store.snapshot.tasks.contains { $0.id == t }) // still recoverable
    }

    // MARK: Reorder

    func testMoveReordersWithinList() {
        let store = makeStore()
        let a = store.add("a", to: .today).inserted[0]
        let b = store.add("b", to: .today).inserted[0]
        let c = store.add("c", to: .today).inserted[0]
        // move c to the front
        XCTAssertEqual(store.move(c, toIndex: 0).moved, [c])
        XCTAssertEqual(store.tasks(in: .today).map { $0.id }, [c, a, b])
        // move a to the end
        store.move(a, toIndex: 2)
        XCTAssertEqual(store.tasks(in: .today).map { $0.id }, [c, b, a])
    }

    // PLAN §5: fractional-order renormalization when gaps get tight.
    func testOrderRenormalizationWhenGapsCollapse() {
        let store = makeStore()
        store.add("lo", to: .today)
        store.add("hi", to: .today)
        // Repeatedly drop a fresh task into index 1: its neighbors become `lo` and the
        // previous insert, so the gap halves each time until it collapses below
        // minOrderGap and forces a renormalization.
        var renormalized = false
        var iterations = 0
        for _ in 0..<100 {
            iterations += 1
            let n = store.add("n", to: .today).inserted[0]
            let cs = store.move(n, toIndex: 1)
            if !cs.updated.isEmpty { renormalized = true; break } // renorm touches siblings
        }
        XCTAssertTrue(renormalized, "expected a renormalization once the gap collapsed")
        XCTAssertLessThan(iterations, 60) // collapses quickly (doubles precision each step)
        // Order is still valid and well-spaced afterwards.
        let orders = store.tasks(in: .today).map { $0.order }
        XCTAssertEqual(orders, orders.sorted())
        for i in 1..<orders.count {
            XCTAssertGreaterThanOrEqual(orders[i] - orders[i-1], TaskStore.minOrderGap)
        }
        // `lo` stays first, `hi` still present — no tasks lost during renormalization.
        XCTAssertEqual(store.tasks(in: .today).first?.title, "lo")
        XCTAssertTrue(store.tasks(in: .today).contains { $0.title == "hi" })
    }

    // MARK: Promote / demote

    // PLAN §5: promote/demote preserves identity (id + createdAt).
    func testPromotePreservesIdentityAndSetsAddedToday() {
        let store = makeStore()
        let l = store.add("goal", to: .longterm).inserted[0]
        let createdAt = store.task(id: l)!.createdAt
        store.promote(l)
        let t = store.task(id: l)!
        XCTAssertEqual(t.id, l)                       // same identity
        XCTAssertEqual(t.createdAt, createdAt)        // createdAt preserved
        XCTAssertEqual(t.list, .today)
        XCTAssertEqual(t.addedToTodayOn, T.day(2026, 7, 26))
        XCTAssertEqual(store.tasks(in: .today).map { $0.id }, [l])
        XCTAssertTrue(store.tasks(in: .longterm).isEmpty)
    }

    func testDemotePreservesIdentityAndClearsAddedToday() {
        let store = makeStore()
        let t = store.add("task", to: .today).inserted[0]
        let createdAt = store.task(id: t)!.createdAt
        store.demote(t)
        let d = store.task(id: t)!
        XCTAssertEqual(d.id, t)
        XCTAssertEqual(d.createdAt, createdAt)
        XCTAssertEqual(d.list, .longterm)
        XCTAssertNil(d.addedToTodayOn)
    }

    // MARK: Age & triage (§3.5)

    func testAgeIsDerivedFromAddedToTodayOn() {
        let store = makeStore()
        let t = store.add("x", to: .today).inserted[0]
        XCTAssertEqual(store.age(of: store.task(id: t)!), 0)
        clock.set(year: 2026, month: 7, day: 29) // +3 days
        XCTAssertEqual(store.age(of: store.task(id: t)!), 3)
        // longterm has no age
        let l = store.add("l", to: .longterm).inserted[0]
        XCTAssertNil(store.age(of: store.task(id: l)!))
    }

    func testTriageEntersAt7DaysAndKeepSnoozesWithoutResettingAge() {
        let store = makeStore()
        let t = store.add("old", to: .today).inserted[0]
        XCTAssertFalse(store.isInTriage(store.task(id: t)!)) // age 0

        clock.set(year: 2026, month: 8, day: 2) // age 7
        XCTAssertTrue(store.isInTriage(store.task(id: t)!))

        // "Keep" snoozes the nudge but does NOT reset age.
        store.keepInTriage(t)
        XCTAssertEqual(store.age(of: store.task(id: t)!), 7) // age unchanged
        XCTAssertFalse(store.isInTriage(store.task(id: t)!)) // snoozed

        clock.set(year: 2026, month: 8, day: 8) // 6 days after keep → still snoozed
        XCTAssertFalse(store.isInTriage(store.task(id: t)!))
        clock.set(year: 2026, month: 8, day: 9) // 7 days after keep → nudge returns
        XCTAssertTrue(store.isInTriage(store.task(id: t)!))
        XCTAssertEqual(store.age(of: store.task(id: t)!), 14) // age kept climbing
    }

    // MARK: dayStartOffset persistence

    func testSetDayStartOffsetPersistsAndAffectsDayIdentity() {
        let store = makeStore()
        clock.set(year: 2026, month: 7, day: 27, hour: 1) // 01:00
        XCTAssertEqual(store.currentDayKey(), T.day(2026, 7, 27))
        store.setDayStartOffset(3 * 3600) // 03:00 semantics
        XCTAssertEqual(store.currentDayKey(), T.day(2026, 7, 26)) // 01:00 → prev day
        // Persisted in store.json (not UserDefaults).
        let reopened = makeStore()
        XCTAssertEqual(reopened.dayStartOffset, 3 * 3600)
    }

    // MARK: Queries sorted by order

    func testTasksSortedByOrder() {
        let store = makeStore()
        let a = store.add("a", to: .today).inserted[0]
        let b = store.add("b", to: .today).inserted[0]
        store.move(b, toIndex: 0)
        XCTAssertEqual(store.tasks(in: .today).map { $0.id }, [b, a])
    }
}
