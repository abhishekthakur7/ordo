import XCTest
import SwiftUI
import AppKit
@testable import OrdoThemes

/// Mirrors `MacOSThemeTests`' structure and rigor for the Arcade theme.
/// Assertions are checked against the ACTUAL values in `ArcadeTheme.swift` /
/// `ArcadeStructuralViews.swift` (read before writing this file), not re-derived
/// from `mockups/01-arcade.html` — any discrepancy vs the distilled spec is
/// called out inline.
final class ArcadeThemeTests: XCTestCase {

    let theme = ArcadeTheme()
    let macTheme = MacOSTheme()

    // MARK: Helpers

    private func comps(_ c: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        let ns = NSColor(c).usingColorSpace(.sRGB)!
        return (Double(ns.redComponent), Double(ns.greenComponent),
                Double(ns.blueComponent), Double(ns.alphaComponent))
    }

    // MARK: Identity & voice

    func testIdentityAndVoice() {
        XCTAssertEqual(theme.id, .arcade)
        XCTAssertEqual(theme.displayName, "Arcade")
        XCTAssertEqual(theme.todayTabLabel, "TODAY")
        XCTAssertEqual(theme.longtermTabLabel, "QUESTS")
        XCTAssertEqual(theme.doneSectionLabel, "CLEARED")
    }

    func testAllClearIsVerbatimStageClear() {
        // Verbatim from the mockup's victory panel (`.v-title` / `.v-sub`).
        XCTAssertEqual(theme.allClearTitle, "STAGE CLEAR")
        XCTAssertEqual(theme.allClearMessage, "Every task down. Take the win — tomorrow can wait.")
    }

    func testFirstRunCopyIsArcadeVoiced() {
        // JUDGMENT CALL in the source (no verbatim first-run copy in the mockup's
        // demo data) — asserting the actual voiced strings, not inventing new ones.
        XCTAssertEqual(theme.firstRunTitle, "PRESS START")
        XCTAssertFalse(theme.firstRunMessage.isEmpty)
    }

    func testGreetingIsArcadeVoicedButUnusedInHeader() {
        // Unused in the Arcade header (brand + score shown instead), but still
        // required by the protocol — spot-check the actual thresholds/strings.
        XCTAssertEqual(theme.greeting(forHour: 2), "STILL PLAYING?")
        XCTAssertEqual(theme.greeting(forHour: 9), "NEW GAME.")
        XCTAssertEqual(theme.greeting(forHour: 14), "CONTINUE?")
        XCTAssertEqual(theme.greeting(forHour: 21), "HIGH SCORE HOUR.")
    }

    // MARK: Palette — exact hex, light vs dark independently art-directed

    func testAccentDiffersLightVsDarkExactHex() {
        let dark = comps(theme.palette(for: .dark).accent)
        let light = comps(theme.palette(for: .light).accent)
        // dark #9be05a
        XCTAssertEqual(dark.r, 0x9B.d / 255, accuracy: 0.005)
        XCTAssertEqual(dark.g, 0xE0.d / 255, accuracy: 0.005)
        XCTAssertEqual(dark.b, 0x5A.d / 255, accuracy: 0.005)
        // light #2c5417
        XCTAssertEqual(light.r, 0x2C.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.g, 0x54.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.b, 0x17.d / 255, accuracy: 0.005)
        // independently art-directed, not an inversion
        XCTAssertNotEqual(dark.r, 1 - light.r, accuracy: 0.02)
    }

    func testInkDiffersLightVsDarkExactHex() {
        let dark = comps(theme.palette(for: .dark).ink)   // #e9f2d8
        let light = comps(theme.palette(for: .light).ink) // #1b280d
        XCTAssertEqual(dark.r, 0xE9.d / 255, accuracy: 0.005)
        XCTAssertEqual(dark.g, 0xF2.d / 255, accuracy: 0.005)
        XCTAssertEqual(dark.b, 0xD8.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.r, 0x1B.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.g, 0x28.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.b, 0x0D.d / 255, accuracy: 0.005)
        XCTAssertGreaterThan(dark.r, light.r) // dark ink is light-on-dark
    }

