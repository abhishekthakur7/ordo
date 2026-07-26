import SwiftUI
import AppKit

/// The design-system contract (PLAN.md C1); OrdoUI/OrdoApp code against this surface only.
/// Light/dark palettes are independently art-directed (never inversions); signature views take
/// primitives only; accessibility reshapes the palette, and Reduce-Motion the `MotionToken`s.
public protocol Theme: Sendable {

    // MARK: Identity

    /// Stable id used for persistence and registry lookup.
    var id: ThemeID { get }
    /// Human-readable name for the theme picker.
    var displayName: String { get }

    // MARK: Display strings (theme voice)

    /// Time-of-day greeting. The theme owns the thresholds (part of its voice).
    func greeting(forHour hour: Int) -> String
    /// Label for the Today tab.
    var todayTabLabel: String { get }
    /// Label for the long-term tab (macOS: "Horizon"; domain type stays `.longterm`).
    var longtermTabLabel: String { get }
    /// Label for the completed-section header (the count is appended by the header view).
    var doneSectionLabel: String { get }
    /// First-run empty-state title.
    var firstRunTitle: String { get }
    /// First-run empty-state body copy.
    var firstRunMessage: String { get }
    /// All-cleared (every Today task done) title.
    var allClearTitle: String { get }
    /// All-cleared body copy.
    var allClearMessage: String { get }

    // MARK: Tokens

    /// The color set for an appearance, adjusted for accessibility. Light and dark are
    /// independently art-directed. See the `palette(for:)` convenience for the common case.
    func palette(for appearance: ResolvedAppearance, accessibility: AccessibilityOptions) -> Palette
    /// Typographic scale (sizes/weights/tracking) for this theme.
    var typeScale: TypeScale { get }
    /// Motion tokens (curves + durations + Reduce-Motion variants + keyframe specs).
    var motion: Motion { get }
    /// Layout metrics (panel sizes, radii, ring geometry).
    var metrics: ThemeMetrics { get }
    /// Declarative sound set for all eight `SoundEvent`s.
    var soundSet: SoundSet { get }

    // MARK: Signature views (primitives only)

    /// The hero checkbox with done/hover/press states and the full completion sequence.
    func checkbox(done: Bool, hover: Bool, pressed: Bool) -> AnyView
    /// A task title with the completed treatment (strikethrough draw + color fade).
    func taskTitle(_ text: String, done: Bool) -> AnyView
    /// The age marker (`"2d"` etc). Age 0 renders nothing; `triage` (age ≥ 7) styles it up.
    func ageMarker(days: Int, triage: Bool) -> AnyView
    /// Compact progress element (small ring) for the collapsed panel.
    func progressCompact(done: Int, total: Int) -> AnyView
    /// Expanded progress ring (rail) with percentage label.
    func progressRing(done: Int, total: Int) -> AnyView
    /// The completed-section header (label + count + rule).
    func doneSectionHeader(count: Int) -> AnyView
    /// First-run empty state (theme-voiced onboarding).
    func firstRunEmptyState() -> AnyView
    /// All-cleared celebration state (pulsing sun + copy).
    func allClearedState() -> AnyView
    /// The menu-bar status glyph as a template `NSImage` (system-tinted).
    func menuBarGlyphImage(pointSize: CGFloat) -> NSImage
}

extension Theme {
    /// The palette with no accessibility adjustments — the common case.
    public func palette(for appearance: ResolvedAppearance) -> Palette {
        palette(for: appearance, accessibility: .standard)
    }

    /// Menu-bar glyph at the default 18 pt.
    public func menuBarGlyphImage() -> NSImage {
        menuBarGlyphImage(pointSize: 18)
    }
}

extension ResolvedAppearance {
    /// Resolve from a SwiftUI `ColorScheme`.
    public init(_ scheme: ColorScheme) {
        self = (scheme == .dark) ? .dark : .light
    }
}
