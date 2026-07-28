import XCTest
@testable import OrdoCore
@testable import OrdoThemes
@testable import OrdoUI

@MainActor
final class UndoToastTests: UIModelTestCase {

    func testDefaultToastWindowIsThreeSeconds() throws {
        let model = AppModel(store: makeStore(undoWindow: 3),
                             clock: clock,
                             theme: MacOSTheme(),
                             settings: settings,
                             sounds: sounds,
                             scheduler: scheduler)
        model.composerText = "Delete me"; model.submitComposer()

        model.delete(try XCTUnwrap(model.openToday.first?.id))

        XCTAssertEqual(try XCTUnwrap(model.undoToast).expiresAt.timeIntervalSince(clock.now),
                       3,
                       accuracy: 0.001)
    }

    func testToastPersistsBeforeExpiry() {
        let model = makeModel(store: makeStore(undoWindow: 10), undoWindow: 10)
        model.composerText = "Delete me"; model.submitComposer()
        let id = model.openToday[0].id

        model.delete(id)
        XCTAssertNotNil(model.undoToast)

        // Scheduler fires but the clock has not advanced past the window → toast stays.
        scheduler.fireAll()
        XCTAssertNotNil(model.undoToast, "toast should remain until the clock passes expiry")
    }

    func testToastExpiresViaClock() {
        let model = makeModel(store: makeStore(undoWindow: 10), undoWindow: 10)
        model.composerText = "Delete me"; model.submitComposer()
        let id = model.openToday[0].id

        model.delete(id)
        XCTAssertNotNil(model.undoToast)

        // Advance the clock past the undo window, then let the scheduled work run.
        clock.advance(by: 11)
        scheduler.fireAll()
        XCTAssertNil(model.undoToast, "toast expires once the clock passes its deadline")
    }

    func testUndoWithinWindowRestoresTask() {
        let model = makeModel(store: makeStore(undoWindow: 10), undoWindow: 10)
        model.composerText = "Delete me"; model.submitComposer()
        let id = model.openToday[0].id

        model.delete(id)
        XCTAssertEqual(model.openToday.count, 0)

        clock.advance(by: 5) // still within window
        model.undoDelete()
        XCTAssertNil(model.undoToast)
        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertEqual(model.openToday[0].id, id)
    }

    func testExpiredToastFiringIsNoOpAfterUndo() {
        let model = makeModel(store: makeStore(undoWindow: 10), undoWindow: 10)
        model.composerText = "Delete me"; model.submitComposer()
        let id = model.openToday[0].id

        model.delete(id)
        model.undoDelete() // toast already gone
        // The still-queued expiry work must not clobber a restored task.
        clock.advance(by: 11)
        scheduler.fireAll()
        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertNil(model.undoToast)
    }

    func testClosingPanelDismissesToastImmediately() {
        let model = makeModel(store: makeStore(undoWindow: 10), undoWindow: 10)
        model.composerText = "Delete me"; model.submitComposer()
        model.delete(model.openToday[0].id)
        XCTAssertNotNil(model.undoToast)

        model.panelDidClose()

        XCTAssertNil(model.undoToast)
    }
}
