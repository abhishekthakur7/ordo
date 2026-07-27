import XCTest
import SwiftUI
import AppKit
@testable import OrdoThemes

final class MacOSThemeTests: XCTestCase {

    let theme = MacOSTheme()

    // MARK: Helpers

    private func comps(_ c: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        let ns = NSColor(c).usingColorSpace(.sRGB)!
        return (Double(ns.redComponent), Double(ns.greenComponent),
                Double(ns.blueComponent), Double(ns.alphaComponent))
    }

    // MARK: Palette spot-checks (light vs dark, exact mockup values)

    func testAccentMatchesMockupAndDiffersLightVsDark() {
        let light = comps(theme.palette(for: .light).accent)
        let dark = comps(theme.palette(for: .dark).accent)
        // light #0a7bff, dark #0a84ff
        XCTAssertEqual(light.r, 10.0 / 255, accuracy: 0.005)
        XCTAssertEqual(light.g, 123.0 / 255, accuracy: 0.005)
        XCTAssertEqual(light.b, 1.0, accuracy: 0.005)
        XCTAssertEqual(dark.g, 132.0 / 255, accuracy: 0.005)
        XCTAssertNotEqual(light.g, dark.g, accuracy: 0.02) // independently art-directed
    }

    func testInkDiffersLightVsDark() {
        let light = comps(theme.palette(for: .light).ink) // #16171c
        let dark = comps(theme.palette(for: .dark).ink)   // #f3f3f6
        XCTAssertEqual(light.r, 22.0 / 255, accuracy: 0.005)
        XCTAssertEqual(dark.r, 243.0 / 255, accuracy: 0.005)
        XCTAssertGreaterThan(dark.r, light.r) // dark ink is light-on-dark
    }

    func testCheckRingAndDividerAlphaMatchMockup() {
        let light = theme.palette(for: .light)
        XCTAssertEqual(comps(light.checkRing).a, 0.24, accuracy: 0.01)
        XCTAssertEqual(comps(light.divider).a, 0.08, accuracy: 0.01)
        let dark = theme.palette(for: .dark)
        XCTAssertEqual(comps(dark.checkRing).a, 0.28, accuracy: 0.01)
    }

    // MARK: Accessibility

    func testReduceTransparencyUsesOpaqueFallback() {
        let normal = theme.palette(for: .light, accessibility: .standard)
        XCTAssertFalse(normal.material.usesFallback)
        let reduced = theme.palette(for: .light,
                                    accessibility: AccessibilityOptions(reduceTransparency: true))
        XCTAssertTrue(reduced.material.usesFallback)
        // fallback is fully opaque
        XCTAssertEqual(comps(reduced.material.fallbackOpaque).a, 1.0, accuracy: 0.001)
    }

