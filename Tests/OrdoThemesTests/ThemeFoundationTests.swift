import XCTest
import SwiftUI
import OrdoCore
@testable import OrdoThemes

final class ThemeFoundationTests: XCTestCase {
    private let macTheme = MacOSTheme()
    private let arcadeTheme = ArcadeTheme()

    func testPaperStyleHasValueSemantics() {
        let grain = GrainStyle(opacity: 0.045, blend: .multiply, tile: 170)
        let paper = PaperStyle(
            fillTop: .white,
            fillBottom: .black,
            border: .gray,
            borderWidth: 1,
            cornerRadius: 22,
            innerHighlight: .white.opacity(0.6),
            shadow: [ShadowLayer(color: .black.opacity(0.2), x: 0, y: 24, blur: 60)],
            grain: grain
        )
        var copy = paper
        copy.grain.opacity = 0.05
        copy.shadow[0].blur = 70

        XCTAssertEqual(paper.grain.opacity, 0.045, accuracy: 0.0001)
        XCTAssertEqual(paper.shadow[0].blur, 60, accuracy: 0.0001)
        XCTAssertEqual(paper.beakCornerRadius, 0, accuracy: 0.0001)
        XCTAssertNotEqual(paper, copy)
        XCTAssertEqual(SurfaceStyle.paper(paper), .paper(paper))
    }

    func testPaperAndOverlayDescriptorsExposeBothBlendModes() {
        XCTAssertEqual(GrainStyle.Blend.multiply, .multiply)
        XCTAssertEqual(GrainStyle.Blend.overlay, .overlay)
        XCTAssertEqual(OverlayStyle.Kind.paperGrain, .paperGrain)
    }

    func testCapabilityEnumDefaultsPreserveMacOSAndArcadeBranches() {
        XCTAssertEqual(macTheme.composerStyle, .card)
        XCTAssertEqual(macTheme.appearanceSegmentStyle, .iconAndLabel)
        XCTAssertEqual(macTheme.soundControlStyle, .switchTrack)
        XCTAssertEqual(macTheme.tabIndicatorStyle, .thumb)

        XCTAssertEqual(arcadeTheme.composerStyle, .cabinet)
        XCTAssertEqual(arcadeTheme.appearanceSegmentStyle, .iconOnly)
        XCTAssertEqual(arcadeTheme.soundControlStyle, .cabinetSwitch)
        XCTAssertEqual(arcadeTheme.tabIndicatorStyle, .thumb)
    }

    func testNewStructuralDefaultsLeaveShippedThemesUnchanged() {
        for theme in [macTheme as any Theme, arcadeTheme as any Theme] {
            XCTAssertFalse(theme.clearedStateIsPeekable)
            XCTAssertFalse(theme.mainColumnFlexes)
            XCTAssertNil(theme.headerAccessory())
            XCTAssertNil(theme.headerTrailingAccessory(done: 2, total: 5, expanded: false))
            XCTAssertNil(theme.tabBarContent(tab: .today, remaining: { _ in 3 }, onSelect: { _ in }))
            XCTAssertNil(theme.rowTrailingAccessory(done: true, age: 2, triage: false, index: 1))
            _ = theme.allClearedState(onPeek: {})
        }
    }

    func testNewMotionDefaultsAreZeroAndReduceMotionSafe() {
        for motion in [macTheme.motion, arcadeTheme.motion] {
            XCTAssertEqual(motion.panelEnterBlur, 0, accuracy: 0.0001)
            XCTAssertEqual(motion.panelExitBlur, 0, accuracy: 0.0001)
            XCTAssertEqual(motion.panelBlur(entering: true, reduceMotion: false), 0, accuracy: 0.0001)
            XCTAssertEqual(motion.panelBlur(entering: false, reduceMotion: false), 0, accuracy: 0.0001)
            XCTAssertEqual(motion.panelBlur(entering: true, reduceMotion: true), 0, accuracy: 0.0001)
            XCTAssertEqual(motion.rowEntranceTransform.blur, 0, accuracy: 0.0001)
        }
    }

