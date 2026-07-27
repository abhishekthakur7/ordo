import SwiftUI
import AppKit

/// Zen Ink's pure design data: washi paper, sumi ink, vermilion, Japanese
/// typography, and near-silent koto/temple-wood recipes. Signature-view
/// conformance lives in `ZenInkSignatureViews.swift`.
public struct ZenInkTheme: Theme {

    public init() {
        // §3.1 / D2: bundled static faces are registered once, idempotently.
        FontRegistrar.registerAll()
    }

    // MARK: Identity

    public let id: ThemeID = .zenInk
    public let displayName = "Zen Ink"

    // MARK: Voice (§3.11; D5 where the mockup has no source copy)

    public func greeting(forHour hour: Int) -> String {
        // D5: Settings-only fallback; the Zen header is a wordmark, not a greeting.
        if hour < 5 { return "The night is still." }
        if hour < 12 { return "Begin gently." }
        if hour < 18 { return "One thing at a time." }
        return "Let the day settle." }

    public let todayTabLabel = "Today" // mockup :608; subline is 今日 in Phase 5.
    public let longtermTabLabel = "道" // mockup :611; subline is The Path in Phase 5.
    public let doneSectionLabel = "済" // §3.11; inactive because Zen keeps done rows in place.
    public let firstRunTitle = "始めましょう" // D5
    public let firstRunMessage = "Begin." // D5
    public let allClearTitle = "日々是好日" // mockup :628
    public let allClearMessage = "Every day, a good day." // mockup :629

    // MARK: Tokens

    public func palette(for appearance: ResolvedAppearance, accessibility: AccessibilityOptions) -> Palette {
        var palette = appearance == .dark ? Self.darkBase : Self.lightBase
        if accessibility.increaseContrast {
            Self.applyIncreaseContrast(&palette)
        }
        if accessibility.reduceTransparency {
            // §4.2: opaque paper remains opaque; only washi grain is removed.
            if case .paper(var paper) = palette.surface {
                paper.grain.opacity = 0
                palette.surface = .paper(paper)
            }
        }
        return palette
    }

    public let typeScale = Self.zenTypeScale
    public let motion = Self.zenMotion
    public let metrics = Self.zenMetrics
    public let layout = Self.zenLayout
    public let soundSet = Self.zenSoundSet

    // MARK: Pure structural capabilities (§4.3 / D8 / D10)

    public let showsDoneSection = false
    public let showsTabCountBadge = false
    public let clearedStateCoversList = true
    public let clearedStateIsPeekable = true
    public let mainColumnFlexes = true
    public let composerStyle: ComposerStyle = .ink
    public let appearanceSegmentStyle: AppearanceSegmentStyle = .labelOnly
    public let soundControlStyle: SoundControlStyle = .ghostIcon
    public let tabIndicatorStyle: TabIndicatorStyle = .custom

}

// MARK: - Palettes (mockup CSS :21-68; §3.3-3.5)

extension ZenInkTheme {
    private static func paperMaterial(fill: Color, highlight: Color) -> MaterialIntent {
        // Required by the legacy Palette field; paper rendering consumes `.surface`.
        MaterialIntent(blurRadius: 0, saturation: 1, vibrancy: false, tint: fill,
                       sheen: highlight, fallbackOpaque: fill, usesFallback: true,
                       material: .headerView, blending: .withinWindow)
    }

