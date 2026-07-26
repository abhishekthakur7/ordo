import SwiftUI
import AppKit

/// Ordo's default theme: native macOS vibrancy/glass, SF type, physical motion, marimba
/// confirmations, transcribed from `mockups/02-macos-glass.html`. A stateless `Sendable` value
/// (palettes/tokens computed), so one shared instance is safe to inject and swap live.
public struct MacOSTheme: Theme {

    public init() {}

    // MARK: Identity

    public let id: ThemeID = .macOS
    public let displayName = "macOS"

    // MARK: Display strings (theme voice)

    public func greeting(forHour hour: Int) -> String {
        if hour < 5 { return "Still up?" }
        if hour < 12 { return "Good morning." }
        if hour < 18 { return "Good afternoon." }
        return "Good evening."
    }

    public let todayTabLabel = "Today"
    public let longtermTabLabel = "Horizon"
    public let doneSectionLabel = "Completed"
    public let firstRunTitle = "A clean slate."
    public let firstRunMessage = "Add your first task below. Ordo keeps today in view — and quietly carries anything unfinished into tomorrow."
    public let allClearTitle = "All clear for today"
    public let allClearMessage = "Every task is done. Enjoy the rest of your day — you earned the quiet."

    // MARK: Palette

    public func palette(for appearance: ResolvedAppearance, accessibility: AccessibilityOptions) -> Palette {
        var p = (appearance == .dark) ? Self.darkBase : Self.lightBase

        if accessibility.increaseContrast {
            Self.applyIncreaseContrast(&p, appearance: appearance)
        }
        if accessibility.reduceTransparency {
            p.material.usesFallback = true
        }
        return p
    }

    // MARK: Tokens

    public let typeScale = Self.macTypeScale
    public let motion = Self.macMotion
    public let metrics = Self.macMetrics
    public let soundSet = Self.macSoundSet
}

// MARK: - Palettes (exact CSS transcription)

extension MacOSTheme {

    /// Light — the resolved default palette.
    static let lightBase = Palette(
        ink: .hex(0x16171C),
        ink2: .rgba(24, 25, 32, 0.62),
        ink3: .rgba(24, 25, 32, 0.40),
        inkFaint: .rgba(24, 25, 32, 0.09),
        rowHover: .rgba(20, 22, 44, 0.045),
        rowPress: .rgba(20, 22, 44, 0.08),
        fieldBackground: .rgba(255, 255, 255, 0.60),
        fieldLine: .rgba(20, 22, 44, 0.10),
        segmentBackground: .rgba(20, 22, 44, 0.06),
        segmentThumb: .rgba(255, 255, 255, 0.95),
        segmentThumbShadow: [
            ShadowLayer(color: .rgba(20, 22, 44, 0.18), x: 0, y: 1, blur: 3),
            ShadowLayer(color: .rgba(20, 22, 44, 0.06), x: 0, y: 1, blur: 1),
        ],
        accent: .hex(0x0A7BFF),
        accentSoft: .rgba(10, 123, 255, 0.14),
        accentInk: .hex(0xFFFFFF),
        checkRing: .rgba(20, 22, 44, 0.24),
        divider: .rgba(20, 22, 44, 0.08),
        material: MaterialIntent(
            blurRadius: 40,
            saturation: 1.8,
            vibrancy: true,
            tint: .rgba(250, 250, 252, 0.66),
            sheen: .rgba(255, 255, 255, 0.50),
            fallbackOpaque: .hex(0xF2F2F6),
            usesFallback: false,
            material: .popover,
            blending: .behindWindow
        ),
        panelHairline: .rgba(255, 255, 255, 0.75),
        panelHairlineOuter: .rgba(0, 0, 0, 0.08),
        innerHighlight: .rgba(255, 255, 255, 0.90),
        panelShadow: [
            ShadowLayer(color: .rgba(20, 22, 40, 0.05), x: 0, y: 1, blur: 1),
            ShadowLayer(color: .rgba(24, 26, 54, 0.14), x: 0, y: 14, blur: 30),
            ShadowLayer(color: .rgba(24, 26, 54, 0.12), x: 0, y: 34, blur: 68),
        ],
        hairlineWidth: 0.5
    )

