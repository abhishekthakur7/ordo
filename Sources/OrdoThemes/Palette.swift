import SwiftUI

// MARK: - Identity & resolution enums

/// Stable identifier for a shipping theme. All five V1 themes have a case reserved
/// so lookup is type-safe and future themes drop in without touching call sites;
/// only the themes present in `ThemeRegistry.all` actually resolve.
public enum ThemeID: String, CaseIterable, Sendable, Hashable {
    case macOS = "macos"
    case arcade
    case zenInk = "zen-ink"
    case swiss
    case instrument
}

/// The concrete light/dark appearance a palette is being asked for. Appearance
/// *resolution* (System → light/dark) is the UI's job; a theme only ever sees a
/// resolved value. Light and dark are independently art-directed — never inversions.
public enum ResolvedAppearance: Sendable, Hashable {
    case light
    case dark
}

/// Accessibility flags that reshape a palette (ARCHITECTURE §4.6). Reduce-Motion is
/// handled per-animation on `MotionToken`, not here.
public struct AccessibilityOptions: Sendable, Hashable {
    /// Swap vibrancy/blur for an opaque fallback surface.
    public var reduceTransparency: Bool
    /// Thicken hairlines and darken muted grays for legibility.
    public var increaseContrast: Bool

    public init(reduceTransparency: Bool = false, increaseContrast: Bool = false) {
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
    }

    /// No accessibility adjustments — the art-directed default.
    public static let standard = AccessibilityOptions()
}

// MARK: - Color helpers

extension Color {
    /// sRGB from 0–255 channels plus alpha, matching the mockup's `rgba()` values exactly.
    static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    /// sRGB from a 24-bit hex literal (e.g. `0x0A7BFF`).
    static func hex(_ value: UInt32, alpha: Double = 1) -> Color {
        let r = Double((value >> 16) & 0xFF)
        let g = Double((value >> 8) & 0xFF)
        let b = Double(value & 0xFF)
        return .rgba(r, g, b, alpha)
    }
}

// MARK: - Shadow & material intent

/// One CSS `box-shadow` layer. `blur` is the CSS blur radius; SwiftUI's `.shadow`
/// radius is roughly half of that, exposed as `swiftUIRadius`.
public struct ShadowLayer: Sendable, Hashable {
    public var color: Color
    public var x: Double
    public var y: Double
    public var blur: Double

    public init(color: Color, x: Double, y: Double, blur: Double) {
        self.color = color
        self.x = x
        self.y = y
        self.blur = blur
    }

    /// SwiftUI `.shadow(radius:)` approximation of the CSS blur.
    public var swiftUIRadius: Double { blur / 2 }
}

/// Closest NSVisualEffectView material preset for a theme's glass surface.
/// OrdoApp maps this to `NSVisualEffectView.Material` when it builds the panel host.
public enum MaterialKind: Sendable, Hashable {
    case popover
    case menu
    case hudWindow
    case underWindowBackground
    case sidebar
    case headerView
    case fullScreenUI
}

/// How the effect view blends with what's behind it.
public enum MaterialBlending: Sendable, Hashable {
    case behindWindow
    case withinWindow
}

/// Declarative description of the panel's vibrancy surface (rendered as an
/// `NSVisualEffectView`); raw CSS numbers are carried for fidelity. When `usesFallback` is
/// true (Reduce Transparency), render `fallbackOpaque` as a flat fill and skip the blur.
public struct MaterialIntent: Sendable, Hashable {
    /// CSS `backdrop-filter: blur()` radius, in px. (macOS glass ≈ 40.)
    public var blurRadius: Double
    /// CSS `saturate()` multiplier. (macOS glass ≈ 1.8.)
    public var saturation: Double
    /// Whether the surface should use vibrancy (label vibrancy on top of blur).
    public var vibrancy: Bool
    /// Semi-transparent tint painted over the blur (the CSS `--panel-bg`).
    public var tint: Color
    /// The top-edge sheen gradient start color (the CSS `--panel-tint`).
    public var sheen: Color
    /// Opaque surface to use when Reduce Transparency is on (no blur).
    public var fallbackOpaque: Color
    /// True when the caller must render `fallbackOpaque` instead of the blur.
    public var usesFallback: Bool
    /// Recommended NSVisualEffectView preset.
    public var material: MaterialKind
    /// Recommended blending mode.
    public var blending: MaterialBlending

