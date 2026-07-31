import XCTest
@testable import OrdoCore
@testable import OrdoThemes
@testable import OrdoUI

@MainActor
final class AppModelTests: UIModelTestCase {

    // MARK: Diff path — add / toggle / delete / undo / promote

    func testAddReflectedInOpenRows() {
        let model = makeModel(store: makeStore())
        model.composerText = "Buy milk"
        model.submitComposer()

        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertEqual(model.openToday.first?.title, "Buy milk")
        XCTAssertTrue(model.composerText.isEmpty)
        XCTAssertTrue(sounds.played.contains(.add))
    }

    func testToggleReflowsToDoneSection() {
        let model = makeModel(store: makeStore())
        model.composerText = "Task"
        model.submitComposer()
        let id = model.openToday[0].id

        model.toggle(id)
        // Phase 1: flipped in place, still in the open section, checkbox done.
        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertTrue(model.openToday[0].done)
        XCTAssertTrue(sounds.played.contains(.complete))

        // Phase 2: the reflow runs and the row travels to the done section.
        scheduler.fireAll()
        XCTAssertEqual(model.openToday.count, 0)
        XCTAssertEqual(model.doneToday.count, 1)
        XCTAssertEqual(model.doneToday[0].id, id)
    }

    func testUncheckReturnsToOpen() {
        let store = makeStore()
        let model = makeModel(store: store)
        model.composerText = "Task"
        model.submitComposer()
        let id = model.openToday[0].id
        model.toggle(id); scheduler.fireAll()
        XCTAssertEqual(model.doneToday.count, 1)

        model.toggle(id)
        XCTAssertTrue(sounds.played.contains(.uncheck))
        scheduler.fireAll()
        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertEqual(model.doneToday.count, 0)
    }

    func testZenPathCompletionMovesTaskBelowIncompleteRowsImmediately() {
        let store = makeStore()
        let model = makeZenModel(store: store)
        model.selectTab(.longterm)
        model.composerText = "First"; model.submitComposer()
        model.composerText = "Second"; model.submitComposer()
        model.composerText = "Third"; model.submitComposer()

        let canonicalIDs = store.tasks(in: .longterm).map(\.id)
        let targetID = canonicalIDs[1]

        model.toggle(targetID)

        XCTAssertEqual(model.longtermRemaining, 2)
        XCTAssertEqual(model.allRows.map(\.id), [canonicalIDs[0], canonicalIDs[2], targetID])
        XCTAssertEqual(model.allRows.map(\.done), [false, false, true])
    }

    func testZenPathUncheckUpdatesFlatRowsImmediately() {
        let store = makeStore()
        let model = makeZenModel(store: store)
        model.selectTab(.longterm)
        model.composerText = "First"; model.submitComposer()
        model.composerText = "Second"; model.submitComposer()
        model.composerText = "Third"; model.submitComposer()

        let canonicalIDs = store.tasks(in: .longterm).map(\.id)
        let targetID = canonicalIDs[1]
        model.toggle(targetID)

        model.toggle(targetID)

        XCTAssertEqual(model.longtermRemaining, 3)
        XCTAssertEqual(model.allRows.map(\.id), canonicalIDs)
        XCTAssertEqual(model.allRows.firstIndex(where: { $0.id == targetID }), 1)
        XCTAssertFalse(model.allRows[1].done)
    }

    func testZenTodayFlatRowsKeepIncompleteTasksBeforeCompletedTasks() {
        let store = makeStore()
        let model = makeZenModel(store: store)
        model.composerText = "First"; model.submitComposer()
        model.composerText = "Second"; model.submitComposer()
        model.composerText = "Third"; model.submitComposer()

        let canonicalIDs = store.tasks(in: .today).map(\.id)
        let firstID = canonicalIDs[0]
        let thirdID = canonicalIDs[2]
        model.toggle(firstID)
        model.toggle(thirdID)

        XCTAssertEqual(model.allRows.map(\.id), [canonicalIDs[1], firstID, thirdID])
        XCTAssertEqual(model.allRows.map(\.done), [false, true, true])

        model.toggle(firstID)

        XCTAssertEqual(model.allRows.map(\.id), [firstID, canonicalIDs[1], thirdID])
        XCTAssertEqual(model.allRows.map(\.done), [false, false, true])
    }

    func testZenKeepsEveryRowVisibleWhenAllTasksAreCompleted() {
        let store = makeStore()
        let model = makeZenModel(store: store)
        model.composerText = "First"; model.submitComposer()
        model.composerText = "Second"; model.submitComposer()

        let ids = model.allRows.map(\.id)
        ids.forEach(model.toggle)

        XCTAssertTrue(model.isAllClearedToday)
        XCTAssertEqual(model.allRows.map(\.id), ids)
        XCTAssertTrue(model.allRows.allSatisfy(\.done))
    }

    func testDeleteAndUndoReflectedInRows() {
        let model = makeModel(store: makeStore())
        model.composerText = "Delete me"
        model.submitComposer()
        let id = model.openToday[0].id

        model.delete(id)
        XCTAssertEqual(model.openToday.count, 0)
        XCTAssertNotNil(model.undoToast)
        XCTAssertEqual(model.undoToast?.taskID, id)

        model.undoDelete()
        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertEqual(model.openToday[0].id, id)
        XCTAssertNil(model.undoToast)
    }

