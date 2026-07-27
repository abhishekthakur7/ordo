import XCTest
import SwiftUI
import AppKit
@testable import OrdoThemes

/// Phase-6 contract coverage for the complete Zen Ink theme.  This mirrors the
/// grouped Arcade suite while exercising Zen's paper, static-font, and
/// structural-view contracts independently of the earlier data-only tests.
final class ZenInkThemeTests: XCTestCase {
    private let theme = ZenInkTheme()
    private let macTheme = MacOSTheme()

    // MARK: Helpers

    private func components(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        let resolved = NSColor(color).usingColorSpace(.sRGB)!
        return (Double(resolved.redComponent), Double(resolved.greenComponent),
                Double(resolved.blueComponent), Double(resolved.alphaComponent))
    }

    private func assertColor(_ color: Color, hex: UInt32, alpha: Double = 1,
                             file: StaticString = #filePath, line: UInt = #line) {
        let actual = components(color)
        XCTAssertEqual(actual.r, Double((hex >> 16) & 0xFF) / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.g, Double((hex >> 8) & 0xFF) / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.b, Double(hex & 0xFF) / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.a, alpha, accuracy: 0.005, file: file, line: line)
    }

    private func assertRGBA(_ color: Color, _ red: Double, _ green: Double, _ blue: Double, _ alpha: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        let actual = components(color)
        XCTAssertEqual(actual.r, red / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.g, green / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.b, blue / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.a, alpha, accuracy: 0.005, file: file, line: line)
    }