    public init(
        blurRadius: Double,
        saturation: Double,
        vibrancy: Bool,
        tint: Color,
        sheen: Color,
        fallbackOpaque: Color,
        usesFallback: Bool,
        material: MaterialKind,
        blending: MaterialBlending
    ) {
        self.blurRadius = blurRadius
        self.saturation = saturation
        self.vibrancy = vibrancy
        self.tint = tint
        self.sheen = sheen
        self.fallbackOpaque = fallbackOpaque
        self.usesFallback = usesFallback
        self.material = material
        self.blending = blending
    }
}

// MARK: - Cabinet surface (opaque, non-vibrancy)

/// A zero-blur offset shadow, used by the Arcade cabinet surface for its hard
/// drop shadow (no glow, no softness).
public struct HardShadow: Sendable, Hashable {
    public var color: Color
    public var x: Double
    public var y: Double

    public init(color: Color, x: Double, y: Double) {
        self.color = color
        self.x = x
        self.y = y
    }
}

/// Describes a CRT/LCD-style screen overlay (scanlines, grain, vignette, pixel grid).
/// `.none` (the static default) draws nothing, which is what every macOS palette gets.
public struct OverlayStyle: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case none
        case scanlines
        case lcdGrain
        /// A static, tiled paper-noise image. Its opacity and blend mode live
        /// on `GrainStyle`, carried by a paper surface.
        case paperGrain
    }

    public var kind: Kind
    /// Opacity of the repeating scanline lines (0–1).
    public var scanlineOpacity: Double
    /// Vertical period of the scanline repeat, in points.
    public var scanlinePitch: Double
    /// Opacity of a radial vignette darkening the corners (0–1).
    public var vignetteOpacity: Double
    /// Opacity of a faint pixel/grid overlay (0–1).
    public var gridOpacity: Double

    public init(
        kind: Kind,
        scanlineOpacity: Double = 0,
        scanlinePitch: Double = 3,
        vignetteOpacity: Double = 0,
        gridOpacity: Double = 0
    ) {
        self.kind = kind
        self.scanlineOpacity = scanlineOpacity
        self.scanlinePitch = scanlinePitch
        self.vignetteOpacity = vignetteOpacity
        self.gridOpacity = gridOpacity
    }

    /// No overlay — the default for every surface that isn't an arcade cabinet.
    public static let none = OverlayStyle(kind: .none)
}

/// The opaque "cabinet" panel surface (Arcade), mutually exclusive with macOS
/// vibrancy: a flat fill, a border, a hard offset shadow, a top sheen
/// highlight, and an optional CRT/LCD overlay descriptor.
public struct CabinetStyle: Sendable, Hashable {
    /// Opaque panel fill.
    public var fill: Color
    /// Panel border color.
    public var border: Color
    /// Border stroke width in points.
    public var borderWidth: Double
    /// Panel corner radius in points.
    public var cornerRadius: Double
    /// The hard, zero-blur offset shadow.
    public var hardShadow: HardShadow
    /// Start color of the top sheen highlight gradient.
    public var topSheen: Color
    /// CRT/LCD overlay descriptor; `.none` draws nothing.
    public var overlay: OverlayStyle

    public init(
        fill: Color,
        border: Color,
        borderWidth: Double = 2,
        cornerRadius: Double = 16,
        hardShadow: HardShadow,
        topSheen: Color,
        overlay: OverlayStyle = .none
    ) {
        self.fill = fill
        self.border = border
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.hardShadow = hardShadow
        self.topSheen = topSheen
        self.overlay = overlay
    }
}

/// A tiled, deterministic noise treatment for a paper surface. An opacity of
/// zero is an explicit no-grain accessibility fallback.
public struct GrainStyle: Sendable, Hashable {
    public enum Blend: Sendable, Hashable {
        case multiply
        case overlay
    }

    /// Opacity of the grain layer (0 disables it).
    public var opacity: Double
    /// Blend mode used to composite the grain over the paper fill.
    public var blend: Blend
    /// Edge length of one repeated noise tile, in points.
    public var tile: Double

    public init(opacity: Double, blend: Blend, tile: Double) {
        self.opacity = opacity
        self.blend = blend
        self.tile = tile
    }
}

/// An opaque paper panel: a vertical fill, fine border, soft shadow stack,
/// inset top highlight, and optional tiled grain.
public struct PaperStyle: Sendable, Hashable {
    public var fillTop: Color
    public var fillBottom: Color
    public var border: Color
    public var borderWidth: Double
    public var cornerRadius: Double
    public var innerHighlight: Color
    public var shadow: [ShadowLayer]
    public var grain: GrainStyle
    public var beakCornerRadius: Double

