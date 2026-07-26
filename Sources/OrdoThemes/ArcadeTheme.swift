import SwiftUI
import AppKit

/// Ordo's "Arcade" theme: night-arcade phosphor (dark) / Game Boy DMG (light) cabinet
/// chrome, pixel type, and chiptune sound. Stateless `Sendable` value, safe to share
/// and swap live. Signature-view conformances live in `ArcadeSignatureViews.swift`.
public struct ArcadeTheme: Theme {

    public init() {
        FontRegistrar.registerAll()
    }

    // MARK: Identity

    public let id: ThemeID = .arcade
    public let displayName = "Arcade"

    // MARK: Display strings (theme voice)

    public func greeting(forHour hour: Int) -> String {
        if hour < 5 { return "STILL PLAYING?" }
        if hour < 12 { return "NEW GAME." }
        if hour < 18 { return "CONTINUE?" }
        return "HIGH SCORE HOUR."
    }

    public let todayTabLabel = "TODAY"
    public let longtermTabLabel = "QUESTS"
    public let doneSectionLabel = "CLEARED"

    // First-run empty-state copy, arcade-voiced.
    public let firstRunTitle = "PRESS START"
    public let firstRunMessage = "Add your first task below. Ordo keeps today in play — and quietly carries anything unfinished into tomorrow."

    // "All cleared" is the victory/stage-clear screen text.
    public let allClearTitle = "STAGE CLEAR"
    public let allClearMessage = "Every task down. Take the win — tomorrow can wait."

    // MARK: Palette

    public func palette(for appearance: ResolvedAppearance, accessibility: AccessibilityOptions) -> Palette {
        var p = (appearance == .dark) ? Self.darkBase : Self.lightBase

        if accessibility.increaseContrast {
            Self.applyIncreaseContrast(&p, appearance: appearance)
        }
        if accessibility.reduceTransparency {
            if case .cabinet(var cab) = p.surface {
                cab.overlay.scanlineOpacity *= 0.5
                cab.overlay.vignetteOpacity *= 0.5
                p.surface = .cabinet(cab)
            }
            p.material.usesFallback = true
        }
        return p
    }

    // MARK: Tokens

    public let typeScale = Self.arcadeTypeScale
    public let motion = Self.arcadeMotion
    public let metrics = Self.arcadeMetrics
    public let soundSet = Self.arcadeSoundSet
}

// MARK: - Palettes

extension ArcadeTheme {

    /// Light — Game Boy DMG: cream cabinet + green LCD, flat/matte, no glow.
    static let lightBase = Palette(
        ink: .hex(0x1B280D),
        ink2: .hex(0x3F4F26),
        ink3: .hex(0x6A7A49),
        inkFaint: .rgba(27, 40, 13, 0.09),
        rowHover: .rgba(0, 0, 0, 0.03),
        rowPress: .rgba(0, 0, 0, 0.08),
        fieldBackground: .hex(0xA8BB72),
        fieldLine: .hex(0x7C8A5A),
        segmentBackground: .hex(0x9FB268),
        segmentThumb: .hex(0x2C5417),
        segmentThumbShadow: [],
        accent: .hex(0x2C5417),
        accentSoft: .rgba(44, 84, 23, 0.2),
        accentInk: .hex(0xA8BB72),
        checkRing: .hex(0x5D6C3C),
        divider: .hex(0x7C8A5A),
        material: MaterialIntent(
            blurRadius: 0,
            saturation: 1.0,
            vibrancy: false,
            tint: .hex(0xCDD1B6),
            sheen: .rgba(255, 255, 255, 0.28),
            fallbackOpaque: .hex(0xCDD1B6),
            usesFallback: true,
            material: .headerView,
            blending: .withinWindow
        ),
        panelHairline: .rgba(255, 255, 255, 0.28),
        panelHairlineOuter: .hex(0x5D6C3C),
        innerHighlight: .rgba(255, 255, 255, 0.28),
        panelShadow: [],
        hairlineWidth: 2,
        surface: .cabinet(CabinetStyle(
            fill: .hex(0xCDD1B6),
            border: .hex(0x5D6C3C),
            borderWidth: 2,
            cornerRadius: 16,
            hardShadow: HardShadow(color: .rgba(40, 50, 20, 0.30), x: 6, y: 8),
            topSheen: .rgba(255, 255, 255, 0.28),
            overlay: OverlayStyle(kind: .lcdGrain, scanlineOpacity: 0, vignetteOpacity: 0, gridOpacity: 0.10)
        )),
        coin: .hex(0x6A4E07),
        coinInk: .hex(0xA8BB72),
        glow: .rgba(44, 84, 23, 0),
        coinGlow: .rgba(106, 78, 7, 0)
    )

