import XCTest
import SwiftUI
import AppKit
@testable import OrdoThemes

/// Phase-2 contract tests for Zen Ink's pure data. Signature views and shared
/// view integration deliberately remain out of scope until their later phases.
final class ZenInkThemeDataTests: XCTestCase {
    private let theme = ZenInkTheme()

    private func components(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        let color = NSColor(color).usingColorSpace(.sRGB)!
        return (Double(color.redComponent), Double(color.greenComponent),
                Double(color.blueComponent), Double(color.alphaComponent))
    }

    private func assertColor(_ color: Color, _ hex: UInt32, alpha: Double = 1,
                             file: StaticString = #filePath, line: UInt = #line) {
        let actual = components(color)
        XCTAssertEqual(actual.r, Double((hex >> 16) & 0xFF) / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.g, Double((hex >> 8) & 0xFF) / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.b, Double(hex & 0xFF) / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.a, alpha, accuracy: 0.005, file: file, line: line)
    }

    private func assertRGBA(_ color: Color, _ r: Double, _ g: Double, _ b: Double, _ a: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        let actual = components(color)
        XCTAssertEqual(actual.r, r / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.g, g / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.b, b / 255, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.a, a, accuracy: 0.005, file: file, line: line)
    }

    private func assertToken(_ token: TypeToken, size: Double, weight: Font.Weight,
                             tracking: Double = 0, lineHeight: Double = 1.2,
                             italic: Bool = false, uppercase: Bool = false,
                             postScript: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(token.size, size, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(token.weight, weight, file: file, line: line)
        XCTAssertEqual(token.trackingEm, tracking, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(token.lineHeightMultiple, lineHeight, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(token.italic, italic, file: file, line: line)
        XCTAssertEqual(token.uppercase, uppercase, file: file, line: line)
        XCTAssertEqual(token.fontFamily, .postScript(postScript), file: file, line: line)
    }

    private func assertPluck(_ component: SoundComponent, frequency: Double, gain: Double, duration: Double,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard case let .pluck(pluck) = component else { return XCTFail("expected Pluck", file: file, line: line) }
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
    }

    // MARK: Identity and voice

    func testIdentityVoiceAndGreetingThresholds() {
        XCTAssertEqual(theme.id, .zenInk)
        XCTAssertEqual(theme.displayName, "Zen Ink")
        XCTAssertEqual(theme.todayTabLabel, "Today")
        XCTAssertEqual(theme.longtermTabLabel, "道")
        XCTAssertEqual(theme.doneSectionLabel, "済")
        XCTAssertEqual(theme.firstRunTitle, "始めましょう")
        XCTAssertEqual(theme.firstRunMessage, "Begin.")
        XCTAssertEqual(theme.allClearTitle, "日々是好日")
        XCTAssertEqual(theme.allClearMessage, "Every day, a good day.")

        XCTAssertEqual(theme.greeting(forHour: 0), "The night is still.")
        XCTAssertEqual(theme.greeting(forHour: 4), "The night is still.")
        XCTAssertEqual(theme.greeting(forHour: 5), "Begin gently.")
        XCTAssertEqual(theme.greeting(forHour: 11), "Begin gently.")
        XCTAssertEqual(theme.greeting(forHour: 12), "One thing at a time.")
        XCTAssertEqual(theme.greeting(forHour: 17), "One thing at a time.")
        XCTAssertEqual(theme.greeting(forHour: 18), "Let the day settle.")
        XCTAssertEqual(theme.greeting(forHour: 23), "Let the day settle.")
    }

    // MARK: Palette and paper surface

    func testLightPaletteExactSRGBMapping() {
        let p = theme.palette(for: .light)
        assertColor(p.ink, 0x231F19); assertColor(p.ink2, 0x514A3F)
        assertColor(p.ink3, 0x8A8071); assertColor(p.inkFaint, 0xA89E8D)
        assertRGBA(p.rowHover, 35, 31, 25, 0.08); assertRGBA(p.rowPress, 35, 31, 25, 0.08)
        XCTAssertEqual(components(p.fieldBackground).a, 0, accuracy: 0.001)
        assertRGBA(p.fieldLine, 35, 31, 25, 0.12)
        assertRGBA(p.segmentBackground, 35, 31, 25, 0.08); assertColor(p.segmentThumb, 0xFCF8EF)
        assertColor(p.accent, 0xC33A28); assertRGBA(p.accentSoft, 195, 58, 40, 0.18); assertColor(p.accentInk, 0xF8F3E8)
        assertColor(p.checkRing, 0x8A8071); assertRGBA(p.divider, 35, 31, 25, 0.07)
        assertRGBA(p.panelHairline, 35, 31, 25, 0.12); assertRGBA(p.panelHairlineOuter, 35, 31, 25, 0.12)
        assertRGBA(p.innerHighlight, 255, 255, 255, 0.6)
        XCTAssertEqual(p.hairlineWidth, 1, accuracy: 0.0001)
        XCTAssertEqual(p.segmentThumbShadow.count, 1)
        XCTAssertEqual(p.segmentThumbShadow[0], ShadowLayer(color: .rgba(0, 0, 0, 0.08), x: 0, y: 1, blur: 3))
        XCTAssertEqual(components(p.coin).a, 0); XCTAssertEqual(components(p.coinInk).a, 0)
        XCTAssertEqual(components(p.glow).a, 0); XCTAssertEqual(components(p.coinGlow).a, 0)
    }

    func testDarkPaletteExactSRGBMappingAndIndependentArtDirection() {
        let light = theme.palette(for: .light)
        let p = theme.palette(for: .dark)
        assertColor(p.ink, 0xCBD0DC); assertColor(p.ink2, 0xAEB4C3)
        assertColor(p.ink3, 0x7C8291); assertColor(p.inkFaint, 0x565C6D)
        assertRGBA(p.rowHover, 203, 208, 220, 0.10); assertRGBA(p.rowPress, 203, 208, 220, 0.10)
        XCTAssertEqual(components(p.fieldBackground).a, 0, accuracy: 0.001)
        assertRGBA(p.fieldLine, 203, 208, 220, 0.13)
        assertRGBA(p.segmentBackground, 203, 208, 220, 0.10); assertColor(p.segmentThumb, 0x1C2031)
        assertColor(p.accent, 0xDE5B49); assertRGBA(p.accentSoft, 222, 91, 73, 0.18); assertColor(p.accentInk, 0x181B28)
        assertColor(p.checkRing, 0x7C8291); assertRGBA(p.divider, 203, 208, 220, 0.06)
        assertRGBA(p.panelHairline, 203, 208, 220, 0.13); assertRGBA(p.panelHairlineOuter, 203, 208, 220, 0.13)
        assertRGBA(p.innerHighlight, 255, 255, 255, 0.05)
        XCTAssertEqual(p.hairlineWidth, 1, accuracy: 0.0001)
        XCTAssertNotEqual(components(p.ink).r, 1 - components(light.ink).r, accuracy: 0.02)
        XCTAssertNotEqual(components(p.accent).r, 1 - components(light.accent).r, accuracy: 0.02)
    }

    func testPaperSurfaceAndGrainAreExactInBothAppearances() {
        let light = theme.palette(for: .light)
        let dark = theme.palette(for: .dark)
        guard case let .paper(lightPaper) = light.surface, case let .paper(darkPaper) = dark.surface else {
            return XCTFail("Zen Ink must use paper, never vibrancy or cabinet")
        }
        assertColor(lightPaper.fillTop, 0xFCF8EF); assertColor(lightPaper.fillBottom, 0xF8F3E8)
        assertRGBA(lightPaper.border, 35, 31, 25, 0.12); assertRGBA(lightPaper.innerHighlight, 255, 255, 255, 0.6)
        XCTAssertEqual(lightPaper.borderWidth, 1, accuracy: 0.0001); XCTAssertEqual(lightPaper.cornerRadius, 22, accuracy: 0.0001)
        XCTAssertEqual(lightPaper.beakCornerRadius, 0, accuracy: 0.0001)
        XCTAssertEqual(lightPaper.shadow, light.panelShadow); XCTAssertEqual(lightPaper.shadow.count, 2)
        XCTAssertEqual(lightPaper.shadow[0], ShadowLayer(color: .rgba(74, 54, 26, 0.32), x: 0, y: 24, blur: 60))
        XCTAssertEqual(lightPaper.shadow[1], ShadowLayer(color: .rgba(74, 54, 26, 0.18), x: 0, y: 4, blur: 14))
        // The paper overlay renders the mockup's `--grain-op * 0.7` value.
        XCTAssertEqual(lightPaper.grain.opacity, 0.045 * 0.7, accuracy: 0.0001)
        XCTAssertEqual(lightPaper.grain.blend, .multiply); XCTAssertEqual(lightPaper.grain.tile, 170, accuracy: 0.0001)

        assertColor(darkPaper.fillTop, 0x1C2031); assertColor(darkPaper.fillBottom, 0x181B28)
        assertRGBA(darkPaper.border, 203, 208, 220, 0.13); assertRGBA(darkPaper.innerHighlight, 255, 255, 255, 0.05)
        XCTAssertEqual(darkPaper.borderWidth, 1, accuracy: 0.0001); XCTAssertEqual(darkPaper.cornerRadius, 22, accuracy: 0.0001)
        XCTAssertEqual(darkPaper.beakCornerRadius, 0, accuracy: 0.0001)
        XCTAssertEqual(darkPaper.shadow, dark.panelShadow); XCTAssertEqual(darkPaper.shadow.count, 2)
        XCTAssertEqual(darkPaper.shadow[0], ShadowLayer(color: .rgba(0, 0, 0, 0.72), x: 0, y: 30, blur: 70))
        XCTAssertEqual(darkPaper.shadow[1], ShadowLayer(color: .rgba(0, 0, 0, 0.50), x: 0, y: 6, blur: 18))
        XCTAssertEqual(darkPaper.grain.opacity, 0.05 * 0.7, accuracy: 0.0001)
        XCTAssertEqual(darkPaper.grain.blend, .overlay); XCTAssertEqual(darkPaper.grain.tile, 170, accuracy: 0.0001)
    }

    func testAccessibilityDeltasAreExact() {
        let normal = theme.palette(for: .light)
        let contrast = theme.palette(for: .light, accessibility: .init(increaseContrast: true))
        XCTAssertEqual(contrast.hairlineWidth, 1.5, accuracy: 0.0001)
        XCTAssertEqual(contrast.inkFaint, normal.ink3)
        guard case let .paper(paper) = contrast.surface else { return XCTFail("expected paper") }
        XCTAssertEqual(paper.borderWidth, 1.5, accuracy: 0.0001)
        for appearance in [ResolvedAppearance.light, .dark] {
            guard case let .paper(paper) = theme.palette(for: appearance, accessibility: .init(reduceTransparency: true)).surface else {
                return XCTFail("expected paper")
            }
            XCTAssertEqual(paper.grain.opacity, 0, accuracy: 0.0001)
        }
    }

    // MARK: Typography

    func testEverySharedTypeTokenUsesExactStaticPostScriptFace() {
        let t = theme.typeScale
        assertToken(t.greeting, size: 18, weight: .bold, tracking: 0.02, postScript: FontRegistrar.shipporiMinchoBold)
        assertToken(t.date, size: 12.5, weight: .regular, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(t.tab, size: 16, weight: .semibold, tracking: 0.04, lineHeight: 1.1, postScript: FontRegistrar.shipporiMinchoSemiBold)
        assertToken(t.tabCount, size: 9.5, weight: .medium, tracking: 0.26, postScript: FontRegistrar.zenKakuGothicNewMedium)
        assertToken(t.taskTitle, size: 15, weight: .regular, tracking: 0.01, lineHeight: 1.4, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(t.ageMarker, size: 10, weight: .medium, tracking: 0.10, postScript: FontRegistrar.zenKakuGothicNewMedium)
        assertToken(t.doneHeader, size: 10, weight: .medium, tracking: 0.28, uppercase: true, postScript: FontRegistrar.zenKakuGothicNewMedium)
        assertToken(t.field, size: 15, weight: .regular, tracking: 0.02, postScript: FontRegistrar.shipporiMinchoRegular)
        assertToken(t.emptyTitle, size: 21, weight: .semibold, tracking: 0.24, postScript: FontRegistrar.shipporiMinchoSemiBold)
        assertToken(t.emptyBody, size: 13.5, weight: .regular, tracking: 0.05, italic: true, postScript: FontRegistrar.shipporiMinchoRegular)
        assertToken(t.railKicker, size: 10, weight: .regular, tracking: 0.34, uppercase: true, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(t.ringNumber, size: 34, weight: .semibold, postScript: FontRegistrar.shipporiMinchoSemiBold)
        assertToken(t.ringSub, size: 10, weight: .regular, tracking: 0.34, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(t.railLine, size: 13, weight: .regular, tracking: 0.04, lineHeight: 2, postScript: FontRegistrar.shipporiMinchoRegular)
        assertToken(t.railLineValue, size: 14.5, weight: .regular, tracking: 0.14, postScript: FontRegistrar.shipporiMinchoRegular)
        assertToken(t.railQuote, size: 13, weight: .regular, tracking: 0.04, lineHeight: 2, postScript: FontRegistrar.shipporiMinchoRegular)
        assertToken(t.segmentButton, size: 10.5, weight: .medium, tracking: 0.12, uppercase: true, postScript: FontRegistrar.zenKakuGothicNewMedium)
    }

    func testZenOnlyTypeTokensAreExact() {
        assertToken(ZenInkTheme.wordmarkType, size: 23, weight: .bold, tracking: 0.03, lineHeight: 1, postScript: FontRegistrar.shipporiMinchoBold)
        assertToken(ZenInkTheme.headSubType, size: 9, weight: .regular, tracking: 0.34, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(ZenInkTheme.headCountType, size: 14, weight: .semibold, lineHeight: 1, postScript: FontRegistrar.shipporiMinchoSemiBold)
        assertToken(ZenInkTheme.tabSubType, size: 9.5, weight: .regular, tracking: 0.26, uppercase: true, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(ZenInkTheme.railVertType, size: 24, weight: .semibold, tracking: 0.28, postScript: FontRegistrar.shipporiMinchoSemiBold)
        assertToken(ZenInkTheme.railVertSmallType, size: 11, weight: .regular, tracking: 0.30, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(ZenInkTheme.backLinkType, size: 10.5, weight: .regular, tracking: 0.28, uppercase: true, postScript: FontRegistrar.zenKakuGothicNewRegular)
        assertToken(ZenInkTheme.sealCharType, size: 21, weight: .bold, postScript: FontRegistrar.shipporiMinchoExtraBold)
    }

    // MARK: Metrics, layout and motion

    func testMetricsAndLayoutTranscribeEverySharedRegion() {
        let m = theme.metrics; let l = theme.layout
        XCTAssertEqual(m.panelCompactSize, CGSize(width: 380, height: 568)); XCTAssertEqual(m.panelExpandedSize, CGSize(width: 604, height: 568))
        XCTAssertEqual(m.panelCornerRadius, 22); XCTAssertEqual(m.railWidth, 194); XCTAssertEqual(m.mainColumnWidth, 380)
        XCTAssertEqual(m.ringRadius, 46.2); XCTAssertEqual(m.ringStrokeWidth, 6.05); XCTAssertEqual(m.compactRingDiameter, 38); XCTAssertEqual(m.compactRingStrokeWidth, 2.22)
        XCTAssertEqual(m.rowCornerRadius, 12); XCTAssertEqual(m.checkboxSize, 24); XCTAssertEqual(m.beakSize, 14); XCTAssertEqual(m.borderWidth, 1); XCTAssertEqual(m.progressSegments, 0); XCTAssertEqual(m.notchInsetFromRight, 26)
        XCTAssertEqual(l.railInsets, ThemeInsets(top: 30, leading: 22, bottom: 26, trailing: 22)); XCTAssertEqual(l.mainColumnInsets, ThemeInsets(top: 22, leading: 24, bottom: 0, trailing: 24))
        XCTAssertEqual(l.headerInsets, .zero); XCTAssertEqual(l.headerContentSpacing, 10); XCTAssertEqual(l.headerControlsSpacing, 8); XCTAssertEqual(l.headerTextSpacing, 11); XCTAssertEqual(l.headerTrailingAccessorySpacing, 8)
        XCTAssertEqual(l.dividerInsets, ThemeInsets(top: 16, bottom: 4)); XCTAssertEqual(l.dividerHeight, 12)
        XCTAssertEqual(l.tabInsets, ThemeInsets(top: 8, bottom: 2)); XCTAssertEqual(l.tabHeight, 54); XCTAssertEqual(l.tabCornerRadius, 0); XCTAssertEqual(l.tabThumbInset, 0); XCTAssertEqual(l.tabTrackCornerRadius, 0); XCTAssertEqual(l.tabCellInsets, ThemeInsets(top: 9, leading: 4, bottom: 13, trailing: 4)); XCTAssertEqual(l.tabSublineSpacing, 3); XCTAssertEqual(l.tabIndicatorHeight, 9); XCTAssertEqual(l.tabIndicatorBottomInset, 2)
        XCTAssertEqual(l.stageTopSpacing, 6); XCTAssertEqual(l.listInsets, ThemeInsets(top: 6, leading: 2, bottom: 12, trailing: 2))
        XCTAssertEqual(l.rowInsets, ThemeInsets(top: 11, leading: 8, bottom: 11, trailing: 8)); XCTAssertEqual(l.rowContentSpacing, 13); XCTAssertEqual(l.rowTitleTrailingReserve, 62)
        XCTAssertEqual(l.composerInsets, ThemeInsets(top: 14, leading: 8, bottom: 12, trailing: 8)); XCTAssertEqual(l.composerStackSpacing, 12); XCTAssertEqual(l.composerFieldSpacing, 12); XCTAssertEqual(l.composerFieldInsets, .zero); XCTAssertEqual(l.composerFieldMinimumHeight, 0)
        XCTAssertEqual(l.footerInsets, ThemeInsets(top: 12, leading: 6, bottom: 18, trailing: 6)); XCTAssertEqual(l.footerContentSpacing, 0)
        XCTAssertEqual(l.clearedIconBottomSpacing, 22); XCTAssertEqual(l.clearedBodyTopSpacing, 10); XCTAssertEqual(l.clearedPeekTopSpacing, 26); XCTAssertTrue(l.clearedStateFillsAvailableSpace)
    }

    func testEveryNamedMotionAndCompletionSequenceIsExact() {
        let m = theme.motion
        let expected: [(MotionToken, Double, MotionCurve)] = [(m.panelEnter, 0.520, .easeOut), (m.panelExit, 0.280, .easeOut), (m.expandMorph, 0.620, .easeDrawer), (m.tabThumb, 0.420, .easeDrawer), (m.appearanceThumb, 0.380, .easeDrawer), (m.soundKnob, 0.240, .easeOut), (m.checkboxFill, 0.420, .easeOut), (m.tickDraw, 0.360, .easeOut), (m.strikethrough, 0.560, .easeOut), (m.titleColorFade, 0.460, .easeOut), (m.rowEntrance, 0.500, .easeOut), (m.flipMove, 0.500, .easeOut), (m.ring, 0.950, .easeIO), (m.appearanceCrossfade, 0.600, .easeOut), (m.hoverFade, 0.240, .easeOut), (m.pressEcho, 0.160, .easeOut), (m.counterFade, 0.220, .easeOut)]
        for (token, duration, curve) in expected { XCTAssertEqual(token.duration, duration, accuracy: 0.0001); XCTAssertEqual(token.curve, curve) }
        XCTAssertEqual(m.panelEnterBlur, 0); XCTAssertEqual(m.panelExitBlur, 0)
        let sequence = m.checkboxSequence
        XCTAssertEqual(sequence.fillDuration, 0.420); XCTAssertEqual(sequence.fillKeyframes, [.init(scale: 0.2, fraction: 0), .init(scale: 1, fraction: 1)])
        XCTAssertEqual(sequence.tickDrawDuration, 0.360); XCTAssertEqual(sequence.tickDrawDelay, 0); XCTAssertEqual(sequence.fillFadeDuration, 0.360); XCTAssertEqual(sequence.ringFadeDuration, 0.300); XCTAssertEqual(sequence.completeReflowDelay, 0); XCTAssertEqual(sequence.uncheckReflowDelay, 0)
        XCTAssertEqual(m.rowEntranceTransform, RowEntranceTransform(translateY: -10, scale: 1, duration: 0.5, blur: 6))
    }

    // MARK: Sound

    func testAllEightEventsAndSixAddVariantsArePresent() {
        XCTAssertEqual(Set(theme.soundSet.events), Set(SoundEvent.allCases))
        XCTAssertEqual(theme.soundSet.events.count, 8)
        XCTAssertEqual(theme.soundSet.variants(for: .add).count, 6)
        for event in SoundEvent.allCases { XCTAssertFalse(theme.soundSet.variants(for: event).isEmpty, "missing \(event)") }
    }

    func testSoundRecipesAndComponentsAreExact() {
        let complete = theme.soundSet[.complete]!
        XCTAssertEqual(complete.components.count, 2)
        guard case let .oscillator(wood) = complete.components[0], case let .noise(knock) = complete.components[1] else { return XCTFail("complete must be tone plus knock") }
        XCTAssertEqual(wood.wave, .sine); XCTAssertEqual(wood.frequency, 820); XCTAssertEqual(wood.glideTo, 300); XCTAssertEqual(wood.duration, 0.160); XCTAssertEqual(wood.peakGain, 0.20); XCTAssertEqual(wood.attack, 0.004)
        XCTAssertEqual(knock.duration, 0.040); XCTAssertEqual(knock.peakGain, 0.10); XCTAssertEqual(knock.bandpassStart, 1_900); XCTAssertEqual(knock.bandpassEnd, 1_900); XCTAssertEqual(knock.q, 1.1)
        let pitches: [Double] = [261.63, 293.66, 349.23, 392, 440, 523.25]
        for (recipe, pitch) in zip(theme.soundSet.variants(for: .add), pitches) { XCTAssertEqual(recipe.components.count, 1); assertPluck(recipe.components[0], frequency: pitch, gain: 0.15, duration: 1) }
        assertPluck(theme.soundSet[.uncheck]!.components[0], frequency: 174.61, gain: 0.09, duration: 0.7)
        assertPluck(theme.soundSet[.tabSwitch]!.components[0], frequency: 392, gain: 0.075, duration: 0.5)
        for (event, start, end, gain, duration, pitch) in [(SoundEvent.panelOpen, 500.0, 2_200.0, 0.045, 0.5, 293.66), (.panelClose, 2_000, 450, 0.04, 0.36, 220)] {
            let recipe = theme.soundSet[event]!
            guard case let .noise(noise) = recipe.components[0] else { return XCTFail("\(event) must begin with noise") }
            XCTAssertEqual(noise.bandpassStart, start); XCTAssertEqual(noise.bandpassEnd, end); XCTAssertEqual(noise.q, 0.8); XCTAssertEqual(noise.peakGain, gain); XCTAssertEqual(noise.duration, duration)
            assertPluck(recipe.components[1], frequency: pitch, gain: 0.06, duration: 0.6)
        }
        for (event, gain) in [(SoundEvent.toggleOn, 0.09), (.toggleOff, 0.06)] {
            guard case let .oscillator(tick) = theme.soundSet[event]!.components[0] else { return XCTFail("\(event) must be a wood tick") }
            XCTAssertEqual(tick.wave, .sine); XCTAssertEqual(tick.frequency, 1_400); XCTAssertEqual(tick.glideTo, 700); XCTAssertEqual(tick.duration, 0.06); XCTAssertEqual(tick.peakGain, gain); XCTAssertEqual(tick.attack, 0.003)
        }
    }

    // MARK: Structural capabilities and Phase-2 registry isolation

    func testStructuralCapabilitiesAndMacOSDefaultsRemainDistinct() {
        XCTAssertFalse(theme.showsDoneSection); XCTAssertFalse(theme.showsTabCountBadge); XCTAssertTrue(theme.clearedStateCoversList); XCTAssertTrue(theme.clearedStateIsPeekable); XCTAssertTrue(theme.mainColumnFlexes)
        XCTAssertEqual(theme.composerStyle, .ink); XCTAssertEqual(theme.appearanceSegmentStyle, .labelOnly); XCTAssertEqual(theme.soundControlStyle, .ghostIcon); XCTAssertEqual(theme.tabIndicatorStyle, .custom)
        let mac = MacOSTheme()
        XCTAssertTrue(mac.showsDoneSection); XCTAssertTrue(mac.showsTabCountBadge); XCTAssertFalse(mac.clearedStateCoversList); XCTAssertFalse(mac.clearedStateIsPeekable); XCTAssertFalse(mac.mainColumnFlexes)
        XCTAssertEqual(mac.composerStyle, .card); XCTAssertEqual(mac.appearanceSegmentStyle, .iconAndLabel); XCTAssertEqual(mac.soundControlStyle, .switchTrack); XCTAssertEqual(mac.tabIndicatorStyle, .thumb)
    }

}