    func testCoinDiffersLightVsDarkExactHex() {
        let dark = comps(theme.palette(for: .dark).coin)   // #ffd24d
        let light = comps(theme.palette(for: .light).coin) // #6a4e07
        XCTAssertEqual(dark.r, 0xFF.d / 255, accuracy: 0.005)
        XCTAssertEqual(dark.g, 0xD2.d / 255, accuracy: 0.005)
        XCTAssertEqual(dark.b, 0x4D.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.r, 0x6A.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.g, 0x4E.d / 255, accuracy: 0.005)
        XCTAssertEqual(light.b, 0x07.d / 255, accuracy: 0.005)
    }

    func testScreenAndCabinetColorsExactHex() {
        let dark = theme.palette(for: .dark)
        // --cab #14180f (cabinet fill), --screen #0c1108 (fieldBackground)
        guard case .cabinet(let darkCab) = dark.surface else {
            return XCTFail("expected .cabinet surface in dark")
        }
        let darkFill = comps(darkCab.fill)
        XCTAssertEqual(darkFill.r, 0x14.d / 255, accuracy: 0.005)
        XCTAssertEqual(darkFill.g, 0x18.d / 255, accuracy: 0.005)
        XCTAssertEqual(darkFill.b, 0x0F.d / 255, accuracy: 0.005)
        let darkScreen = comps(dark.fieldBackground)
        XCTAssertEqual(darkScreen.r, 0x0C.d / 255, accuracy: 0.005)
        XCTAssertEqual(darkScreen.g, 0x11.d / 255, accuracy: 0.005)
        XCTAssertEqual(darkScreen.b, 0x08.d / 255, accuracy: 0.005)

        let light = theme.palette(for: .light)
        guard case .cabinet(let lightCab) = light.surface else {
            return XCTFail("expected .cabinet surface in light")
        }
        // --cab #cdd1b6 (light cabinet), --screen #a8bb72 (DMG LCD green)
        let lightFill = comps(lightCab.fill)
        XCTAssertEqual(lightFill.r, 0xCD.d / 255, accuracy: 0.005)
        XCTAssertEqual(lightFill.g, 0xD1.d / 255, accuracy: 0.005)
        XCTAssertEqual(lightFill.b, 0xB6.d / 255, accuracy: 0.005)
        let lightScreen = comps(light.fieldBackground)
        XCTAssertEqual(lightScreen.r, 0xA8.d / 255, accuracy: 0.005)
        XCTAssertEqual(lightScreen.g, 0xBB.d / 255, accuracy: 0.005)
        XCTAssertEqual(lightScreen.b, 0x72.d / 255, accuracy: 0.005)
    }

    func testGlowIsPresentInDarkAndZeroAlphaInLight() {
        let dark = theme.palette(for: .dark)
        let light = theme.palette(for: .light)
        // dark: rgba(155,224,90,0.55) / coin rgba(255,210,77,0.55)
        XCTAssertEqual(comps(dark.glow).a, 0.55, accuracy: 0.01)
        XCTAssertEqual(comps(dark.coinGlow).a, 0.55, accuracy: 0.01)
        // light: glow none — alpha 0 (--accent-glow rgba(44,84,23,0), --coin-glow rgba(106,78,7,0))
        XCTAssertEqual(comps(light.glow).a, 0, accuracy: 0.01)
        XCTAssertEqual(comps(light.coinGlow).a, 0, accuracy: 0.01)
    }

    // MARK: SurfaceStyle — cabinet, not vibrancy

    func testSurfaceIsCabinetNotVibrancyBothAppearances() {
        for appearance: ResolvedAppearance in [.light, .dark] {
            let p = theme.palette(for: appearance)
            guard case .cabinet(let cab) = p.surface else {
                return XCTFail("expected .cabinet surface for \(appearance)")
            }
            XCTAssertEqual(cab.borderWidth, 2, accuracy: 0.0001)
            XCTAssertEqual(cab.cornerRadius, 16, accuracy: 0.0001)
            XCTAssertEqual(cab.hardShadow.x, 6, accuracy: 0.0001)
            XCTAssertEqual(cab.hardShadow.y, 8, accuracy: 0.0001)
        }
    }

