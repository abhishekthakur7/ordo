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

    public init(
        ink: Color, ink2: Color, ink3: Color, inkFaint: Color,
        rowHover: Color, rowPress: Color, fieldBackground: Color, fieldLine: Color,
        segmentBackground: Color, segmentThumb: Color, segmentThumbShadow: [ShadowLayer],
        accent: Color, accentSoft: Color, accentInk: Color,
        checkRing: Color, divider: Color,
        material: MaterialIntent,
        panelHairline: Color, panelHairlineOuter: Color, innerHighlight: Color,
        panelShadow: [ShadowLayer],
        hairlineWidth: Double
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
    }
}
