import XCTest
@testable import OrdoCore
@testable import OrdoThemes
@testable import OrdoUI

@MainActor
final class ComposerAndPasteTests: UIModelTestCase {

    // MARK: Composer validation

    func testEmptyComposerRejected() {
        let model = makeModel(store: makeStore())
        XCTAssertFalse(model.canAdd)

        model.composerText = "    \n  "
        XCTAssertFalse(model.canAdd)
        model.submitComposer()
        XCTAssertEqual(model.openToday.count, 0)
        XCTAssertFalse(sounds.played.contains(.add))
    }

    func testTitleCappedAt500() {
        let model = makeModel(store: makeStore())
        model.composerText = String(repeating: "a", count: 600)
        model.submitComposer()

        XCTAssertEqual(model.openToday.count, 1)
        XCTAssertEqual(model.openToday[0].title.count, 500)
    }

    func testCharacterCounterThreshold() {
        let model = makeModel(store: makeStore())

        model.composerText = String(repeating: "a", count: 400)
        XCTAssertFalse(model.showCharacterCounter)

        model.composerText = String(repeating: "a", count: 401)
        XCTAssertTrue(model.showCharacterCounter)
        XCTAssertEqual(model.charactersRemaining, 500 - 401)
    }

    // MARK: Multi-line paste (§4.1)

    func testPasteUpToTwentyAddsDirectly() {
        let model = makeModel(store: makeStore())
        let lines = (1...20).map { "Task \($0)" }.joined(separator: "\n")
        model.composerText = lines
        model.submitComposer()

        XCTAssertNil(model.pendingPaste)
        XCTAssertEqual(model.openToday.count, 20)
        XCTAssertTrue(model.composerText.isEmpty)
    }

    func testPasteBeyondTwentyRequiresConfirm() {
        let model = makeModel(store: makeStore())
        let lines = (1...21).map { "Task \($0)" }.joined(separator: "\n")
        model.composerText = lines
        model.submitComposer()

        // Nothing added yet; a quiet inline confirm is pending.
        XCTAssertEqual(model.openToday.count, 0)
        XCTAssertNotNil(model.pendingPaste)
        XCTAssertEqual(model.pendingPaste?.count, 21)

        model.confirmPendingPaste()
        XCTAssertNil(model.pendingPaste)
        XCTAssertEqual(model.openToday.count, 21)
    }

    func testCancelPendingPasteAddsNothing() {
        let model = makeModel(store: makeStore())
        model.composerText = (1...25).map { "T\($0)" }.joined(separator: "\n")
        model.submitComposer()
        XCTAssertNotNil(model.pendingPaste)

        model.cancelPendingPaste()
        XCTAssertNil(model.pendingPaste)
        XCTAssertEqual(model.openToday.count, 0)
        XCTAssertTrue(model.composerText.isEmpty)
    }

    func testBlankLinesSkippedInPaste() {
        let model = makeModel(store: makeStore())
        model.composerText = "One\n\n  \nTwo\n"
        model.submitComposer()
        XCTAssertEqual(model.openToday.count, 2)
        XCTAssertEqual(model.openToday.map(\.title), ["One", "Two"])
    }
}