    public init(
        fillTop: Color,
        fillBottom: Color,
        border: Color,
        borderWidth: Double,
        cornerRadius: Double,
        innerHighlight: Color,
        shadow: [ShadowLayer],
        grain: GrainStyle,
        beakCornerRadius: Double = 0
    ) {
        self.fillTop = fillTop
        self.fillBottom = fillBottom
        self.border = border
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.innerHighlight = innerHighlight
        self.shadow = shadow
        self.grain = grain
        self.beakCornerRadius = beakCornerRadius
    }
}

/// Which panel surface a theme renders: macOS vibrancy/glass (`.vibrancy`),
/// an opaque arcade cabinet (`.cabinet`), or an opaque paper panel (`.paper`).
public enum SurfaceStyle: Sendable, Hashable {
    case vibrancy(MaterialIntent)
    case cabinet(CabinetStyle)
    case paper(PaperStyle)
}

// MARK: - Palette

/// A fully art-directed color set for one appearance. Every value is transcribed
/// from the mockup's CSS custom properties. Reduce-Transparency and Increase-Contrast
/// variants are produced by `Theme.palette(for:accessibility:)`, not stored globally.
public struct Palette: Sendable, Hashable {
    // Ink hierarchy (text)
    public var ink: Color
    public var ink2: Color
    public var ink3: Color
    public var inkFaint: Color

    // Rows & fields
    public var rowHover: Color
    public var rowPress: Color
    public var fieldBackground: Color
    public var fieldLine: Color

    // Segmented control
    public var segmentBackground: Color
    public var segmentThumb: Color
    public var segmentThumbShadow: [ShadowLayer]

    // Accent
    public var accent: Color
    public var accentSoft: Color
    public var accentInk: Color

    // Structure
    public var checkRing: Color
    public var divider: Color

    // Panel surface
    public var material: MaterialIntent
    public var panelHairline: Color       // inner light hairline (`--panel-hair`)
    public var panelHairlineOuter: Color  // outer dark hairline (`--panel-hair-out`)
    public var innerHighlight: Color      // top inset highlight (`--panel-inner`)
    public var panelShadow: [ShadowLayer]

    /// Hairline stroke width in points; thickens under Increase Contrast.
    public var hairlineWidth: Double

    /// Which panel surface to render: macOS vibrancy (`.vibrancy(material)`, the
    /// default derived from `material` below) or an opaque Arcade cabinet.
    public var surface: SurfaceStyle

    // Coin / gold accent (Arcade). Defaults to `.clear` — unused by non-Arcade themes.
    public var coin: Color
    public var coinInk: Color
    /// Accent glow color (e.g. for focus/press glows).
    public var glow: Color
    /// Coin-specific glow color.
    public var coinGlow: Color

    public init(
        ink: Color, ink2: Color, ink3: Color, inkFaint: Color,
        rowHover: Color, rowPress: Color, fieldBackground: Color, fieldLine: Color,
        segmentBackground: Color, segmentThumb: Color, segmentThumbShadow: [ShadowLayer],
        accent: Color, accentSoft: Color, accentInk: Color,
        checkRing: Color, divider: Color,
        material: MaterialIntent,
        panelHairline: Color, panelHairlineOuter: Color, innerHighlight: Color,
        panelShadow: [ShadowLayer],
        hairlineWidth: Double,
        surface: SurfaceStyle? = nil,
        coin: Color = .clear, coinInk: Color = .clear, glow: Color = .clear, coinGlow: Color = .clear
    ) {
        self.ink = ink
        self.ink2 = ink2
        self.ink3 = ink3
        self.inkFaint = inkFaint
        self.rowHover = rowHover
        self.rowPress = rowPress
        self.fieldBackground = fieldBackground
        self.fieldLine = fieldLine
        self.segmentBackground = segmentBackground
        self.segmentThumb = segmentThumb
        self.segmentThumbShadow = segmentThumbShadow
        self.accent = accent
        self.accentSoft = accentSoft
        self.accentInk = accentInk
        self.checkRing = checkRing
        self.divider = divider
        self.material = material
        self.panelHairline = panelHairline
        self.panelHairlineOuter = panelHairlineOuter
        self.innerHighlight = innerHighlight
        self.panelShadow = panelShadow
        self.hairlineWidth = hairlineWidth
        self.surface = surface ?? .vibrancy(material)
        self.coin = coin
        self.coinInk = coinInk
        self.glow = glow
        self.coinGlow = coinGlow
    }
}
