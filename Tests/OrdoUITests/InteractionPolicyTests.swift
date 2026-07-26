import XCTest
@testable import OrdoCore
@testable import OrdoThemes
@testable import OrdoUI

/// A PanelChrome spy recording notifyInteraction transitions.
@MainActor
final class SpyChrome: PanelChrome {
    private(set) var holdHistory: [Bool] = []
    var lastHold: Bool? { holdHistory.last }
    func requestClose() {}
    func setExpanded(_ expanded: Bool) {}
    func notifyInteraction(active: Bool) { holdHistory.append(active) }
}

@MainActor
final class InteractionPolicyTests: UIModelTestCase {

    /// A store on day 25 with one Today task completed that day, clock advanced to
    /// day 26 so a pending rollover would archive it.
    private func storeWithArchivablyDoneTask() -> TaskStore {
        clock.set(year: 2026, month: 7, day: 25, hour: 12)
        let s = TaskStore(clock: clock,
                          persistence: Persistence(directory: dir),
                          scheduler: ImmediateSaveScheduler(),
                          undoWindow: 10)
        let id = s.add("Yesterday task", to: .today).inserted[0]
        s.setDone(id, true)
        s.flush()
        clock.set(year: 2026, month: 7, day: 26, hour: 9)
        return s
    }

    // MARK: FINDING 4(a) — composer draft preserved across close/reopen

    func testComposerDraftSurvivesCloseAndReopen() {
        let model = makeModel(store: makeStore())
        model.composerText = "half-typed thought"

        model.panelDidClose()
        XCTAssertEqual(model.composerText, "half-typed thought", "draft survives close")

        model.panelWillOpen()
        XCTAssertEqual(model.composerText, "half-typed thought", "draft survives reopen (§4.1)")
    }

    // MARK: FINDING 4(b) — panel close commits a non-empty edit, cancels an empty one

    func testPanelCloseCommitsActiveEdit() {
        let store = makeStore()
        let model = makeModel(store: store)
        model.composerText = "Task"; model.submitComposer()
        let id = model.openToday[0].id

        model.beginEditing(id)
        model.editingText = "Edited on close"
        model.panelDidClose()

        XCTAssertNil(model.editingTaskID)
        XCTAssertEqual(store.task(id: id)?.title, "Edited on close", "blur commits on close (§4.1)")
    }

    func testPanelCloseCancelsEmptyEdit() {
        let store = makeStore()
        let model = makeModel(store: store)
        model.composerText = "Keep me"; model.submitComposer()
        let id = model.openToday[0].id

        model.beginEditing(id)
        model.editingText = "   "
        model.panelDidClose()

        XCTAssertNil(model.editingTaskID)
        XCTAssertEqual(store.task(id: id)?.title, "Keep me", "empty commit cancels — never deletes")
    }

    // MARK: FINDING 4(c) — interactionActive transitions drive the chrome (drag-only hold)

    func testDragHoldsClickOutsideViaChrome() {
        let model = makeModel(store: makeStore())
        let spy = SpyChrome()
        model.chrome = spy

        // Typing does NOT hold dismissal (draft is safe across close).
        model.composerText = "typing"
        XCTAssertNil(spy.lastHold, "typing must not hold click-outside")

        // A drag holds…
        model.isDragging = true
        XCTAssertEqual(spy.lastHold, true)

        // …and releases.
        model.isDragging = false
        XCTAssertEqual(spy.lastHold, false)
    }

    // MARK: FINDING 5 — a stuck drag flag must always reset and drain deferred work

    func testDragResetDrainsDeferredWork() {
        let model = makeModel(store: storeWithArchivablyDoneTask())
        XCTAssertEqual(model.doneToday.count, 1)

        model.isDragging = true
        model.requestRollover()
        XCTAssertEqual(model.doneToday.count, 1, "deferred while dragging")

        model.isDragging = false // the reset path clears interaction…
        XCTAssertEqual(model.doneToday.count, 0, "…and drains the deferred rollover")
    }

    func testPanelWillOpenResetsStuckDragAndDrains() {
        let model = makeModel(store: storeWithArchivablyDoneTask())
        model.isDragging = true
        model.requestRollover()
        XCTAssertEqual(model.doneToday.count, 1)

        // A drag that never received a drop leaves isDragging true; reopening clears it.
        model.panelWillOpen()
        XCTAssertFalse(model.isDragging)
        XCTAssertEqual(model.doneToday.count, 0)
    }

    // MARK: FINDING 6 — reorder index math is correct in BOTH directions

    private func fourTasks(_ model: AppModel) -> [UUID] {
        for t in ["A", "B", "C", "D"] { model.composerText = t; model.submitComposer() }
        return model.openToday.map(\.id)
    }

    func testReorderDownwardLandsAtTargetSlot() {
        let model = makeModel(store: makeStore())
        let ids = fourTasks(model) // [A,B,C,D]
        // Drag A (first) down onto C (third).
        let toIndex = AppModel.reorderIndex(orderedIDs: ids, dragging: ids[0], target: ids[2])
        XCTAssertEqual(toIndex, 1) // siblings-relative, not full-list index (was 2 → off-by-one)
        model.move(ids[0], toIndex: toIndex!)
        XCTAssertEqual(model.openToday.map(\.title), ["B", "A", "C", "D"])
    }

    func testReorderUpwardLandsAtTargetSlot() {
        let model = makeModel(store: makeStore())
        let ids = fourTasks(model) // [A,B,C,D]
        // Drag D (last) up onto B (second).
        let toIndex = AppModel.reorderIndex(orderedIDs: ids, dragging: ids[3], target: ids[1])
        XCTAssertEqual(toIndex, 1)
        model.move(ids[3], toIndex: toIndex!)
        XCTAssertEqual(model.openToday.map(\.title), ["A", "D", "B", "C"])
    }

    func testReorderMissingIDsReturnNil() {
        let a = UUID(), b = UUID()
        XCTAssertNil(AppModel.reorderIndex(orderedIDs: [a], dragging: a, target: b))
        XCTAssertNil(AppModel.reorderIndex(orderedIDs: [a, b], dragging: UUID(), target: b))
    }
}