    func testOverlayKindDiffersLightVsDark() {
        let dark = theme.palette(for: .dark)
        let light = theme.palette(for: .light)
        guard case .cabinet(let darkCab) = dark.surface,
              case .cabinet(let lightCab) = light.surface else {
            return XCTFail("expected cabinet surfaces")
        }
        XCTAssertEqual(darkCab.overlay.kind, .scanlines)
        XCTAssertEqual(darkCab.overlay.scanlineOpacity, 0.42, accuracy: 0.001)
        XCTAssertEqual(lightCab.overlay.kind, .lcdGrain)
    }

    // MARK: Type scale

    func testTaskTitleUsesSpaceGroteskAtSpecSize() {
        let ts = theme.typeScale
        guard case .named(let family) = ts.taskTitle.fontFamily else {
            return XCTFail("expected a named font family for taskTitle")
        }
        XCTAssertEqual(family, FontRegistrar.spaceGroteskFamily)
        XCTAssertEqual(ts.taskTitle.size, 14.5, accuracy: 0.001)
        XCTAssertEqual(ts.taskTitle.lineHeightMultiple, 1.25, accuracy: 0.0001)
    }

    func testTabUsesPressStart2PAtSpecSize() {
        let ts = theme.typeScale
        guard case .named(let family) = ts.tab.fontFamily else {
            return XCTFail("expected a named font family for tab")
        }
        XCTAssertEqual(family, FontRegistrar.pressStart2PFamily)
        XCTAssertEqual(ts.tab.size, 8, accuracy: 0.001)
    }

    func testNamedFontFamiliesAreUsedThroughoutNotSystem() {
        // Every pixel/body role in Arcade's TypeScale should resolve to a named
        // (bundled) font, never `.system` — that's the macOS-only default.
        let ts = theme.typeScale
        let tokens: [TypeToken] = [
            ts.greeting, ts.date, ts.tab, ts.tabCount, ts.taskTitle, ts.ageMarker,
            ts.doneHeader, ts.field, ts.emptyTitle, ts.emptyBody, ts.railKicker,
            ts.ringNumber, ts.ringSub, ts.railLine, ts.railLineValue, ts.railQuote,
            ts.segmentButton,
        ]
        for token in tokens {
            guard case .named = token.fontFamily else {
                return XCTFail("expected .named fontFamily, got .system")
            }
        }
    }

    func testArcadeStaticTypeTokensExist() {
        XCTAssertEqual(ArcadeTheme.brandType.size, 11, accuracy: 0.001)
        XCTAssertEqual(ArcadeTheme.statusNumberType.size, 20, accuracy: 0.001)
        XCTAssertTrue(ArcadeTheme.statusNumberType.monospacedDigit)
        XCTAssertEqual(ArcadeTheme.scoreType.size, 14, accuracy: 0.001)
        XCTAssertEqual(ArcadeTheme.indexType.size, 7, accuracy: 0.001)
        XCTAssertEqual(ArcadeTheme.sfxLabelType.size, 7, accuracy: 0.001)
        XCTAssertEqual(ArcadeTheme.statBigType.size, 24, accuracy: 0.001)
        XCTAssertEqual(ArcadeTheme.statSmallType.size, 13, accuracy: 0.001)
        XCTAssertEqual(ArcadeTheme.victoryTitleType.size, 15, accuracy: 0.001)
        XCTAssertEqual(ArcadeTheme.victoryScoreType.size, 9, accuracy: 0.001)
    }

    // MARK: Metrics

    func testMetricsMatchArcadeCabinetChrome() {
        let m = theme.metrics
        XCTAssertEqual(m.panelCompactSize.width, 380, accuracy: 0.001)
        XCTAssertEqual(m.panelCompactSize.height, 562, accuracy: 0.001)
        XCTAssertEqual(m.panelExpandedSize.width, 604, accuracy: 0.001)
        XCTAssertEqual(m.panelExpandedSize.height, 582, accuracy: 0.001)
        XCTAssertEqual(m.panelCornerRadius, 16, accuracy: 0.001)
        XCTAssertEqual(m.railWidth, 196, accuracy: 0.001)
        XCTAssertEqual(m.checkboxSize, 22, accuracy: 0.001)
        XCTAssertEqual(m.borderWidth, 2, accuracy: 0.001)
    }

    // MARK: Motion