    static let lightBase = Palette(
        ink: .hex(0x231F19), // --ink :27
        ink2: .hex(0x514A3F), // --ink-70 :29
        ink3: .hex(0x8A8071), // --ink-45 :30
        inkFaint: .hex(0xA89E8D), // --ink-30 :31
        rowHover: .rgba(35, 31, 25, 0.08), // --glyph-active :41
        rowPress: .rgba(35, 31, 25, 0.08), // CSS press is scale-only; same neutral fill
        fieldBackground: .clear, // composer has no card fill, :428
        fieldLine: .rgba(35, 31, 25, 0.12), // --hair :32
        segmentBackground: .rgba(35, 31, 25, 0.08), // --glyph-active :41
        segmentThumb: .hex(0xFCF8EF), // --paper-2 :26
        segmentThumbShadow: [ShadowLayer(color: .rgba(0, 0, 0, 0.08), x: 0, y: 1, blur: 3)], // :460
        accent: .hex(0xC33A28), // --vermilion :34
        accentSoft: .rgba(195, 58, 40, 0.18), // §3.5
        accentInk: .hex(0xF8F3E8), // --paper :25
        checkRing: .hex(0x8A8071), // --ink-45 :30
        divider: .rgba(35, 31, 25, 0.07), // --hair-2 :33
        material: paperMaterial(fill: .hex(0xF8F3E8), highlight: .rgba(255, 255, 255, 0.6)),
        panelHairline: .rgba(35, 31, 25, 0.12), // --hair :32
        panelHairlineOuter: .rgba(35, 31, 25, 0.12), // --hair :32
        innerHighlight: .rgba(255, 255, 255, 0.6), // inset layer :38
        panelShadow: [
            ShadowLayer(color: .rgba(74, 54, 26, 0.32), x: 0, y: 24, blur: 60), // :38 (no CSS spread field)
            ShadowLayer(color: .rgba(74, 54, 26, 0.18), x: 0, y: 4, blur: 14), // :38 (no CSS spread field)
        ],
        hairlineWidth: 1, // .panel :186
        surface: .paper(PaperStyle(
            fillTop: .hex(0xFCF8EF), fillBottom: .hex(0xF8F3E8),
            border: .rgba(35, 31, 25, 0.12), borderWidth: 1, cornerRadius: 22,
            innerHighlight: .rgba(255, 255, 255, 0.6),
            shadow: [
                ShadowLayer(color: .rgba(74, 54, 26, 0.32), x: 0, y: 24, blur: 60),
                ShadowLayer(color: .rgba(74, 54, 26, 0.18), x: 0, y: 4, blur: 14),
            ],
            // .panel::after :218: calc(--grain-op * .7), tile is 170.
            grain: GrainStyle(opacity: 0.045 * 0.7, blend: .multiply, tile: 170)
        ))
    )

    static let darkBase = Palette(
        ink: .hex(0xCBD0DC), // --ink :51
        ink2: .hex(0xAEB4C3), // --ink-70 :53
        ink3: .hex(0x7C8291), // --ink-45 :54
        inkFaint: .hex(0x565C6D), // --ink-30 :55
        rowHover: .rgba(203, 208, 220, 0.10), // --glyph-active :66
        rowPress: .rgba(203, 208, 220, 0.10), // CSS press is scale-only
        fieldBackground: .clear, // composer :428
        fieldLine: .rgba(203, 208, 220, 0.13), // --hair :56
        segmentBackground: .rgba(203, 208, 220, 0.10), // --glyph-active :66
        segmentThumb: .hex(0x1C2031), // --paper-2 :50
        segmentThumbShadow: [ShadowLayer(color: .rgba(0, 0, 0, 0.08), x: 0, y: 1, blur: 3)], // :460
        accent: .hex(0xDE5B49), // --vermilion :58
        accentSoft: .rgba(222, 91, 73, 0.18), // §3.5
        accentInk: .hex(0x181B28), // --paper :49
        checkRing: .hex(0x7C8291), // --ink-45 :54
        divider: .rgba(203, 208, 220, 0.06), // --hair-2 :57
        material: paperMaterial(fill: .hex(0x181B28), highlight: .rgba(255, 255, 255, 0.05)),
        panelHairline: .rgba(203, 208, 220, 0.13), // --hair :56
        panelHairlineOuter: .rgba(203, 208, 220, 0.13), // --hair :56
        innerHighlight: .rgba(255, 255, 255, 0.05), // inset layer :63
        panelShadow: [
            ShadowLayer(color: .rgba(0, 0, 0, 0.72), x: 0, y: 30, blur: 70), // :63 (no CSS spread field)
            ShadowLayer(color: .rgba(0, 0, 0, 0.50), x: 0, y: 6, blur: 18), // :63 (no CSS spread field)
        ],
        hairlineWidth: 1, // .panel :186
        surface: .paper(PaperStyle(
            fillTop: .hex(0x1C2031), fillBottom: .hex(0x181B28),
            border: .rgba(203, 208, 220, 0.13), borderWidth: 1, cornerRadius: 22,
            innerHighlight: .rgba(255, 255, 255, 0.05),
            shadow: [
                ShadowLayer(color: .rgba(0, 0, 0, 0.72), x: 0, y: 30, blur: 70),
                ShadowLayer(color: .rgba(0, 0, 0, 0.50), x: 0, y: 6, blur: 18),
            ],
            // .panel::after :218: calc(--grain-op * .7), tile is 170.
            grain: GrainStyle(opacity: 0.05 * 0.7, blend: .overlay, tile: 170)
        ))
    )