    /// Dark — night-arcade phosphor: glow + scanlines.
    static let darkBase = Palette(
        ink: .hex(0xE9F2D8),
        ink2: .hex(0x97A884),
        ink3: .hex(0x5F6E4E),
        inkFaint: .rgba(233, 242, 216, 0.10),
        rowHover: .rgba(255, 255, 255, 0.03),
        rowPress: .rgba(0, 0, 0, 0.12),
        fieldBackground: .hex(0x0C1108),
        fieldLine: .hex(0x2C3620),
        segmentBackground: .hex(0x0A0E07),
        segmentThumb: .hex(0x9BE05A),
        segmentThumbShadow: [],
        accent: .hex(0x9BE05A),
        accentSoft: .rgba(155, 224, 90, 0.2),
        accentInk: .hex(0x0C1206),
        checkRing: .hex(0x3A4A29),
        divider: .hex(0x2C3620),
        material: MaterialIntent(
            blurRadius: 0,
            saturation: 1.0,
            vibrancy: false,
            tint: .hex(0x14180F),
            sheen: .rgba(255, 255, 255, 0.045),
            fallbackOpaque: .hex(0x14180F),
            usesFallback: true,
            material: .headerView,
            blending: .withinWindow
        ),
        panelHairline: .rgba(255, 255, 255, 0.045),
        panelHairlineOuter: .hex(0x3A4A29),
        innerHighlight: .rgba(255, 255, 255, 0.045),
        panelShadow: [],
        hairlineWidth: 2,
        surface: .cabinet(CabinetStyle(
            fill: .hex(0x14180F),
            border: .hex(0x3A4A29),
            borderWidth: 2,
            cornerRadius: 16,
            hardShadow: HardShadow(color: .rgba(0, 0, 0, 0.65), x: 6, y: 8),
            topSheen: .rgba(255, 255, 255, 0.045),
            overlay: OverlayStyle(kind: .scanlines, scanlineOpacity: 0.42, scanlinePitch: 3, vignetteOpacity: 0.55, gridOpacity: 0.05)
        )),
        coin: .hex(0xFFD24D),
        coinInk: .hex(0x3A2C00),
        glow: .rgba(155, 224, 90, 0.55),
        coinGlow: .rgba(255, 210, 77, 0.55)
    )

    /// Thickens cabinet borders/hairlines and deepens mid-tone inks for Increase Contrast.
    static func applyIncreaseContrast(_ p: inout Palette, appearance: ResolvedAppearance) {
        p.hairlineWidth = 3
        if case .cabinet(var cab) = p.surface {
            cab.borderWidth = 3
            p.surface = .cabinet(cab)
        }
        if appearance == .dark {
            p.ink2 = .hex(0xB7CFA0)
            p.ink3 = .hex(0x84976A)
            p.divider = .hex(0x4A5C36)
            p.checkRing = .hex(0x4A5C36)
            p.fieldLine = .hex(0x4A5C36)
        } else {
            p.ink2 = .hex(0x27390F)
            p.ink3 = .hex(0x415A22)
            p.divider = .hex(0x46521F)
            p.checkRing = .hex(0x46521F)
            p.fieldLine = .hex(0x46521F)
        }
    }
}