    func testNamedMotionDurations() {
        let m = theme.motion
        XCTAssertEqual(m.tabThumb.duration, 0.320, accuracy: 0.0001)
        XCTAssertEqual(m.tabThumb.curve, .easeDrawer)
        XCTAssertEqual(m.expandMorph.duration, 0.460, accuracy: 0.0001)
        XCTAssertEqual(m.expandMorph.curve, .easeDrawer)
        XCTAssertEqual(m.rowEntrance.duration, 0.340, accuracy: 0.0001)
    }

    func testTickDrawAndSoundKnobAreSteppedCurves() {
        let m = theme.motion
        XCTAssertEqual(m.tickDraw.curve.stepCount, 4)
        XCTAssertEqual(m.tickDraw.duration, 0.220, accuracy: 0.0001)
        XCTAssertEqual(m.soundKnob.curve.stepCount, 4)
        XCTAssertEqual(m.soundKnob.duration, 0.180, accuracy: 0.0001)
    }

    func testReduceMotionVariantsExist() {
        XCTAssertEqual(theme.motion.expandMorph.reducedDuration, 0.2, accuracy: 0.0001)
        XCTAssertEqual(theme.motion.tickDraw.reducedDuration, 0.2, accuracy: 0.0001)
        _ = theme.motion.checkboxFill.animation(reduceMotion: true)
        _ = theme.motion.checkboxFill.animation(reduceMotion: false)
    }

    // MARK: Sound set

    func testAllEightSoundEventsHaveRecipes() {
        for e in SoundEvent.allCases {
            XCTAssertNotNil(theme.soundSet[e], "missing recipe for \(e)")
        }
        XCTAssertEqual(theme.soundSet.events.count, 8)
    }

    func testCompleteRecipeIsTwoSquareTones() {
        let r = theme.soundSet[.complete]!
        XCTAssertEqual(r.components.count, 2)
        guard case let .oscillator(o1) = r.components[0],
              case let .oscillator(o2) = r.components[1] else {
            return XCTFail("expected two oscillator components")
        }
        XCTAssertEqual(o1.wave, .square)
        XCTAssertEqual(o1.frequency, 988, accuracy: 0.001)
        XCTAssertEqual(o1.duration, 0.07, accuracy: 0.0001)
        XCTAssertEqual(o1.peakGain, 0.08, accuracy: 0.0001)
        XCTAssertEqual(o2.wave, .square)
        XCTAssertEqual(o2.frequency, 1319, accuracy: 0.001)
        XCTAssertEqual(o2.startDelay, 0.07, accuracy: 0.0001)
        XCTAssertEqual(o2.duration, 0.16, accuracy: 0.0001)
    }

    func testUncheckRecipeGlidesSquareDown() {
        let r = theme.soundSet[.uncheck]!
        guard case let .oscillator(o) = r.components[0] else { return XCTFail() }
        XCTAssertEqual(o.wave, .square)
        XCTAssertEqual(o.frequency, 440, accuracy: 0.001)
        XCTAssertEqual(o.glideTo!, 220, accuracy: 0.001)
    }

    func testTabSwitchRecipeIsSquareGlideUp() {
        let r = theme.soundSet[.tabSwitch]!
        guard case let .oscillator(o) = r.components[0] else { return XCTFail() }
        XCTAssertEqual(o.wave, .square)
        XCTAssertEqual(o.frequency, 360, accuracy: 0.001)
        XCTAssertEqual(o.glideTo!, 500, accuracy: 0.001)
    }

    func testPanelOpenRecipeIsTriangleGlideUp() {
        let r = theme.soundSet[.panelOpen]!
        guard case let .oscillator(o) = r.components[0] else { return XCTFail() }
        XCTAssertEqual(o.wave, .triangle)
        XCTAssertEqual(o.frequency, 300, accuracy: 0.001)
        XCTAssertEqual(o.glideTo!, 760, accuracy: 0.001)
        XCTAssertEqual(o.duration, 0.16, accuracy: 0.0001)
    }

    func testToggleOnRecipeIsSquare1200() {
        let r = theme.soundSet[.toggleOn]!
        guard case let .oscillator(o) = r.components[0] else { return XCTFail() }
        XCTAssertEqual(o.wave, .square)
        XCTAssertEqual(o.frequency, 1200, accuracy: 0.001)
        XCTAssertEqual(o.duration, 0.04, accuracy: 0.0001)
    }