    /// §4.2: hairline 1 → 1.5 and muted `ink-30` → `ink-45`.
    static func applyIncreaseContrast(_ palette: inout Palette) {
        palette.hairlineWidth = 1.5
        palette.inkFaint = palette.ink3
        if case .paper(var paper) = palette.surface {
            paper.borderWidth = 1.5
            palette.surface = .paper(paper)
        }
    }
}

// MARK: - Typography (§3.7; exact PostScript faces)

extension ZenInkTheme {
    private static let minchoRegular: FontFamily = .postScript(FontRegistrar.shipporiMinchoRegular)
    private static let minchoSemiBold: FontFamily = .postScript(FontRegistrar.shipporiMinchoSemiBold)
    private static let minchoBold: FontFamily = .postScript(FontRegistrar.shipporiMinchoBold)
    private static let minchoExtraBold: FontFamily = .postScript(FontRegistrar.shipporiMinchoExtraBold)
    private static let gothicRegular: FontFamily = .postScript(FontRegistrar.zenKakuGothicNewRegular)
    private static let gothicMedium: FontFamily = .postScript(FontRegistrar.zenKakuGothicNewMedium)

    static let zenTypeScale = TypeScale(
        greeting: TypeToken(size: 18, weight: .bold, trackingEm: 0.02, fontFamily: minchoBold), // : Settings fallback
        date: TypeToken(size: 12.5, weight: .regular, fontFamily: gothicRegular), // protocol-only
        tab: TypeToken(size: 16, weight: .semibold, trackingEm: 0.04, lineHeightMultiple: 1.1, fontFamily: minchoSemiBold), // :311
        tabCount: TypeToken(size: 9.5, weight: .medium, trackingEm: 0.26, fontFamily: gothicMedium), // .t-sub :312
        taskTitle: TypeToken(size: 15, weight: .regular, trackingEm: 0.01, lineHeightMultiple: 1.4, fontFamily: gothicRegular), // :369
        ageMarker: TypeToken(size: 10, weight: .medium, trackingEm: 0.10, fontFamily: gothicMedium), // extrapolated
        doneHeader: TypeToken(size: 10, weight: .medium, trackingEm: 0.28, uppercase: true, fontFamily: gothicMedium), // inactive
        field: TypeToken(size: 15, weight: .regular, trackingEm: 0.02, fontFamily: minchoRegular), // :428
        emptyTitle: TypeToken(size: 21, weight: .semibold, trackingEm: 0.24, fontFamily: minchoSemiBold), // :415
        emptyBody: TypeToken(size: 13.5, weight: .regular, trackingEm: 0.05, italic: true, fontFamily: minchoRegular), // :416
        railKicker: TypeToken(size: 10, weight: .regular, trackingEm: 0.34, uppercase: true, fontFamily: gothicRegular), // :254
        ringNumber: TypeToken(size: 34, weight: .semibold, fontFamily: minchoSemiBold), // :568
        ringSub: TypeToken(size: 10, weight: .regular, trackingEm: 0.34, fontFamily: gothicRegular), // mirrors rail kicker
        railLine: TypeToken(size: 13, weight: .regular, trackingEm: 0.04, lineHeightMultiple: 2, fontFamily: minchoRegular), // :255
        railLineValue: TypeToken(size: 14.5, weight: .regular, trackingEm: 0.14, fontFamily: minchoRegular), // :260
        railQuote: TypeToken(size: 13, weight: .regular, trackingEm: 0.04, lineHeightMultiple: 2, fontFamily: minchoRegular), // :255
        segmentButton: TypeToken(size: 10.5, weight: .medium, trackingEm: 0.12, uppercase: true, fontFamily: gothicMedium) // :449
    )