// MARK: - Type scale

extension ArcadeTheme {
    static let arcadeTypeScale = TypeScale(
        greeting: TypeToken(size: 15, weight: .semibold, trackingEm: -0.01, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        date: TypeToken(size: 12, weight: .medium, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        tab: TypeToken(size: 8, weight: .regular, trackingEm: 0.5 / 8, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        tabCount: TypeToken(size: 6, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        taskTitle: TypeToken(size: 14.5, weight: .medium, trackingEm: 0.1 / 14.5, lineHeightMultiple: 1.25, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        ageMarker: TypeToken(size: 7, weight: .regular, trackingEm: 0.5 / 7, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        doneHeader: TypeToken(size: 8, weight: .regular, trackingEm: 1.0 / 8, uppercase: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        field: TypeToken(size: 14, weight: .medium, trackingEm: 0.1 / 14, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        emptyTitle: TypeToken(size: 15, weight: .regular, trackingEm: 1.0 / 15, lineHeightMultiple: 1.5, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        emptyBody: TypeToken(size: 13.5, weight: .regular, lineHeightMultiple: 1.45, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        railKicker: TypeToken(size: 8, weight: .regular, trackingEm: 1.0 / 8, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        ringNumber: TypeToken(size: 20, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        ringSub: TypeToken(size: 7, weight: .regular, trackingEm: 1.0 / 7, lineHeightMultiple: 1.5, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        railLine: TypeToken(size: 6, weight: .regular, trackingEm: 0.5 / 6, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        railLineValue: TypeToken(size: 13, weight: .regular, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        railQuote: TypeToken(size: 6.5, weight: .regular, trackingEm: 0.5 / 6.5, lineHeightMultiple: 1.7, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        segmentButton: TypeToken(size: 7, weight: .regular, fontFamily: .named(FontRegistrar.pressStart2PFamily))
    )
}

// MARK: - Arcade-specific type roles (outside the shared `TypeScale` schema)

extension ArcadeTheme {
    /// Header "ORDO" wordmark — 11px, letter-spacing 0.5px, glow-shadowed.
    public static let brandType = TypeToken(size: 11, weight: .regular, trackingEm: 0.5 / 11, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Status row big number ("N" left today / "N" done total) — 20px, tabular, glowing.
    public static let statusNumberType = TypeToken(size: 20, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Header SCORE readout — 14px, tabular, coin-colored, pops on change.
    public static let scoreType = TypeToken(size: 14, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Row index badge ("01", "02", …) — 7px, letter-spacing 0.5px, dimmed.
    public static let indexType = TypeToken(size: 7, weight: .regular, trackingEm: 0.5 / 7, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Footer "SFX" toggle label — 7px, letter-spacing 1px.
    public static let sfxLabelType = TypeToken(size: 7, weight: .regular, trackingEm: 1.0 / 7, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Rail HIGH SCORE value — 24px, tabular, coin-colored + glow.
    public static let statBigType = TypeToken(size: 24, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Rail SCORE / STREAK / CLEARED values — 13px, accent-colored + glow.
    public static let statSmallType = TypeToken(size: 13, weight: .regular, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Victory panel title ("STAGE CLEAR") — 15px, letter-spacing 1px, glowing.
    public static let victoryTitleType = TypeToken(size: 15, weight: .regular, trackingEm: 1.0 / 15, lineHeightMultiple: 1.5, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Victory panel score line ("SCORE 700 · STREAK ×7") — 9px, letter-spacing 1px.
    public static let victoryScoreType = TypeToken(size: 9, weight: .regular, trackingEm: 1.0 / 9, fontFamily: .named(FontRegistrar.pressStart2PFamily))
}

// MARK: - Motion

extension ArcadeTheme {
    static let arcadeMotion = Motion(
        easeOut: .easeOut,
        easeDrawer: .easeDrawer,
        easeIO: .easeIO,
        panelEnter: MotionToken(0.300, .easeDrawer),
        panelExit: MotionToken(0.240, .easeOut),
        expandMorph: MotionToken(0.460, .easeDrawer),
        tabThumb: MotionToken(0.320, .easeDrawer),
        appearanceThumb: MotionToken(0.200, .easeOut),
        soundKnob: MotionToken(0.180, .steps(4)),
        checkboxFill: MotionToken(0.180, .easeOut),
        tickDraw: MotionToken(0.220, .steps(4)),
        strikethrough: MotionToken(0.260, .easeOut),
        titleColorFade: MotionToken(0.200, .easeOut),
        rowEntrance: MotionToken(0.340, .easeOut),
        flipMove: MotionToken(0.340, .easeDrawer),
        ring: MotionToken(0.700, .easeDrawer),
        appearanceCrossfade: MotionToken(0.600, .easeOut),
        hoverFade: MotionToken(0.140, .easeOut),
        pressEcho: MotionToken(0.120, .easeOut),
        counterFade: MotionToken(0.200, .easeOut),
        checkboxSequence: CheckboxSequence(
            fillDuration: 0.180,
            fillKeyframes: [
                .init(scale: 0.94, fraction: 0.00),
                .init(scale: 1.00, fraction: 1.00),
            ],
            tickDrawDuration: 0.220,
            tickDrawDelay: 0,
            fillFadeDuration: 0.120,
            ringFadeDuration: 0.120,
            completeReflowDelay: 0,
            uncheckReflowDelay: 0
        ),
        rowEntranceTransform: RowEntranceTransform(translateY: 0, scale: 0.98, duration: 0.340)
    )
}

// MARK: - Metrics

extension ArcadeTheme {
    static let arcadeMetrics = ThemeMetrics(
        panelCompactSize: CGSize(width: 380, height: 562),
        panelExpandedSize: CGSize(width: 604, height: 582),
        panelCornerRadius: 16,
        railWidth: 196,
        mainColumnWidth: 380,
        ringRadius: 56,
        ringStrokeWidth: 9,
        compactRingDiameter: 20,
        compactRingStrokeWidth: 2.5,
        rowCornerRadius: 8,
        checkboxSize: 22,
        beakSize: 12,
        borderWidth: 2,
        progressSegments: 0,
        notchInsetFromRight: 44
    )
}

// MARK: - Sound set

extension ArcadeTheme {
    static let arcadeSoundSet = SoundSet([
        .complete: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 988, duration: 0.07, peakGain: 0.08)),
            .oscillator(Oscillator(wave: .square, startDelay: 0.07, frequency: 1319, duration: 0.16, peakGain: 0.08)),
        ]),
        .uncheck: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 440, glideTo: 220, duration: 0.10, peakGain: 0.06)),
        ]),
        .add: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 520, duration: 0.05, peakGain: 0.06)),
            .oscillator(Oscillator(wave: .square, startDelay: 0.05, frequency: 880, glideTo: 1180, duration: 0.09, peakGain: 0.06)),
        ]),
        .tabSwitch: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 360, glideTo: 500, duration: 0.05, peakGain: 0.05)),
        ]),
        .panelOpen: SoundRecipe([
            .oscillator(Oscillator(wave: .triangle, frequency: 300, glideTo: 760, duration: 0.16, peakGain: 0.06)),
        ]),
        .panelClose: SoundRecipe([
            .oscillator(Oscillator(wave: .triangle, frequency: 620, glideTo: 220, duration: 0.14, peakGain: 0.05)),
        ]),
        .toggleOn: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 1200, duration: 0.04, peakGain: 0.05)),
        ]),
        .toggleOff: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 900, duration: 0.04, peakGain: 0.05)),
        ]),
    ])
}

