import XCTest
import SwiftUI
@testable import OrdoCore
@testable import OrdoThemes
@testable import OrdoUI

@MainActor
final class AppearanceAndSelectionTests: UIModelTestCase {

    // MARK: Appearance resolution (pure function, task item 12)

    func testAppearanceResolution() {
        XCTAssertEqual(resolveAppearance(.system, systemIsDark: true), .dark)
        XCTAssertEqual(resolveAppearance(.system, systemIsDark: false), .light)
        XCTAssertEqual(resolveAppearance(.light, systemIsDark: true), .light)
        XCTAssertEqual(resolveAppearance(.light, systemIsDark: false), .light)
        XCTAssertEqual(resolveAppearance(.dark, systemIsDark: false), .dark)
        XCTAssertEqual(resolveAppearance(.dark, systemIsDark: true), .dark)
    }

    func testResolvedAppearanceMappings() {
        XCTAssertEqual(ResolvedUIAppearance.dark.colorScheme, .dark)
        XCTAssertEqual(ResolvedUIAppearance.light.colorScheme, .light)
        XCTAssertEqual(ResolvedUIAppearance.dark.themeAppearance, .dark)
        XCTAssertEqual(ResolvedUIAppearance.light.themeAppearance, .light)
    }

    // MARK: Selection keyboard movement model (§4.4)

    func testSelectionMovesThroughVisibleList() {
        let model = makeModel(store: makeStore())
        for t in ["A", "B", "C"] { model.composerText = t; model.submitComposer() }
        let ids = model.openToday.map(\.id)
        XCTAssertNil(model.selectedID)

        model.moveSelection(.down)
        XCTAssertEqual(model.selectedID, ids[0])
        model.moveSelection(.down)
        XCTAssertEqual(model.selectedID, ids[1])
        model.moveSelection(.down)
        XCTAssertEqual(model.selectedID, ids[2])
        // Clamps at the bottom.
        model.moveSelection(.down)
        XCTAssertEqual(model.selectedID, ids[2])

        model.moveSelection(.up)
        XCTAssertEqual(model.selectedID, ids[1])
    }

    func testSelectionSpansOpenThenDoneSection() {
        let model = makeModel(store: makeStore())
        for t in ["A", "B"] { model.composerText = t; model.submitComposer() }
        let aID = model.openToday[0].id
        let bID = model.openToday[1].id
        // Complete A → it moves to the done section (below B).
        model.toggle(aID); scheduler.fireAll()
        XCTAssertEqual(model.openToday.map(\.id), [bID])
        XCTAssertEqual(model.doneToday.map(\.id), [aID])

        // Down from nil selects first open (B), then wraps into the done section (A).
        model.moveSelection(.down)
        XCTAssertEqual(model.selectedID, bID)
        model.moveSelection(.down)
        XCTAssertEqual(model.selectedID, aID)
    }

    func testTabSwitchClearsSelection() {
        let model = makeModel(store: makeStore())
        model.composerText = "A"; model.submitComposer()
        model.moveSelection(.down)
        XCTAssertNotNil(model.selectedID)
        model.selectTab(.longterm)
        XCTAssertNil(model.selectedID)
    }
}