    // MARK: Zen-only roles (§3.7)
    public static let wordmarkType = TypeToken(size: 23, weight: .bold, trackingEm: 0.03, lineHeightMultiple: 1, fontFamily: minchoBold) // :272
    public static let headSubType = TypeToken(size: 9, weight: .regular, trackingEm: 0.34, fontFamily: gothicRegular) // :274
    public static let headCountType = TypeToken(size: 14, weight: .semibold, lineHeightMultiple: 1, fontFamily: minchoSemiBold) // :282
    public static let tabSubType = TypeToken(size: 9.5, weight: .regular, trackingEm: 0.26, uppercase: true, fontFamily: gothicRegular) // :312
    public static let railVertType = TypeToken(size: 24, weight: .semibold, trackingEm: 0.28, fontFamily: minchoSemiBold) // :244
    public static let railVertSmallType = TypeToken(size: 11, weight: .regular, trackingEm: 0.30, fontFamily: gothicRegular) // :251
    public static let backLinkType = TypeToken(size: 10.5, weight: .regular, trackingEm: 0.28, uppercase: true, fontFamily: gothicRegular) // :417
    public static let sealCharType = TypeToken(size: 21, weight: .bold, fontFamily: minchoExtraBold) // :395, :840 (40-unit source box)
}

// MARK: - Motion (§3.8)

extension ZenInkTheme {
    static let zenMotion = Motion(
        easeOut: .easeOut, easeDrawer: .easeDrawer, easeIO: .easeIO,
        panelEnter: MotionToken(0.520, .easeOut), // transform :212 (opacity itself is 340ms)
        panelExit: MotionToken(0.280, .easeOut), // transform :197 (opacity/filter are 240ms)
        expandMorph: MotionToken(0.620, .easeDrawer), // :198
        tabThumb: MotionToken(0.420, .easeDrawer), // :319
        appearanceThumb: MotionToken(0.380, .easeDrawer), // :461
        soundKnob: MotionToken(0.240, .easeOut), // :467
        checkboxFill: MotionToken(0.420, .easeOut), // :363
        tickDraw: MotionToken(0.360, .easeOut), // fill opacity :363
        strikethrough: MotionToken(0.560, .easeOut), // :382
        titleColorFade: MotionToken(0.460, .easeOut), // :371
        rowEntrance: MotionToken(0.500, .easeOut), // :342, :348
        flipMove: MotionToken(0.500, .easeOut), // Zen does not reflow; mirrors row entrance
        ring: MotionToken(0.950, .easeIO), // :484
        appearanceCrossfade: MotionToken(0.600, .easeOut), // :199
        hoverFade: MotionToken(0.240, .easeOut), // :342
        pressEcho: MotionToken(0.160, .easeOut), // :289
        counterFade: MotionToken(0.220, .easeOut), // :489
        checkboxSequence: CheckboxSequence(
            fillDuration: 0.420,
            fillKeyframes: [.init(scale: 0.2, fraction: 0.0), .init(scale: 1.0, fraction: 1.0)],
            tickDrawDuration: 0.360, tickDrawDelay: 0,
            fillFadeDuration: 0.360, ringFadeDuration: 0.300,
            completeReflowDelay: 0, uncheckReflowDelay: 0
        ),
        rowEntranceTransform: RowEntranceTransform(translateY: -10, scale: 1, duration: 0.500, blur: 6),
        panelEnterBlur: 7, panelExitBlur: 7 // .panel :204, :217; paper only in renderer
    )
}

// MARK: - Metrics and layout (§3.6, §3.10)

extension ZenInkTheme {
    static let zenMetrics = ThemeMetrics(
        panelCompactSize: CGSize(width: 380, height: 568), // .panel :186
        panelExpandedSize: CGSize(width: 604, height: 568), // :220
        panelCornerRadius: 22, railWidth: 194, mainColumnWidth: 380,
        ringRadius: 46.2, ringStrokeWidth: 6.05, // :564 rendered 132 / unit box 120
        compactRingDiameter: 38, compactRingStrokeWidth: 2.22, // :282, :565
        rowCornerRadius: 12, checkboxSize: 24, beakSize: 14,
        borderWidth: 1, progressSegments: 0, notchInsetFromRight: 26 // D9 deviation
    )