    /// Dark — true macOS vibrancy, independently art-directed.
    static let darkBase = Palette(
        ink: .hex(0xF3F3F6),
        ink2: .rgba(240, 240, 246, 0.60),
        ink3: .rgba(240, 240, 246, 0.38),
        inkFaint: .rgba(255, 255, 255, 0.10),
        rowHover: .rgba(255, 255, 255, 0.055),
        rowPress: .rgba(255, 255, 255, 0.10),
        fieldBackground: .rgba(255, 255, 255, 0.06),
        fieldLine: .rgba(255, 255, 255, 0.11),
        segmentBackground: .rgba(255, 255, 255, 0.08),
        segmentThumb: .rgba(120, 120, 132, 0.55),
        segmentThumbShadow: [
            ShadowLayer(color: .rgba(0, 0, 0, 0.50), x: 0, y: 1, blur: 2),
        ],
        accent: .hex(0x0A84FF),
        accentSoft: .rgba(10, 132, 255, 0.24),
        accentInk: .hex(0xFFFFFF),
        checkRing: .rgba(255, 255, 255, 0.28),
        divider: .rgba(255, 255, 255, 0.09),
        material: MaterialIntent(
            blurRadius: 40,
            saturation: 1.8,
            vibrancy: true,
            tint: .rgba(28, 28, 34, 0.56),
            sheen: .rgba(60, 60, 74, 0.24),
            fallbackOpaque: .hex(0x1C1C22),
            usesFallback: false,
            material: .hudWindow,
            blending: .behindWindow
        ),
        panelHairline: .rgba(255, 255, 255, 0.10),
        panelHairlineOuter: .rgba(0, 0, 0, 0.50),
        innerHighlight: .rgba(255, 255, 255, 0.08),
        panelShadow: [
            ShadowLayer(color: .rgba(0, 0, 0, 0.40), x: 0, y: 2, blur: 6),
            ShadowLayer(color: .rgba(0, 0, 0, 0.62), x: 0, y: 22, blur: 60),
            ShadowLayer(color: .rgba(0, 0, 0, 0.50), x: 0, y: 40, blur: 90),
        ],
        hairlineWidth: 0.5
    )

    /// Increase-Contrast: thicken hairlines, deepen muted grays and structure.
    static func applyIncreaseContrast(_ p: inout Palette, appearance: ResolvedAppearance) {
        p.hairlineWidth = 1.0
        if appearance == .dark {
            p.ink2 = .rgba(240, 240, 246, 0.80)
            p.ink3 = .rgba(240, 240, 246, 0.56)
            p.divider = .rgba(255, 255, 255, 0.18)
            p.checkRing = .rgba(255, 255, 255, 0.44)
            p.fieldLine = .rgba(255, 255, 255, 0.22)
        } else {
            p.ink2 = .rgba(24, 25, 32, 0.82)
            p.ink3 = .rgba(24, 25, 32, 0.58)
            p.divider = .rgba(20, 22, 44, 0.18)
            p.checkRing = .rgba(20, 22, 44, 0.42)
            p.fieldLine = .rgba(20, 22, 44, 0.22)
        }
    }
}

// MARK: - Type scale (exact CSS transcription)

extension MacOSTheme {
    static let macTypeScale = TypeScale(
        greeting: TypeToken(size: 19, weight: .bold, trackingEm: -0.02, lineHeightMultiple: 1.1),
        date: TypeToken(size: 12.5, weight: .medium),
        tab: TypeToken(size: 13, weight: .semibold, trackingEm: -0.01),
        tabCount: TypeToken(size: 11, weight: .semibold, monospacedDigit: true),
        taskTitle: TypeToken(size: 14, weight: .medium, trackingEm: -0.01, lineHeightMultiple: 1.3),
        ageMarker: TypeToken(size: 11, weight: .semibold, monospacedDigit: true),
        doneHeader: TypeToken(size: 11, weight: .semibold, trackingEm: 0.08, uppercase: true),
        field: TypeToken(size: 14, weight: .medium, trackingEm: -0.01),
        emptyTitle: TypeToken(size: 15.5, weight: .bold, trackingEm: -0.01),
        emptyBody: TypeToken(size: 12.5, weight: .regular, lineHeightMultiple: 1.45),
        railKicker: TypeToken(size: 10.5, weight: .semibold, trackingEm: 0.16, uppercase: true),
        ringNumber: TypeToken(size: 30, weight: .bold, trackingEm: -0.03, monospacedDigit: true),
        ringSub: TypeToken(size: 11, weight: .regular),
        railLine: TypeToken(size: 13, weight: .regular),
        railLineValue: TypeToken(size: 13, weight: .semibold, monospacedDigit: true),
        railQuote: TypeToken(size: 12, weight: .regular, lineHeightMultiple: 1.5),
        segmentButton: TypeToken(size: 12, weight: .semibold)
    )
}

// MARK: - Motion (exact CSS/WAAPI transcription)

