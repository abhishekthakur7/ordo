import SwiftUI
import AppKit

/// Ordo's "Arcade" theme: night-arcade phosphor (dark) / Game Boy DMG (light) cabinet
/// chrome, Press Start 2P + Space Grotesk type, hard-shadow chrome, square/triangle
/// chiptune confirmations — transcribed from `mockups/01-arcade.html`. A stateless
/// `Sendable` value (palettes/tokens computed), so one shared instance is safe to
/// inject and swap live.
///
/// The signature-view conformances (the pixel-art `checkbox`, `taskTitle`, etc.)
/// live in `ArcadeSignatureViews.swift`, mirroring `MacOSTheme` / `MacOSSignatureViews`.
public struct ArcadeTheme: Theme {

    public init() {
        FontRegistrar.registerAll()
    }

    // MARK: Identity

    public let id: ThemeID = .arcade
    public let displayName = "Arcade"

    // MARK: Display strings (theme voice)

    public func greeting(forHour hour: Int) -> String {
        // NOTE: unused in the Arcade header (which shows brand + score, not a
        // greeting), but required by the `Theme` protocol. Kept short and
        // arcade-voiced for any future call site.
        if hour < 5 { return "STILL PLAYING?" }
        if hour < 12 { return "NEW GAME." }
        if hour < 18 { return "CONTINUE?" }
        return "HIGH SCORE HOUR."
    }

    public let todayTabLabel = "TODAY"
    public let longtermTabLabel = "QUESTS"
    public let doneSectionLabel = "CLEARED"

    // JUDGMENT CALL: the mockup's demo data always seeds tasks, so it never
    // renders an empty-list state — there is no verbatim first-run copy to
    // transcribe. Voiced to match the arcade idiom and the composer's existing
    // "ADD A TASK…" placeholder (see `mockups/01-arcade.html` line 729).
    public let firstRunTitle = "PRESS START"
    public let firstRunMessage = "Add your first task below. Ordo keeps today in play — and quietly carries anything unfinished into tomorrow."

    // Verbatim from the mockup's victory panel (`.v-title` / `.v-sub`,
    // `mockups/01-arcade.html` lines 718–719): in Arcade, "all cleared" IS the
    // victory screen (there's no separate all-clear treatment).
    public let allClearTitle = "STAGE CLEAR"
    public let allClearMessage = "Every task down. Take the win — tomorrow can wait."

    // MARK: Palette