    // MARK: Font-family resolution

    func testFontRegistrarFamiliesAreNonEmpty() {
        XCTAssertFalse(FontRegistrar.pressStart2PFamily.isEmpty)
        XCTAssertFalse(FontRegistrar.spaceGroteskFamily.isEmpty)
    }

    func testNamedTypeTokenFontDoesNotCrash() {
        FontRegistrar.registerAll()
        _ = theme.typeScale.taskTitle.font
        _ = theme.typeScale.tab.font
        _ = ArcadeTheme.brandType.font
    }

    // MARK: Accessibility

    func testIncreaseContrastThickensStructure() {
        let normal = theme.palette(for: .dark)
        let bumped = theme.palette(for: .dark, accessibility: AccessibilityOptions(increaseContrast: true))
        XCTAssertEqual(normal.hairlineWidth, 2, accuracy: 0.001)
        XCTAssertEqual(bumped.hairlineWidth, 3, accuracy: 0.001)
        guard case .cabinet(let normalCab) = normal.surface,
              case .cabinet(let bumpedCab) = bumped.surface else {
            return XCTFail("expected cabinet surfaces")
        }
        XCTAssertEqual(normalCab.borderWidth, 2, accuracy: 0.001)
        XCTAssertEqual(bumpedCab.borderWidth, 3, accuracy: 0.001) // thicker border
    }

    func testReduceTransparencyKeepsCabinetOpaqueAndDoesNotCrash() {
        let reduced = theme.palette(for: .dark, accessibility: AccessibilityOptions(reduceTransparency: true))
        guard case .cabinet(let cab) = reduced.surface else {
            return XCTFail("expected reduced-transparency palette to still return a cabinet surface")
        }
        // Cabinet was already opaque; Reduce Transparency should soften the
        // overlay rather than change the fundamental surface kind.
        XCTAssertEqual(cab.overlay.kind, .scanlines)
        XCTAssertTrue(reduced.material.usesFallback)
        XCTAssertEqual(comps(reduced.material.fallbackOpaque).a, 1.0, accuracy: 0.001)
    }

    // MARK: Structural hook defaults vs Arcade overrides

    func testArcadeStructuralHookOverrides() {
        XCTAssertFalse(theme.showsDoneSection)
        XCTAssertFalse(theme.showsTabCountBadge)
        XCTAssertTrue(theme.usesCabinetRows)
        XCTAssertEqual(theme.soundToggleLabel, "SFX")
    }

    func testMacOSKeepsStructuralHookDefaults() {
        XCTAssertTrue(macTheme.showsDoneSection)
        XCTAssertTrue(macTheme.showsTabCountBadge)
        XCTAssertFalse(macTheme.usesCabinetRows)
        XCTAssertNil(macTheme.soundToggleLabel)
    }

    func testArcadeContentBuildersReturnNonNilMacOSReturnsNil() {
        XCTAssertNotNil(theme.statusRow(done: 2, total: 5, isToday: true))
        XCTAssertNotNil(theme.railContent(done: 2, total: 5, remaining: 3, score: 200, best: 400, streak: 3))
        XCTAssertNotNil(theme.headerLeading(score: 200))

        XCTAssertNil(macTheme.statusRow(done: 2, total: 5, isToday: true))
        XCTAssertNil(macTheme.railContent(done: 2, total: 5, remaining: 3, score: 200, best: 400, streak: 3))
        XCTAssertNil(macTheme.headerLeading(score: 200))
    }

    func testComposerPlaceholderIsUppercaseArcadeVoiced() {
        XCTAssertEqual(theme.composerPlaceholder(isToday: true), "ADD A TASK…")
        XCTAssertEqual(theme.composerPlaceholder(isToday: false), "ADD A QUEST…")
        XCTAssertNil(macTheme.composerPlaceholder(isToday: true))
    }
}

private extension Int {
    /// Terse hex-literal-to-Double helper for palette assertions above
    /// (e.g. `0x9B.d` reads as "0x9B as a Double").
    var d: Double { Double(self) }
}