    func testPromoteMovesLongtermToToday() {
        let model = makeModel(store: makeStore())
        model.selectTab(.longterm)
        model.composerText = "Ship v1"
        model.submitComposer()
        let id = model.openLongterm[0].id

        model.promote(id)
        XCTAssertEqual(model.openLongterm.count, 0)
        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertEqual(model.openToday[0].id, id)
    }

    func testDemoteMovesTodayToLongterm() {
        let model = makeModel(store: makeStore())
        model.composerText = "Someday"
        model.submitComposer()
        let id = model.openToday[0].id

        model.demote(id)
        XCTAssertEqual(model.openToday.count, 0)
        XCTAssertEqual(model.openLongterm.count, 1)
        XCTAssertEqual(model.openLongterm[0].id, id)
    }

    func testHorizonPinsLeadWithinTheirExistingSectionsAcrossThemes() {
        let themes: [any Theme] = [MacOSTheme(), ArcadeTheme(), ZenInkTheme()]

        for theme in themes {
            let themeDir = UT.tempDir()
            defer { UT.cleanup(themeDir) }
            let themeScheduler = ManualUIScheduler()
            let store = TaskStore(clock: clock,
                                  persistence: Persistence(directory: themeDir),
                                  scheduler: ImmediateSaveScheduler())
            let model = AppModel(store: store,
                                 clock: clock,
                                 theme: theme,
                                 settings: settings,
                                 sounds: sounds,
                                 scheduler: themeScheduler)
            model.selectTab(.longterm)
            ["First", "Second", "Third", "Fourth"].forEach {
                model.composerText = $0
                model.submitComposer()
            }
            let ids = model.openLongterm.map(\.id)

            model.togglePinned(ids[1])
            model.togglePinned(ids[3])
            XCTAssertEqual(model.openLongterm.map(\.id), [ids[1], ids[3], ids[0], ids[2]], "\(theme.displayName) open section")

            model.toggle(ids[0])
            model.toggle(ids[2])
            themeScheduler.fireAll()
            model.togglePinned(ids[2])

            XCTAssertEqual(model.openLongterm.map(\.id), [ids[1], ids[3]], "\(theme.displayName) open section after completion")
            XCTAssertEqual(model.doneLongterm.map(\.id), [ids[2], ids[0]], "\(theme.displayName) completed section")
        }
    }

    func testPinRebuildsTodayRowsAheadOfUnpinnedTasks() {
        let model = makeModel(store: makeStore())
        model.composerText = "First"; model.submitComposer()
        model.composerText = "Second"; model.submitComposer()
        let first = model.openToday[0].id
        let second = model.openToday[1].id

        model.togglePinned(second)

        XCTAssertEqual(model.openToday.map(\.id), [second, first])
        XCTAssertTrue(model.openToday[0].pinned)

        model.togglePinned(second)
        XCTAssertEqual(model.openToday.map(\.id), [first, second])
    }

    // MARK: Tab badges

    func testRemainingCountsPerTab() {
        let model = makeModel(store: makeStore())
        model.composerText = "A"; model.submitComposer()
        model.composerText = "B"; model.submitComposer()
        model.selectTab(.longterm)
        model.composerText = "C"; model.submitComposer()

        XCTAssertEqual(model.todayRemaining, 2)
        XCTAssertEqual(model.longtermRemaining, 1)
        XCTAssertTrue(sounds.played.contains(.tabSwitch))
    }

    // MARK: Cleared-state peek

    func testClearedPeekDefaultsFalseAndResetsOnPanelOpenAndTabSelection() {
        let model = makeModel(store: makeStore())
        XCTAssertFalse(model.clearedPeek)

        model.clearedPeek = true
        model.panelWillOpen()
        XCTAssertFalse(model.clearedPeek)

        model.clearedPeek = true
        model.selectTab(.longterm)
        XCTAssertFalse(model.clearedPeek)
    }

    func testClearedPeekResetsAfterSuccessfulComposerSubmission() {
        let model = makeModel(store: makeStore())
        model.clearedPeek = true
        model.composerText = "A fresh task"

        model.submitComposer()

        XCTAssertFalse(model.clearedPeek)
        XCTAssertEqual(model.openToday.map(\.title), ["A fresh task"])
    }

    func testClearedPeekResetsForBothCompletionDirections() {
        let model = makeModel(store: makeStore())
        model.composerText = "Task"
        model.submitComposer()
        let id = try! XCTUnwrap(model.openToday.first?.id)

        model.clearedPeek = true
        model.toggle(id)
        XCTAssertFalse(model.clearedPeek)
        scheduler.fireAll()
        XCTAssertTrue(model.isAllClearedToday)

        // A fixture may set the transient flag directly after seeding an
        // all-cleared store; unchecking must invalidate that snapshot as well.
        model.clearedPeek = true
        model.toggle(id)
        XCTAssertFalse(model.clearedPeek)
        scheduler.fireAll()
        XCTAssertFalse(model.isAllClearedToday)
    }

    private func makeZenModel(store: TaskStore) -> AppModel {
        AppModel(store: store,
                 clock: clock,
                 theme: ZenInkTheme(),
                 settings: settings,
                 sounds: sounds,
                 scheduler: scheduler)
    }
}