    func testIncreaseContrastThickensHairlinesAndDeepensGrays() {
        let normal = theme.palette(for: .light)
        let bumped = theme.palette(for: .light,
                                   accessibility: AccessibilityOptions(increaseContrast: true))
        XCTAssertEqual(normal.hairlineWidth, 0.5, accuracy: 0.001)
        XCTAssertEqual(bumped.hairlineWidth, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(comps(bumped.ink2).a, comps(normal.ink2).a)
        XCTAssertGreaterThan(comps(bumped.divider).a, comps(normal.divider).a)
    }

    func testMaterialCarriesCSSNumbers() {
        let m = theme.palette(for: .dark).material
        XCTAssertEqual(m.blurRadius, 40, accuracy: 0.001)
        XCTAssertEqual(m.saturation, 1.8, accuracy: 0.001)
        XCTAssertTrue(m.vibrancy)
    }

    // MARK: Motion tokens

    func testNamedMotionDurations() {
        let m = theme.motion
        XCTAssertEqual(m.expandMorph.duration, 0.520, accuracy: 0.0001)
        XCTAssertEqual(m.tabThumb.duration, 0.460, accuracy: 0.0001)
        // Footer controls: appearance thumb 420ms, sound knob 320ms — both drawer curve.
        XCTAssertEqual(m.appearanceThumb.duration, 0.420, accuracy: 0.0001)
        XCTAssertEqual(m.appearanceThumb.curve, .easeDrawer)
        XCTAssertEqual(m.soundKnob.duration, 0.320, accuracy: 0.0001)
        XCTAssertEqual(m.soundKnob.curve, .easeDrawer)
        XCTAssertEqual(m.checkboxFill.duration, 0.380, accuracy: 0.0001)
        XCTAssertEqual(m.tickDraw.duration, 0.260, accuracy: 0.0001)
        XCTAssertEqual(m.tickDraw.delay, 0.040, accuracy: 0.0001)
        XCTAssertEqual(m.strikethrough.duration, 0.340, accuracy: 0.0001)
        XCTAssertEqual(m.rowEntrance.duration, 0.360, accuracy: 0.0001)
        XCTAssertEqual(m.flipMove.duration, 0.440, accuracy: 0.0001)
        XCTAssertEqual(m.ring.duration, 0.700, accuracy: 0.0001)
        XCTAssertEqual(m.appearanceCrossfade.duration, 0.600, accuracy: 0.0001)
        XCTAssertEqual(m.panelEnter.duration, 0.340, accuracy: 0.0001)
        XCTAssertEqual(m.panelExit.duration, 0.220, accuracy: 0.0001)
        // Micro-motion tokens (row hover, press echo, character counter) — mockup values.
        XCTAssertEqual(m.hoverFade.duration, 0.160, accuracy: 0.0001)
        XCTAssertEqual(m.pressEcho.duration, 0.130, accuracy: 0.0001)
        XCTAssertEqual(m.counterFade.duration, 0.200, accuracy: 0.0001)
        XCTAssertEqual(m.hoverFade.curve, .easeOut)
        XCTAssertEqual(m.pressEcho.curve, .easeOut)
        XCTAssertEqual(m.counterFade.curve, .easeOut)
    }

    func testMotionCurveControlPoints() {
        XCTAssertEqual(MotionCurve.easeOut.controlPoints!.0, 0.23, accuracy: 0.0001)
        XCTAssertEqual(MotionCurve.easeDrawer.controlPoints!.1, 0.72, accuracy: 0.0001)
        XCTAssertEqual(MotionCurve.easeIO.controlPoints!.2, 0.175, accuracy: 0.0001)
        XCTAssertNil(MotionCurve.linear.controlPoints)
    }

    func testReduceMotionVariantsExistAndAreCapped() {
        // Every long moment has a distinct, capped reduced variant (a fade).
        XCTAssertEqual(theme.motion.ring.reducedDuration, 0.2, accuracy: 0.0001)         // capped from 0.70
        XCTAssertEqual(theme.motion.expandMorph.reducedDuration, 0.2, accuracy: 0.0001)  // capped from 0.52
        XCTAssertEqual(theme.motion.panelExit.reducedDuration, 0.2, accuracy: 0.0001)    // 0.22 -> 0.2
        // Short moments are left as-is.
        XCTAssertEqual(theme.motion.tickDraw.reducedDuration, 0.2, accuracy: 0.0001)     // 0.26 -> 0.2
        // The animation accessor returns without crashing for both states.
        _ = theme.motion.checkboxFill.animation(reduceMotion: true)
        _ = theme.motion.checkboxFill.animation(reduceMotion: false)
    }

    func testCheckboxSequenceKeyframes() {
        let seq = theme.motion.checkboxSequence
        XCTAssertEqual(seq.fillDuration, 0.380, accuracy: 0.0001)
        XCTAssertEqual(seq.fillKeyframes.count, 4)
        XCTAssertEqual(seq.fillKeyframes[1].scale, 1.16, accuracy: 0.0001) // overshoot
        XCTAssertEqual(seq.fillKeyframes[1].fraction, 0.55, accuracy: 0.0001)
        XCTAssertEqual(seq.fillKeyframes[2].scale, 0.94, accuracy: 0.0001) // undershoot
        XCTAssertEqual(seq.fillKeyframes[3].scale, 1.00, accuracy: 0.0001)
        XCTAssertEqual(seq.tickDrawDelay, 0.040, accuracy: 0.0001)
        XCTAssertEqual(seq.completeReflowDelay, 0.470, accuracy: 0.0001)
        XCTAssertEqual(seq.uncheckReflowDelay, 0.230, accuracy: 0.0001)
    }

    func testRowEntranceTransform() {
        let r = theme.motion.rowEntranceTransform
        XCTAssertEqual(r.translateY, -8, accuracy: 0.0001)
        XCTAssertEqual(r.scale, 0.96, accuracy: 0.0001)
        XCTAssertEqual(r.duration, 0.360, accuracy: 0.0001)
    }

    // MARK: Sound recipes (all 8 events, exact mockup numbers)

    func testAllEventsHaveRecipes() {
        for e in SoundEvent.allCases {
            XCTAssertNotNil(theme.soundSet[e], "missing recipe for \(e)")
        }
        XCTAssertEqual(theme.soundSet.events.count, 8)
    }

    func testCompleteRecipeIsTwoMarimbaHits() {
        let r = theme.soundSet[.complete]!
        XCTAssertEqual(r.components.count, 2)
        guard case let .marimba(m1) = r.components[0],
              case let .marimba(m2) = r.components[1] else {
            return XCTFail("expected two marimba components")
        }
        XCTAssertEqual(m1.frequency, 523.25, accuracy: 0.001)
        XCTAssertEqual(m1.peakGain, 0.11, accuracy: 0.0001)
        XCTAssertEqual(m1.startDelay, 0.0, accuracy: 0.0001)
        XCTAssertEqual(m2.frequency, 783.99, accuracy: 0.001)
        XCTAssertEqual(m2.peakGain, 0.10, accuracy: 0.0001)
        XCTAssertEqual(m2.startDelay, 0.11, accuracy: 0.0001)
        // marimba composite params from the mockup
        XCTAssertEqual(m1.partialRatio, 2.01, accuracy: 0.0001)
        XCTAssertEqual(m1.partialGain, 0.28, accuracy: 0.0001)
        XCTAssertEqual(m1.lowpassRatio, 4.2, accuracy: 0.0001)
        XCTAssertEqual(m1.attack, 0.006, accuracy: 0.0001)
        XCTAssertEqual(m1.decay, 0.42, accuracy: 0.0001)
    }

    func testUncheckRecipe() {
        let r = theme.soundSet[.uncheck]!
        guard case let .oscillator(o) = r.components[0] else { return XCTFail() }
        XCTAssertEqual(o.wave, .sine)
        XCTAssertEqual(o.frequency, 440, accuracy: 0.001)
        XCTAssertEqual(o.glideTo!, 262, accuracy: 0.001)
        XCTAssertEqual(o.duration, 0.16, accuracy: 0.0001)
        XCTAssertEqual(o.peakGain, 0.05, accuracy: 0.0001)
    }

    func testAddRecipeIsTwoTones() {
        let r = theme.soundSet[.add]!
        XCTAssertEqual(r.components.count, 2)
        guard case let .oscillator(a) = r.components[0],
              case let .oscillator(b) = r.components[1] else { return XCTFail() }
        XCTAssertEqual(a.wave, .sine)
        XCTAssertEqual(a.frequency, 300, accuracy: 0.001)
        XCTAssertEqual(a.glideTo!, 560, accuracy: 0.001)
        XCTAssertEqual(b.wave, .triangle)
        XCTAssertEqual(b.startDelay, 0.02, accuracy: 0.0001)
        XCTAssertEqual(b.frequency, 600, accuracy: 0.001)
        XCTAssertEqual(b.glideTo!, 900, accuracy: 0.001)
        XCTAssertEqual(b.peakGain, 0.03, accuracy: 0.0001)
    }

    func testTabSwitchRecipeHasNoGlide() {
        let r = theme.soundSet[.tabSwitch]!
        guard case let .oscillator(o) = r.components[0] else { return XCTFail() }
        XCTAssertEqual(o.frequency, 880, accuracy: 0.001)
        XCTAssertNil(o.glideTo)
        XCTAssertEqual(o.duration, 0.05, accuracy: 0.0001)
        XCTAssertEqual(o.peakGain, 0.04, accuracy: 0.0001)
    }

    func testPanelOpenAndCloseSwooshes() {
        let open = theme.soundSet[.panelOpen]!
        guard case let .noise(n1) = open.components[0] else { return XCTFail() }
        XCTAssertEqual(n1.bandpassStart, 400, accuracy: 0.001) // rising
        XCTAssertEqual(n1.bandpassEnd, 1400, accuracy: 0.001)
        XCTAssertEqual(n1.q, 0.8, accuracy: 0.0001)
        XCTAssertEqual(n1.duration, 0.16, accuracy: 0.0001)
        XCTAssertTrue(n1.amplitudeTaperLinear)

        let close = theme.soundSet[.panelClose]!
        guard case let .noise(n2) = close.components[0] else { return XCTFail() }
        XCTAssertEqual(n2.bandpassStart, 1200, accuracy: 0.001) // falling
        XCTAssertEqual(n2.bandpassEnd, 420, accuracy: 0.001)
    }

    func testToggleRecipes() {
        let on = theme.soundSet[.toggleOn]!
        guard case let .oscillator(o1) = on.components[0] else { return XCTFail() }
        XCTAssertEqual(o1.wave, .triangle)
        XCTAssertEqual(o1.frequency, 760, accuracy: 0.001)
        XCTAssertEqual(o1.glideTo!, 1180, accuracy: 0.001)
        XCTAssertEqual(o1.peakGain, 0.045, accuracy: 0.0001)

        let off = theme.soundSet[.toggleOff]!
        guard case let .oscillator(o2) = off.components[0] else { return XCTFail() }
        XCTAssertEqual(o2.frequency, 1180, accuracy: 0.001)
        XCTAssertEqual(o2.glideTo!, 720, accuracy: 0.001)
        XCTAssertEqual(o2.peakGain, 0.04, accuracy: 0.0001)
    }

    // MARK: Type scale

    func testTypeScaleSpotChecks() {
        let ts = theme.typeScale
        XCTAssertEqual(ts.greeting.size, 19, accuracy: 0.001)
        XCTAssertEqual(ts.greeting.weight, .bold)
        XCTAssertEqual(ts.greeting.trackingEm, -0.02, accuracy: 0.0001)
        XCTAssertEqual(ts.taskTitle.size, 14, accuracy: 0.001)
        XCTAssertEqual(ts.taskTitle.lineHeightMultiple, 1.3, accuracy: 0.0001)
        XCTAssertEqual(ts.ringNumber.size, 30, accuracy: 0.001)
        XCTAssertTrue(ts.ringNumber.monospacedDigit)
        XCTAssertTrue(ts.doneHeader.uppercase)
        // tracking conversion
        XCTAssertEqual(ts.greeting.trackingPoints, 19 * -0.02, accuracy: 0.0001)
    }

    // MARK: Metrics

    func testMetricsMatchMockup() {
        let m = theme.metrics
        XCTAssertEqual(m.panelCompactSize.width, 380)
        XCTAssertEqual(m.panelCompactSize.height, 566)
        XCTAssertEqual(m.panelExpandedSize.width, 606)
        XCTAssertEqual(m.panelExpandedSize.height, 588)
        XCTAssertEqual(m.panelCornerRadius, 20)
        XCTAssertEqual(m.railWidth, 226)
        XCTAssertEqual(m.ringRadius, 56)
        XCTAssertEqual(m.ringStrokeWidth, 9)
        XCTAssertEqual(m.checkboxSize, 22)
    }

    // MARK: Identity & display strings (theme voice)

    func testDisplayStringsAndGreetingThresholds() {
        XCTAssertEqual(theme.longtermTabLabel, "Horizon")
        XCTAssertEqual(theme.todayTabLabel, "Today")
        XCTAssertEqual(theme.greeting(forHour: 2), "Still up?")
        XCTAssertEqual(theme.greeting(forHour: 9), "Good morning.")
        XCTAssertEqual(theme.greeting(forHour: 14), "Good afternoon.")
        XCTAssertEqual(theme.greeting(forHour: 21), "Good evening.")
        XCTAssertEqual(theme.allClearTitle, "All clear for today")
    }

    // MARK: Menu-bar glyph

    func testMenuBarGlyphIsTemplateImage() {
        let img = theme.menuBarGlyphImage()
        XCTAssertTrue(img.isTemplate)
        XCTAssertEqual(img.size.width, 18, accuracy: 0.001)
        let custom = theme.menuBarGlyphImage(pointSize: 32)
        XCTAssertEqual(custom.size.width, 32, accuracy: 0.001)
    }

    // MARK: Registry

    func testRegistryDefaultAndLookup() {
        let reg = ThemeRegistry.shared
        XCTAssertEqual(reg.defaultTheme.id, .macOS)
        XCTAssertEqual(reg.all.count, 3)
        XCTAssertEqual(reg.theme(id: .macOS)?.id, .macOS)
        XCTAssertEqual(reg.theme(id: .arcade)?.id, .arcade) // now shipped
        XCTAssertEqual(reg.theme(id: .zenInk)?.id, .zenInk)
        XCTAssertEqual(reg.theme(idOrDefault: .swiss).id, .macOS) // still reserved, falls back
    }
}