    func testLegacyThemeLayoutMatchesCurrentSharedMacOSGeometry() {
        let layout = macTheme.layout
        XCTAssertEqual(layout, arcadeTheme.layout)

        XCTAssertEqual(layout.mainColumnInsets, .zero)
        XCTAssertEqual(layout.railInsets, .zero)
        XCTAssertEqual(layout.mainColumnSpacing, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.headerInsets, ThemeInsets(top: 15, leading: 18, bottom: 10, trailing: 12))
        XCTAssertEqual(layout.headerContentSpacing, 10, accuracy: 0.0001)
        XCTAssertEqual(layout.headerControlsSpacing, 6, accuracy: 0.0001)
        XCTAssertEqual(layout.headerTextSpacing, 2, accuracy: 0.0001)
        XCTAssertEqual(layout.headerTrailingAccessorySpacing, 0, accuracy: 0.0001)

        XCTAssertEqual(layout.dividerInsets, .zero)
        XCTAssertEqual(layout.dividerHeight, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.tabInsets, ThemeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
        XCTAssertEqual(layout.tabHeight, 28, accuracy: 0.0001)
        XCTAssertEqual(layout.tabCornerRadius, 7, accuracy: 0.0001)
        XCTAssertEqual(layout.tabThumbInset, 3, accuracy: 0.0001)
        XCTAssertEqual(layout.tabTrackCornerRadius, 9, accuracy: 0.0001)
        XCTAssertEqual(layout.tabLabelSpacing, 6, accuracy: 0.0001)
        XCTAssertEqual(layout.tabCellInsets, .zero)
        XCTAssertEqual(layout.tabSublineSpacing, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.tabIndicatorHeight, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.tabIndicatorBottomInset, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.stageTopSpacing, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.stageInsets, .zero)
        XCTAssertEqual(layout.listInsets, ThemeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
        XCTAssertEqual(layout.listRowSpacing, 0, accuracy: 0.0001)

        XCTAssertEqual(layout.rowInsets, ThemeInsets(top: 9, leading: 10, bottom: 9, trailing: 10))
        XCTAssertEqual(layout.rowContentSpacing, 11, accuracy: 0.0001)
        XCTAssertEqual(layout.rowStackSpacing, 6, accuracy: 0.0001)
        XCTAssertEqual(layout.rowTrailingSpacing, 6, accuracy: 0.0001)
        XCTAssertEqual(layout.rowActionsSpacing, 2, accuracy: 0.0001)
        XCTAssertEqual(layout.rowTitleTrailingReserve, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.triageInsets, ThemeInsets(top: 0, leading: 33, bottom: 0, trailing: 2))
        XCTAssertEqual(layout.triageContentSpacing, 8, accuracy: 0.0001)

        XCTAssertEqual(layout.composerInsets, ThemeInsets(top: 8, leading: 14, bottom: 10, trailing: 14))
        XCTAssertEqual(layout.composerStackSpacing, 8, accuracy: 0.0001)
        XCTAssertEqual(layout.composerFieldSpacing, 9, accuracy: 0.0001)
        XCTAssertEqual(layout.composerFieldInsets, ThemeInsets(top: 0, leading: 12, bottom: 0, trailing: 6))
        XCTAssertEqual(layout.composerFieldMinimumHeight, 40, accuracy: 0.0001)
        XCTAssertEqual(layout.footerInsets, ThemeInsets(top: 8, leading: 14, bottom: 12, trailing: 14))
        XCTAssertEqual(layout.footerContentSpacing, 10, accuracy: 0.0001)

        let stateInsets = ThemeInsets(top: 26, leading: 24, bottom: 20, trailing: 24)
        XCTAssertEqual(layout.emptyStateInsets, stateInsets)
        XCTAssertEqual(layout.emptyStateContentSpacing, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.emptyIconBottomSpacing, 14, accuracy: 0.0001)
        XCTAssertEqual(layout.emptyBodyTopSpacing, 4, accuracy: 0.0001)
        XCTAssertEqual(layout.clearedStateInsets, stateInsets)
        XCTAssertEqual(layout.clearedStateContentSpacing, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.clearedIconBottomSpacing, 14, accuracy: 0.0001)
        XCTAssertEqual(layout.clearedBodyTopSpacing, 4, accuracy: 0.0001)
        XCTAssertEqual(layout.clearedPeekTopSpacing, 0, accuracy: 0.0001)
        XCTAssertFalse(layout.clearedStateFillsAvailableSpace)
    }
}
