import XCTest
@testable import OrdoCore
@testable import OrdoThemes
@testable import OrdoUI

@MainActor
final class LifecycleAndDeferTests: UIModelTestCase {

    /// Build a store on day 25 with one Today task completed that day, then advance
    /// the clock to day 26 so a pending rollover would archive it. The store's
    /// `lastProcessedDay` is day 25 (fresh dir → first launch at the day-25 clock).
    private func storeWithArchivablyDoneTask() -> (TaskStore, UUID) {
        clock.set(year: 2026, month: 7, day: 25, hour: 12)
        let s = TaskStore(clock: clock,
                          persistence: Persistence(directory: dir),
                          scheduler: ImmediateSaveScheduler(),
                          undoWindow: 10)
        let cs = s.add("Yesterday task", to: .today)
        let id = cs.inserted[0]
        s.setDone(id, true)
        s.flush()
        clock.set(year: 2026, month: 7, day: 26, hour: 9)
        return (s, id)
    }

    func testPanelOpenResetsToTodayAndRunsCatchUp() {
        let (store, _) = storeWithArchivablyDoneTask()
        let model = makeModel(store: store)
        model.selectTab(.longterm)
        XCTAssertEqual(model.tab, .longterm)
        // Before open: the done task is still live (catchUp not run).
        XCTAssertEqual(model.doneToday.count, 1)

        model.panelWillOpen()

        XCTAssertEqual(model.tab, .today, "panel always opens on Today (§4.1)")
        XCTAssertEqual(model.doneToday.count, 0, "catchUp archived the done task")
    }

    func testRolloverDeferredDuringInteractionRunsAfterItEnds() {
        let (store, _) = storeWithArchivablyDoneTask()
        let model = makeModel(store: store)
        XCTAssertEqual(model.doneToday.count, 1)

        // Begin interacting (typing a non-empty composer).
        model.composerText = "typing something"
        XCTAssertTrue(model.interactionActive)

        model.requestRollover()
        // Deferred: nothing archived while the user is interacting.
        XCTAssertEqual(model.doneToday.count, 1)

        // Interaction ends → the deferred rollover runs.
        model.composerText = ""
        XCTAssertFalse(model.interactionActive)
        XCTAssertEqual(model.doneToday.count, 0)
    }

    func testDeferredRolloverRunsOnPanelClose() {
        let (store, _) = storeWithArchivablyDoneTask()
        let model = makeModel(store: store)

        model.isDragging = true
        model.requestRollover()
        XCTAssertEqual(model.doneToday.count, 1, "deferred while dragging")

        // Closing the panel drains deferred work (and flushes).
        model.isDragging = false // clears interaction but keep testing close-drain too
        // Re-arm a deferred request while interacting, then close.
        model.isDragging = true
        model.requestRollover()
        model.panelDidClose()
        XCTAssertEqual(model.doneToday.count, 0)
    }

    func testExternalReloadDeferredDuringEdit() {
        let store = makeStore()
        let model = makeModel(store: store)
        model.composerText = "A"; model.submitComposer()
        let id = model.openToday[0].id

        model.beginEditing(id)
        XCTAssertTrue(model.interactionActive)
        model.requestExternalReload() // queued, must not crash / reload mid-edit
        model.cancelEditing()
        XCTAssertFalse(model.interactionActive)
        // Reload of unchanged store leaves the task intact.
        XCTAssertEqual(model.openToday.count, 1)
    }
}