    public func palette(for appearance: ResolvedAppearance, accessibility: AccessibilityOptions) -> Palette {
        var p = (appearance == .dark) ? Self.darkBase : Self.lightBase

        if accessibility.increaseContrast {
            Self.applyIncreaseContrast(&p, appearance: appearance)
        }
        if accessibility.reduceTransparency {
            // The cabinet surface is already opaque (no blur to fall back from),
            // so Reduce Transparency instead softens the CRT/LCD overlay — the
            // closest thing Arcade has to "extra visual noise" to quiet down.
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

// MARK: - Palettes (exact CSS transcription from mockups/01-arcade.html)

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

    /// Increase-Contrast: thicken the cabinet border/hairlines and deepen the
    /// mid-tone inks. JUDGMENT CALL: the mockup has no "increase contrast" mode
    /// to transcribe, so these deltas mirror the spirit of `MacOSTheme`'s
    /// (thicker structure, deeper grays) rather than an exact source value.
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

// MARK: - Type scale (exact CSS transcription)

extension ArcadeTheme {
    static let arcadeTypeScale = TypeScale(
        // Unused in the Arcade header (brand + score shown instead of a greeting/
        // date), but the schema is fixed across themes — given plausible body values.
        greeting: TypeToken(size: 15, weight: .semibold, trackingEm: -0.01, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        date: TypeToken(size: 12, weight: .medium, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        // .tab: 8px, ls 0.5px, Press Start 2P.
        tab: TypeToken(size: 8, weight: .regular, trackingEm: 0.5 / 8, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // Unused: Arcade tabs show a dot indicator, never a count badge.
        tabCount: TypeToken(size: 6, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // .task .title: 14.5px w500 Space Grotesk, lh1.25, ls 0.1px.
        // NOTE: variable-font weight — Space Grotesk's default instance is
        // Light(300); verify `.medium` renders heavy enough in the parity pass.
        taskTitle: TypeToken(size: 14.5, weight: .medium, trackingEm: 0.1 / 14.5, lineHeightMultiple: 1.25, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        // .idx-style 7px pixel, ls 0.5px.
        ageMarker: TypeToken(size: 7, weight: .regular, trackingEm: 0.5 / 7, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // showsDoneSection=false for Arcade (see Motion doc below), so this token
        // is effectively dormant, but kept faithful to the pixel scale (8px, ls1).
        doneHeader: TypeToken(size: 8, weight: .regular, trackingEm: 1.0 / 8, uppercase: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // .composer input: 14px w500 Space Grotesk, ls 0.1px.
        // NOTE: variable-font weight — see taskTitle note above.
        field: TypeToken(size: 14, weight: .medium, trackingEm: 0.1 / 14, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        // .v-title: 15px pixel, ls1px, lh1.5 (victory/empty-state title role).
        emptyTitle: TypeToken(size: 15, weight: .regular, trackingEm: 1.0 / 15, lineHeightMultiple: 1.5, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // .v-sub: 13.5px Space Grotesk, lh1.45.
        // NOTE: variable-font weight — see taskTitle note above.
        emptyBody: TypeToken(size: 13.5, weight: .regular, lineHeightMultiple: 1.45, fontFamily: .named(FontRegistrar.spaceGroteskFamily)),
        // .side-h: 8px pixel, ls1px. (CSS declares no text-transform; the mockup's
        // "STATS" literal is already uppercase, so `uppercase` stays false here.)
        railKicker: TypeToken(size: 8, weight: .regular, trackingEm: 1.0 / 8, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // Mapped to the status big number (.remain .num): 20px pixel, tabular.
        ringNumber: TypeToken(size: 20, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // .remain .txt: 7px pixel, ls1px, lh1.5.
        ringSub: TypeToken(size: 7, weight: .regular, trackingEm: 1.0 / 7, lineHeightMultiple: 1.5, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // Mapped to .stat-sm .k: 6px pixel, ls 0.5px.
        railLine: TypeToken(size: 6, weight: .regular, trackingEm: 0.5 / 6, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // Mapped to .stat-sm .v: 13px pixel (CSS declares no tabular-nums here).
        railLineValue: TypeToken(size: 13, weight: .regular, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // .mascot-txt: 6.5px pixel, ls 0.5px, lh1.7.
        railQuote: TypeToken(size: 6.5, weight: .regular, trackingEm: 0.5 / 6.5, lineHeightMultiple: 1.7, fontFamily: .named(FontRegistrar.pressStart2PFamily)),
        // No direct CSS text counterpart (seg-theme buttons are icon-only); sized
        // to match the pixel scale's small labels per the Phase 1 brief.
        segmentButton: TypeToken(size: 7, weight: .regular, fontFamily: .named(FontRegistrar.pressStart2PFamily))
    )
}

// MARK: - Arcade-specific type roles (not in the shared `TypeScale` schema)
//
// Phases 3/4/5 should reference these directly rather than re-deriving sizes.

extension ArcadeTheme {
    /// Header wordmark "ORDO" — Press Start 2P, 11px, regular (single-weight
    /// face), letter-spacing 0.5px. Rendered with `--txt-glow` (see `palette.glow`).
    public static let brandType = TypeToken(size: 11, weight: .regular, trackingEm: 0.5 / 11, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Status row big number (today: "N" of "LEFT TODAY" / quests: "N" of "OF
    /// total DONE") — Press Start 2P, 20px, tabular digits, accent-colored + glow.
    public static let statusNumberType = TypeToken(size: 20, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Header `.score-mini .val` — Press Start 2P, 14px, tabular digits,
    /// coin-colored + coin-glow, "bump" pop (360ms) on change.
    public static let scoreType = TypeToken(size: 14, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Row index badge ("01", "02", … zero-padded) — Press Start 2P, 7px,
    /// letter-spacing 0.5px, rendered at 65% opacity, ink-3 colored.
    public static let indexType = TypeToken(size: 7, weight: .regular, trackingEm: 0.5 / 7, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Footer "SFX" toggle label — Press Start 2P, 7px, letter-spacing 1px.
    public static let sfxLabelType = TypeToken(size: 7, weight: .regular, trackingEm: 1.0 / 7, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Rail `.stat-big .v` (HIGH SCORE) — Press Start 2P, 24px, tabular digits,
    /// coin-colored + coin-glow.
    public static let statBigType = TypeToken(size: 24, weight: .regular, monospacedDigit: true, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Rail `.stat-sm .v` (SCORE / STREAK / CLEARED) — Press Start 2P, 13px,
    /// accent-colored + txt-glow.
    public static let statSmallType = TypeToken(size: 13, weight: .regular, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Victory panel `.v-title` ("STAGE CLEAR") — Press Start 2P, 15px,
    /// letter-spacing 1px, line-height 1.5, coin-colored + coin-glow.
    public static let victoryTitleType = TypeToken(size: 15, weight: .regular, trackingEm: 1.0 / 15, lineHeightMultiple: 1.5, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    /// Victory panel `.v-score` ("SCORE 700 · STREAK ×7") — Press Start 2P, 9px,
    /// letter-spacing 1px, accent-colored + txt-glow.
    public static let victoryScoreType = TypeToken(size: 9, weight: .regular, trackingEm: 1.0 / 9, fontFamily: .named(FontRegistrar.pressStart2PFamily))
}

// MARK: - Motion (exact CSS/WAAPI transcription)

extension ArcadeTheme {
    static let arcadeMotion = Motion(
        easeOut: .easeOut,
        easeDrawer: .easeDrawer,
        easeIO: .easeIO,
        // .panel-wrap transition: opacity 240ms ease-out, transform 300ms ease-drawer.
        panelEnter: MotionToken(0.300, .easeDrawer),
        panelExit: MotionToken(0.240, .easeOut),
        // .panel transition: width/height 460ms ease-drawer.
        expandMorph: MotionToken(0.460, .easeDrawer),
        // .tab-ind transition: transform 320ms ease-drawer.
        tabThumb: MotionToken(0.320, .easeDrawer),
        // seg-theme buttons have no sliding thumb (flat bg/color swap on `.on`);
        // JUDGMENT CALL: keep a short value matching their own transition (200ms).
        appearanceThumb: MotionToken(0.200, .easeOut),
        // .switch .knob transition: transform 180ms steps(4,end).
        soundKnob: MotionToken(0.180, .steps(4)),
        // .check transition: background/border-color 180ms ease-out (the fill is a
        // flat color swap, not a springy scale — see `checkboxSequence` below).
        checkboxFill: MotionToken(0.180, .easeOut),
        // .check .mark transition: clip-path 220ms steps(4,end).
        tickDraw: MotionToken(0.220, .steps(4)),
        // .task .title::after transition: transform (scaleX) 260ms ease-out.
        strikethrough: MotionToken(0.260, .easeOut),
        // JUDGMENT CALL: the mockup declares no explicit `transition: color` on
        // `.task .title` (the class swap is instant); 200ms ease-out approximates
        // a soft fade so the color change isn't jarring, per the Phase 1 brief.
        titleColorFade: MotionToken(0.200, .easeOut),
        // @keyframes rowin: 340ms ease-out.
        rowEntrance: MotionToken(0.340, .easeOut),
        // Arcade never reflows rows into a done section (showsDoneSection=false),
        // so FLIP is effectively unused; kept non-zero to satisfy the schema.
        flipMove: MotionToken(0.340, .easeDrawer),
        // Not driven by an actual ring in Arcade (segbar instead), kept parallel
        // to macOS's value to satisfy the schema.
        ring: MotionToken(0.700, .easeDrawer),
        // Theme-mode CSS transitions throughout the mockup are 600ms ease-out.
        appearanceCrossfade: MotionToken(0.600, .easeOut),
        // .task:hover transition: transform/box-shadow 140ms ease-out.
        hoverFade: MotionToken(0.140, .easeOut),
        // Buttons' :active transition (add-btn/icon-btn/v-review): 120ms ease-out.
        pressEcho: MotionToken(0.120, .easeOut),
        // JUDGMENT CALL: no composer character-counter in this mockup; 200ms
        // ease-out per the Phase 1 brief.
        counterFade: MotionToken(0.200, .easeOut),
        checkboxSequence: CheckboxSequence(
            // .check background/border-color transition is 180ms; the fill itself
            // is a flat color swap in CSS (no scale keyframes), so this is a mild
            // grow rather than macOS's springy overshoot.
            fillDuration: 0.180,
            fillKeyframes: [
                .init(scale: 0.94, fraction: 0.00),
                .init(scale: 1.00, fraction: 1.00),
            ],
            tickDrawDuration: 0.220,
            tickDrawDelay: 0,
            fillFadeDuration: 0.120,
            ringFadeDuration: 0.120,
            // Arcade has NO reflow — done rows dim in place (opacity 0.62 + strike),
            // stored order, no "Completed" section (showsDoneSection=false).
            completeReflowDelay: 0,
            uncheckReflowDelay: 0
        ),
        // @keyframes rowin: `from{ opacity:0; transform:translateX(-14px) scale(0.98); }`.
        // `RowEntranceTransform` has no X field (Y-only, mirroring macOS); the
        // mockup's entrance is X-axis, not Y — Phase 4 should apply translateX(-14)
        // directly in the row view. `scale`/`duration` are transcribed exactly.
        rowEntranceTransform: RowEntranceTransform(translateY: 0, scale: 0.98, duration: 0.340)
    )
}

// MARK: - Metrics (exact CSS transcription)

extension ArcadeTheme {
    static let arcadeMetrics = ThemeMetrics(
        panelCompactSize: CGSize(width: 380, height: 562),
        panelExpandedSize: CGSize(width: 604, height: 582),
        panelCornerRadius: 16,
        railWidth: 196,
        mainColumnWidth: 380,
        // Not rendered as an actual ring in Arcade (the segbar is the real progress
        // element and has no fixed geometry — `progressSegments` stays 0 since the
        // count is dynamic per task count); kept non-zero to satisfy the schema,
        // mirroring macOS's ring geometry per the Phase 1 brief.
        ringRadius: 56,
        ringStrokeWidth: 9,
        compactRingDiameter: 20,
        compactRingStrokeWidth: 2.5,
        rowCornerRadius: 8,
        checkboxSize: 22,
        beakSize: 12,
        borderWidth: 2,
        progressSegments: 0,
        // .notch/.beak right:44px (mockups/01-arcade.html) — wider than macOS's 26.
        notchInsetFromRight: 44
    )
}

// MARK: - Sound set (exact WebAudio recipe numbers from mockups/01-arcade.html)

extension ArcadeTheme {
    static let arcadeSoundSet = SoundSet([
        // coin: tone(988, square, .07, .08); tone(1319, square, .16, .08, delay .07)
        .complete: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 988, duration: 0.07, peakGain: 0.08)),
            .oscillator(Oscillator(wave: .square, startDelay: 0.07, frequency: 1319, duration: 0.16, peakGain: 0.08)),
        ]),
        // uncheck: tone(440, square, .10, .06, glide 220)
        .uncheck: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 440, glideTo: 220, duration: 0.10, peakGain: 0.06)),
        ]),
        // add: tone(520, square, .05, .06); tone(880, square, .09, .06, delay .05, glide 1180)
        .add: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 520, duration: 0.05, peakGain: 0.06)),
            .oscillator(Oscillator(wave: .square, startDelay: 0.05, frequency: 880, glideTo: 1180, duration: 0.09, peakGain: 0.06)),
        ]),
        // tab: tone(360, square, .05, .05, glide 500)
        .tabSwitch: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 360, glideTo: 500, duration: 0.05, peakGain: 0.05)),
        ]),
        // open: tone(300, triangle, .16, .06, glide 760)
        .panelOpen: SoundRecipe([
            .oscillator(Oscillator(wave: .triangle, frequency: 300, glideTo: 760, duration: 0.16, peakGain: 0.06)),
        ]),
        // close: tone(620, triangle, .14, .05, glide 220)
        .panelClose: SoundRecipe([
            .oscillator(Oscillator(wave: .triangle, frequency: 620, glideTo: 220, duration: 0.14, peakGain: 0.05)),
        ]),
        // toggle: tone(1200, square, .04, .05) — the mockup has one shared toggle
        // sound; toggleOn is transcribed exactly.
        .toggleOn: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 1200, duration: 0.04, peakGain: 0.05)),
        ]),
        // JUDGMENT CALL: the mockup has no distinct "off" toggle sound (`S.toggle`
        // is used for both directions) — per the Phase 1 brief, a slightly lower
        // pitch differentiates the off state without inventing new envelope shape.
        .toggleOff: SoundRecipe([
            .oscillator(Oscillator(wave: .square, frequency: 900, duration: 0.04, peakGain: 0.05)),
        ]),
    ])
}