    static let zenLayout = ThemeLayout(
        railInsets: ThemeInsets(top: 30, leading: 22, bottom: 26, trailing: 22), // .rail-inner :239
        mainColumnInsets: ThemeInsets(top: 22, leading: 24, bottom: 0, trailing: 24), // .main :267
        mainColumnSpacing: 0, // region margins below express CSS flow spacing
        headerInsets: .zero, headerContentSpacing: 10, headerControlsSpacing: 8,
        headerTextSpacing: 11, headerTrailingAccessorySpacing: 8, // .head/:head-id/:head-right :270-280
        dividerInsets: ThemeInsets(top: 16, bottom: 4), dividerHeight: 12, // .divider :301
        tabInsets: ThemeInsets(top: 8, bottom: 2), tabHeight: 54,
        tabCornerRadius: 0, tabThumbInset: 0, tabTrackCornerRadius: 0,
        tabLabelSpacing: 0, // custom tab has no shared-label CSS source
        tabCellInsets: ThemeInsets(top: 9, leading: 4, bottom: 13, trailing: 4),
        tabSublineSpacing: 3, tabIndicatorHeight: 9, tabIndicatorBottomInset: 2, // :306-324
        stageTopSpacing: 6, stageInsets: .zero,
        listInsets: ThemeInsets(top: 6, leading: 2, bottom: 12, trailing: 2), listRowSpacing: 0, // :327-336
        rowInsets: ThemeInsets(top: 11, leading: 8, bottom: 11, trailing: 8),
        rowContentSpacing: 13, rowStackSpacing: 0, rowTrailingSpacing: 0, rowActionsSpacing: 0,
        rowTitleTrailingReserve: 62, // .title :369
        triageInsets: .zero, triageContentSpacing: 0, // no Zen mockup triage treatment
        composerInsets: ThemeInsets(top: 14, leading: 8, bottom: 12, trailing: 8),
        composerStackSpacing: 12, composerFieldSpacing: 12,
        composerFieldInsets: .zero, composerFieldMinimumHeight: 0, // borderless input :423-436
        footerInsets: ThemeInsets(top: 12, leading: 6, bottom: 18, trailing: 6), footerContentSpacing: 0, // :441
        emptyStateInsets: ThemeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        emptyStateContentSpacing: 0, emptyIconBottomSpacing: 22, emptyBodyTopSpacing: 10, // .empty :405-417
        clearedStateInsets: ThemeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        clearedStateContentSpacing: 0, clearedIconBottomSpacing: 22, clearedBodyTopSpacing: 10,
        clearedPeekTopSpacing: 26, clearedStateFillsAvailableSpace: true // .empty :405-417
    )
}

// MARK: - Near-silent sound set (§3.12; mockup :693-767)

extension ZenInkTheme {
    private static func pluck(_ frequency: Double, gain: Double, duration: Double) -> SoundComponent {
        // `Pluck` defaults exactly transcribe the mockup helper :726-741.
        .pluck(Pluck(frequency: frequency, peakGain: gain, duration: duration))
    }

    static let zenSoundSet = SoundSet(variants: [
        .complete: [SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 820, glideTo: 300, duration: 0.160, peakGain: 0.20, attack: 0.004)),
            .noise(NoiseSwoosh(duration: 0.040, peakGain: 0.10, bandpassStart: 1_900, bandpassEnd: 1_900, q: 1.1, attack: 0.0001, amplitudeTaperLinear: false))
        ])],
        .add: [261.63, 293.66, 349.23, 392.00, 440.00, 523.25].map { frequency in
            SoundRecipe([pluck(frequency, gain: 0.15, duration: 1.0)])
        },
        .uncheck: [SoundRecipe([pluck(174.61, gain: 0.09, duration: 0.7)])],
        .tabSwitch: [SoundRecipe([pluck(392.00, gain: 0.075, duration: 0.5)])],
        .panelOpen: [SoundRecipe([
            .noise(NoiseSwoosh(duration: 0.500, peakGain: 0.045, bandpassStart: 500, bandpassEnd: 2_200, q: 0.8, attack: 0.120, amplitudeTaperLinear: false)),
            pluck(293.66, gain: 0.06, duration: 0.6)
        ])],
        .panelClose: [SoundRecipe([
            .noise(NoiseSwoosh(duration: 0.360, peakGain: 0.04, bandpassStart: 2_000, bandpassEnd: 450, q: 0.8, attack: 0.0001, amplitudeTaperLinear: false)),
            pluck(220.00, gain: 0.06, duration: 0.6)
        ])],
        .toggleOn: [SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 1_400, glideTo: 700, duration: 0.060, peakGain: 0.09, attack: 0.003))
        ])],
        // Mockup has no off event; D3/D4 retain the quiet documented mirror.
        .toggleOff: [SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 1_400, glideTo: 700, duration: 0.060, peakGain: 0.06, attack: 0.003))
        ])]
    ])
}