    private func assertPluck(_ component: SoundComponent, frequency: Double, gain: Double, duration: Double,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard case let .pluck(pluck) = component else { return XCTFail("expected koto pluck", file: file, line: line) }
        XCTAssertEqual(pluck.frequency, frequency, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(pluck.peakGain, gain, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.duration, duration, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.attack, 0.005, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.secondPartialRatio, 2.003, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.secondPartialGain, 0.32, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.thirdPartialRatio, 3.01, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.thirdPartialGain, 0.12, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.partialDecayPerMultiplier, 0.15, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.lowpassStart, 4_200, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(pluck.lowpassEnd, 900, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(pluck.lowpassSweepDuration, 0.45, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.pickHighpass, 2_000, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(pluck.pickGain, 0.06, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.pickDuration, 0.05, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(pluck.pickAttack, 0.002, accuracy: 0.0001, file: file, line: line)
    }

    // MARK: Identity & voice

    func testIdentityAndZenVoice() {
        XCTAssertEqual(theme.id, .zenInk)
        XCTAssertEqual(theme.displayName, "Zen Ink")
        XCTAssertEqual(theme.todayTabLabel, "Today")
        XCTAssertEqual(theme.longtermTabLabel, "道")
        XCTAssertEqual(theme.doneSectionLabel, "済")
        XCTAssertEqual(theme.firstRunTitle, "始めましょう")
        XCTAssertEqual(theme.firstRunMessage, "Begin.")
        XCTAssertEqual(theme.allClearTitle, "日々是好日")
        XCTAssertEqual(theme.allClearMessage, "Every day, a good day.")
    }

    func testGreetingThresholdsRemainQuietAndSpecific() {
        XCTAssertEqual(theme.greeting(forHour: 4), "The night is still.")
        XCTAssertEqual(theme.greeting(forHour: 5), "Begin gently.")
        XCTAssertEqual(theme.greeting(forHour: 12), "One thing at a time.")
        XCTAssertEqual(theme.greeting(forHour: 18), "Let the day settle.")
    }

    // MARK: Palette — exact hex, independently art-directed

    func testLightPaletteExactHexes() {
        let palette = theme.palette(for: .light)
        assertColor(palette.ink, hex: 0x231F19); assertColor(palette.ink2, hex: 0x514A3F)
        assertColor(palette.ink3, hex: 0x8A8071); assertColor(palette.inkFaint, hex: 0xA89E8D)
        assertColor(palette.segmentThumb, hex: 0xFCF8EF); assertColor(palette.accent, hex: 0xC33A28)
        assertColor(palette.accentInk, hex: 0xF8F3E8); assertColor(palette.checkRing, hex: 0x8A8071)
        assertRGBA(palette.rowHover, 35, 31, 25, 0.08); assertRGBA(palette.fieldLine, 35, 31, 25, 0.12)
        assertRGBA(palette.accentSoft, 195, 58, 40, 0.18); assertRGBA(palette.divider, 35, 31, 25, 0.07)
        XCTAssertEqual(components(palette.fieldBackground).a, 0, accuracy: 0.001)
    }

    func testDarkPaletteExactHexesAndIsNotAnInversion() {
        let light = theme.palette(for: .light)
        let dark = theme.palette(for: .dark)
        assertColor(dark.ink, hex: 0xCBD0DC); assertColor(dark.ink2, hex: 0xAEB4C3)
        assertColor(dark.ink3, hex: 0x7C8291); assertColor(dark.inkFaint, hex: 0x565C6D)
        assertColor(dark.segmentThumb, hex: 0x1C2031); assertColor(dark.accent, hex: 0xDE5B49)
        assertColor(dark.accentInk, hex: 0x181B28); assertColor(dark.checkRing, hex: 0x7C8291)
        assertRGBA(dark.rowHover, 203, 208, 220, 0.10); assertRGBA(dark.fieldLine, 203, 208, 220, 0.13)
        assertRGBA(dark.accentSoft, 222, 91, 73, 0.18); assertRGBA(dark.divider, 203, 208, 220, 0.06)
        XCTAssertNotEqual(components(dark.ink).r, 1 - components(light.ink).r, accuracy: 0.02)
        XCTAssertNotEqual(components(dark.accent).r, 1 - components(light.accent).r, accuracy: 0.02)
    }

    // MARK: SurfaceStyle — opaque washi paper

    func testPaperSurfaceAndGrainAreExactForBothAppearances() {
        let light = theme.palette(for: .light)
        let dark = theme.palette(for: .dark)
        guard case let .paper(lightPaper) = light.surface, case let .paper(darkPaper) = dark.surface else {
            return XCTFail("Zen Ink must use .paper in both appearances")
        }
        assertColor(lightPaper.fillTop, hex: 0xFCF8EF); assertColor(lightPaper.fillBottom, hex: 0xF8F3E8)
        XCTAssertEqual(lightPaper.borderWidth, 1, accuracy: 0.0001); XCTAssertEqual(lightPaper.cornerRadius, 22, accuracy: 0.0001)
        XCTAssertEqual(lightPaper.grain.blend, .multiply); XCTAssertEqual(lightPaper.grain.tile, 170, accuracy: 0.0001)
        XCTAssertEqual(lightPaper.grain.opacity, 0.045 * 0.7, accuracy: 0.0001)
        assertColor(darkPaper.fillTop, hex: 0x1C2031); assertColor(darkPaper.fillBottom, hex: 0x181B28)
        XCTAssertEqual(darkPaper.borderWidth, 1, accuracy: 0.0001); XCTAssertEqual(darkPaper.cornerRadius, 22, accuracy: 0.0001)
        XCTAssertEqual(darkPaper.grain.blend, .overlay); XCTAssertEqual(darkPaper.grain.tile, 170, accuracy: 0.0001)
        XCTAssertEqual(darkPaper.grain.opacity, 0.05 * 0.7, accuracy: 0.0001)
        XCTAssertEqual(lightPaper.shadow, light.panelShadow); XCTAssertEqual(darkPaper.shadow, dark.panelShadow)
    }

    // MARK: Type scale

    func testTypeScaleUsesOnlyExactBundledPostScriptFaces() {
        let scale = theme.typeScale
        let tokens = [scale.greeting, scale.date, scale.tab, scale.tabCount, scale.taskTitle, scale.ageMarker,
                      scale.doneHeader, scale.field, scale.emptyTitle, scale.emptyBody, scale.railKicker,
                      scale.ringNumber, scale.ringSub, scale.railLine, scale.railLineValue, scale.railQuote,
                      scale.segmentButton]
        let postScriptFaces = tokens.compactMap { token -> String? in
            guard case let .postScript(face) = token.fontFamily else { return nil }
            return face
        }
        let faces = Set(postScriptFaces)
        XCTAssertEqual(postScriptFaces.count, tokens.count) // every token reached .postScript
        XCTAssertFalse(tokens.contains { if case .system = $0.fontFamily { return true }; return false })
        XCTAssertTrue(faces.contains(FontRegistrar.shipporiMinchoRegular))
        XCTAssertTrue(faces.contains(FontRegistrar.zenKakuGothicNewRegular))
        XCTAssertEqual(scale.taskTitle.size, 15, accuracy: 0.0001)
        XCTAssertEqual(scale.taskTitle.lineHeightMultiple, 1.4, accuracy: 0.0001)
        XCTAssertEqual(scale.ringNumber.size, 34, accuracy: 0.0001)
        XCTAssertEqual(ZenInkTheme.wordmarkType.fontFamily, .postScript(FontRegistrar.shipporiMinchoBold))
        XCTAssertEqual(ZenInkTheme.sealCharType.fontFamily, .postScript(FontRegistrar.shipporiMinchoExtraBold))
    }

    func testBothBundledFontFamiliesResolveTheirExactPostScriptFaces() {
        FontRegistrar.registerAll()
        for face in [FontRegistrar.shipporiMinchoRegular, FontRegistrar.shipporiMinchoSemiBold,
                     FontRegistrar.shipporiMinchoBold, FontRegistrar.shipporiMinchoExtraBold,
                     FontRegistrar.zenKakuGothicNewRegular, FontRegistrar.zenKakuGothicNewMedium] {
            let font = NSFont(name: face, size: 14)
            XCTAssertNotNil(font, "failed to resolve bundled face \(face)")
            XCTAssertEqual(font?.fontName, face)
        }
        _ = theme.typeScale.taskTitle.font
        _ = ZenInkTheme.wordmarkType.font
    }

    // MARK: Metrics & layout

    func testMetricsAndLayoutMatchZenGeometry() {
        let metrics = theme.metrics
        XCTAssertEqual(metrics.panelCompactSize, CGSize(width: 380, height: 568))
        XCTAssertEqual(metrics.panelExpandedSize, CGSize(width: 604, height: 568))
        XCTAssertEqual(metrics.panelCornerRadius, 22); XCTAssertEqual(metrics.railWidth, 194)
        XCTAssertEqual(metrics.ringRadius, 46.2); XCTAssertEqual(metrics.ringStrokeWidth, 6.05)
        XCTAssertEqual(metrics.compactRingDiameter, 38); XCTAssertEqual(metrics.compactRingStrokeWidth, 2.22)
        XCTAssertEqual(metrics.rowCornerRadius, 12); XCTAssertEqual(metrics.checkboxSize, 24); XCTAssertEqual(metrics.notchInsetFromRight, 26)

        let layout = theme.layout
        XCTAssertEqual(layout.railInsets, ThemeInsets(top: 30, leading: 22, bottom: 26, trailing: 22))
        XCTAssertEqual(layout.mainColumnInsets, ThemeInsets(top: 22, leading: 24, bottom: 0, trailing: 24))
        XCTAssertEqual(layout.tabHeight, 54); XCTAssertEqual(layout.tabIndicatorHeight, 9); XCTAssertEqual(layout.tabIndicatorBottomInset, 2)
        XCTAssertEqual(layout.rowInsets, ThemeInsets(top: 11, leading: 8, bottom: 11, trailing: 8))
        XCTAssertEqual(layout.rowContentSpacing, 13); XCTAssertEqual(layout.rowTitleTrailingReserve, 62)
        XCTAssertEqual(layout.composerInsets, ThemeInsets(top: 14, leading: 8, bottom: 12, trailing: 8))
        XCTAssertEqual(layout.footerInsets, ThemeInsets(top: 12, leading: 6, bottom: 18, trailing: 6))
        XCTAssertEqual(layout.clearedPeekTopSpacing, 26); XCTAssertTrue(layout.clearedStateFillsAvailableSpace)
    }

    // MARK: Motion

    func testAllNamedMotionDurationsAndRingCurveAreExact() {
        let motion = theme.motion
        let expected: [(MotionToken, Double, MotionCurve)] = [
            (motion.panelEnter, 0.520, .easeOut), (motion.panelExit, 0.280, .easeOut),
            (motion.expandMorph, 0.620, .easeDrawer), (motion.tabThumb, 0.420, .easeDrawer),
            (motion.appearanceThumb, 0.380, .easeDrawer), (motion.soundKnob, 0.240, .easeOut),
            (motion.checkboxFill, 0.420, .easeOut), (motion.tickDraw, 0.360, .easeOut),
            (motion.strikethrough, 0.560, .easeOut), (motion.titleColorFade, 0.460, .easeOut),
            (motion.rowEntrance, 0.500, .easeOut), (motion.flipMove, 0.500, .easeOut),
            (motion.ring, 0.950, .easeIO), (motion.appearanceCrossfade, 0.600, .easeOut),
            (motion.hoverFade, 0.240, .easeOut), (motion.pressEcho, 0.160, .easeOut),
            (motion.counterFade, 0.220, .easeOut),
        ]
        for (token, duration, curve) in expected {
            XCTAssertEqual(token.duration, duration, accuracy: 0.0001)
            XCTAssertEqual(token.curve, curve)
        }
        XCTAssertEqual(motion.checkboxSequence.fillKeyframes, [.init(scale: 0.2, fraction: 0), .init(scale: 1, fraction: 1)])
        XCTAssertEqual(motion.rowEntranceTransform, RowEntranceTransform(translateY: -10, scale: 1, duration: 0.5, blur: 6))
    }

    // MARK: Sound set

    func testAllEightEventsAndSixAddVariantsHaveZenRecipes() {
        XCTAssertEqual(Set(theme.soundSet.events), Set(SoundEvent.allCases))
        XCTAssertEqual(theme.soundSet.events.count, 8)
        XCTAssertEqual(theme.soundSet.variants(for: .add).count, 6)
        for event in SoundEvent.allCases { XCTAssertFalse(theme.soundSet.variants(for: event).isEmpty, "missing \(event)") }
    }

    func testSoundRecipeShapesIncludingEveryPluckVariant() {
        let complete = theme.soundSet[.complete]!
        XCTAssertEqual(complete.components.count, 2)
        guard case let .oscillator(wood) = complete.components[0], case let .noise(knock) = complete.components[1] else {
            return XCTFail("complete must be sine wood tone plus noise knock")
        }
        XCTAssertEqual(wood, Oscillator(wave: .sine, frequency: 820, glideTo: 300, duration: 0.160, peakGain: 0.20, attack: 0.004))
        XCTAssertEqual(knock, NoiseSwoosh(duration: 0.040, peakGain: 0.10, bandpassStart: 1_900, bandpassEnd: 1_900, q: 1.1, attack: 0.0001, amplitudeTaperLinear: false))

        for (recipe, pitch) in zip(theme.soundSet.variants(for: .add), [261.63, 293.66, 349.23, 392.0, 440.0, 523.25]) {
            XCTAssertEqual(recipe.components.count, 1)
            assertPluck(recipe.components[0], frequency: pitch, gain: 0.15, duration: 1)
        }
        assertPluck(theme.soundSet[.uncheck]!.components[0], frequency: 174.61, gain: 0.09, duration: 0.7)
        assertPluck(theme.soundSet[.tabSwitch]!.components[0], frequency: 392, gain: 0.075, duration: 0.5)

        for (event, start, end, gain, duration, pitch) in [(SoundEvent.panelOpen, 500.0, 2_200.0, 0.045, 0.5, 293.66), (.panelClose, 2_000, 450, 0.04, 0.36, 220)] {
            let recipe = theme.soundSet[event]!
            XCTAssertEqual(recipe.components.count, 2)
            guard case let .noise(noise) = recipe.components[0] else { return XCTFail("\(event) must begin with noise") }
            XCTAssertEqual(noise, NoiseSwoosh(duration: duration, peakGain: gain, bandpassStart: start, bandpassEnd: end, q: 0.8, attack: event == .panelOpen ? 0.120 : 0.0001, amplitudeTaperLinear: false))
            assertPluck(recipe.components[1], frequency: pitch, gain: 0.06, duration: 0.6)
        }
        for (event, gain) in [(SoundEvent.toggleOn, 0.09), (.toggleOff, 0.06)] {
            guard case let .oscillator(tick) = theme.soundSet[event]!.components[0] else { return XCTFail("\(event) must be a sine tick") }
            XCTAssertEqual(tick, Oscillator(wave: .sine, frequency: 1_400, glideTo: 700, duration: 0.060, peakGain: gain, attack: 0.003))
        }
    }

    // MARK: Accessibility

    func testAccessibilityDeltasThickenPaperAndRemoveOnlyGrain() {
        let standard = theme.palette(for: .light)
        let contrast = theme.palette(for: .light, accessibility: .init(increaseContrast: true))
        XCTAssertEqual(contrast.hairlineWidth, 1.5, accuracy: 0.0001)
        XCTAssertEqual(contrast.inkFaint, standard.ink3)
        guard case let .paper(contrastPaper) = contrast.surface else { return XCTFail("expected paper surface") }
        XCTAssertEqual(contrastPaper.borderWidth, 1.5, accuracy: 0.0001)
        for appearance: ResolvedAppearance in [.light, .dark] {
            guard case let .paper(paper) = theme.palette(for: appearance, accessibility: .init(reduceTransparency: true)).surface else {
                return XCTFail("expected paper surface")
            }
            XCTAssertEqual(paper.grain.opacity, 0, accuracy: 0.0001)
        }
    }

    // MARK: Structural-hook overrides vs macOS defaults

    func testZenStructuralOverridesRemainDistinctFromMacOSDefaults() {
        XCTAssertFalse(theme.showsDoneSection); XCTAssertFalse(theme.showsTabCountBadge)
        XCTAssertTrue(theme.clearedStateCoversList); XCTAssertTrue(theme.clearedStateIsPeekable); XCTAssertTrue(theme.mainColumnFlexes)
        XCTAssertEqual(theme.composerStyle, .ink); XCTAssertEqual(theme.appearanceSegmentStyle, .labelOnly)
        XCTAssertEqual(theme.soundControlStyle, .ghostIcon); XCTAssertEqual(theme.tabIndicatorStyle, .custom)
        XCTAssertNotNil(theme.headerLeading(score: 0)); XCTAssertNotNil(theme.headerAccessory())
        XCTAssertNotNil(theme.headerTrailingAccessory(done: 1, total: 2, expanded: false))
        XCTAssertNotNil(theme.railContent(done: 1, total: 2, remaining: 1, score: 0, best: 0, streak: 0))
        XCTAssertNotNil(theme.rowTrailingAccessory(done: true, age: 1, triage: false, index: nil))
        XCTAssertNil(theme.rowTrailingAccessory(done: false, age: 1, triage: false, index: nil))
        XCTAssertEqual(theme.composerPlaceholder(isToday: true), "書く… write the next thing")

        XCTAssertTrue(macTheme.showsDoneSection); XCTAssertTrue(macTheme.showsTabCountBadge)
        XCTAssertFalse(macTheme.clearedStateCoversList); XCTAssertFalse(macTheme.clearedStateIsPeekable); XCTAssertFalse(macTheme.mainColumnFlexes)
        XCTAssertEqual(macTheme.composerStyle, .card); XCTAssertEqual(macTheme.appearanceSegmentStyle, .iconAndLabel)
        XCTAssertEqual(macTheme.soundControlStyle, .switchTrack); XCTAssertEqual(macTheme.tabIndicatorStyle, .thumb)
        XCTAssertNil(macTheme.headerLeading(score: 0)); XCTAssertNil(macTheme.headerAccessory())
        XCTAssertNil(macTheme.headerTrailingAccessory(done: 1, total: 2, expanded: false))
        XCTAssertNil(macTheme.railContent(done: 1, total: 2, remaining: 1, score: 0, best: 0, streak: 0))
        XCTAssertNil(macTheme.composerPlaceholder(isToday: true))
    }
}