extension MacOSTheme {
    static let macMotion = Motion(
        easeOut: .easeOut,
        easeDrawer: .easeDrawer,
        easeIO: .easeIO,
        panelEnter: MotionToken(0.340, .easeOut),
        panelExit: MotionToken(0.220, .easeOut),
        expandMorph: MotionToken(0.520, .easeDrawer),
        tabThumb: MotionToken(0.460, .easeDrawer),
        appearanceThumb: MotionToken(0.420, .easeDrawer),
        soundKnob: MotionToken(0.320, .easeDrawer),
        checkboxFill: MotionToken(0.380, .easeOut),
        tickDraw: MotionToken(0.260, .easeOut, delay: 0.040),
        strikethrough: MotionToken(0.340, .easeOut),
        titleColorFade: MotionToken(0.300, .easeOut),
        rowEntrance: MotionToken(0.360, .easeOut),
        flipMove: MotionToken(0.440, .easeDrawer),
        ring: MotionToken(0.700, .easeDrawer),
        appearanceCrossfade: MotionToken(0.600, .easeOut),
        hoverFade: MotionToken(0.160, .easeOut),
        pressEcho: MotionToken(0.130, .easeOut),
        counterFade: MotionToken(0.200, .easeOut),
        checkboxSequence: CheckboxSequence(
            fillDuration: 0.380,
            fillKeyframes: [
                .init(scale: 0.10, fraction: 0.00),
                .init(scale: 1.16, fraction: 0.55),
                .init(scale: 0.94, fraction: 0.78),
                .init(scale: 1.00, fraction: 1.00),
            ],
            tickDrawDuration: 0.260,
            tickDrawDelay: 0.040,
            fillFadeDuration: 0.200,
            ringFadeDuration: 0.200,
            completeReflowDelay: 0.470,
            uncheckReflowDelay: 0.230
        ),
        rowEntranceTransform: RowEntranceTransform(translateY: -8, scale: 0.96, duration: 0.360)
    )
}

// MARK: - Metrics (exact CSS transcription)

extension MacOSTheme {
    static let macMetrics = ThemeMetrics(
        panelCompactSize: CGSize(width: 380, height: 566),
        panelExpandedSize: CGSize(width: 606, height: 588),
        panelCornerRadius: 20,
        railWidth: 226,
        mainColumnWidth: 380,
        ringRadius: 56,
        ringStrokeWidth: 9,
        compactRingDiameter: 20,
        compactRingStrokeWidth: 2.5,
        rowCornerRadius: 11,
        checkboxSize: 22,
        beakSize: 12
    )
}

// MARK: - Sound set (exact WebAudio recipe numbers)

extension MacOSTheme {
    static let macSoundSet = SoundSet([
        // complete: marimba(523.25, t, 0.11); marimba(783.99, t+0.11, 0.10)
        .complete: SoundRecipe([
            .marimba(Marimba(startDelay: 0, frequency: 523.25, peakGain: 0.11)),
            .marimba(Marimba(startDelay: 0.11, frequency: 783.99, peakGain: 0.10)),
        ]),
        // uncheck: tone(440, t, 0.16, 0.05, "sine", 262)
        .uncheck: SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 440, glideTo: 262, duration: 0.16, peakGain: 0.05)),
        ]),
        // add: tone(300, t, 0.11, 0.06, "sine", 560); tone(600, t+0.02, 0.1, 0.03, "triangle", 900)
        .add: SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 300, glideTo: 560, duration: 0.11, peakGain: 0.06)),
            .oscillator(Oscillator(wave: .triangle, startDelay: 0.02, frequency: 600, glideTo: 900, duration: 0.10, peakGain: 0.03)),
        ]),
        // tab: tone(880, t, 0.05, 0.04, "sine")
        .tabSwitch: SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 880, duration: 0.05, peakGain: 0.04)),
        ]),
        // open: noiseSwoosh(t, 0.16, 0.03, true); tone(220, t, 0.18, 0.045, "sine", 420)
        .panelOpen: SoundRecipe([
            .noise(NoiseSwoosh.rising(duration: 0.16, peakGain: 0.03)),
            .oscillator(Oscillator(wave: .sine, frequency: 220, glideTo: 420, duration: 0.18, peakGain: 0.045)),
        ]),
        // close: noiseSwoosh(t, 0.14, 0.028, false); tone(420, t, 0.16, 0.04, "sine", 200)
        .panelClose: SoundRecipe([
            .noise(NoiseSwoosh.falling(duration: 0.14, peakGain: 0.028)),
            .oscillator(Oscillator(wave: .sine, frequency: 420, glideTo: 200, duration: 0.16, peakGain: 0.04)),
        ]),
        // toggleOn: tone(760, t, 0.07, 0.045, "triangle", 1180)
        .toggleOn: SoundRecipe([
            .oscillator(Oscillator(wave: .triangle, frequency: 760, glideTo: 1180, duration: 0.07, peakGain: 0.045)),
        ]),
        // toggleOff: tone(1180, t, 0.07, 0.04, "triangle", 720)
        .toggleOff: SoundRecipe([
            .oscillator(Oscillator(wave: .triangle, frequency: 1180, glideTo: 720, duration: 0.07, peakGain: 0.04)),
        ]),
    ])
}
