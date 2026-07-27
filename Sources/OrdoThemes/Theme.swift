import SwiftUI
import AppKit
import OrdoCore

/// The composer treatment. `card` and `cabinet` reproduce the two existing
/// shared-view branches; `ink` is the borderless paper treatment.
public enum ComposerStyle: Sendable, Hashable {
    case card
    case cabinet
    case ink
}

/// Which content appears in each appearance-selector segment.
public enum AppearanceSegmentStyle: Sendable, Hashable {
    case iconAndLabel
    case iconOnly
    case labelOnly
}

/// The footer sound-control treatment.
public enum SoundControlStyle: Sendable, Hashable {
    case switchTrack
    case cabinetSwitch
    case ghostIcon
}

/// The selection indicator used by the tab bar.
public enum TabIndicatorStyle: Sendable, Hashable {
    case thumb
    case custom
}

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
    /// Shared-view geometry. Defaults exactly to the existing macOS layout;
    /// themes can override it once the shared wrappers consume these tokens.
    var layout: ThemeLayout { get }
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

    // MARK: Structural capabilities (defaults keep macOS behavior)

    /// Whether completed rows move into a separate "Completed" section. Default
    /// `true`. Arcade is `false`: done rows dim in place, in stored order.
    var showsDoneSection: Bool { get }
    /// Whether the tab bar shows a live open-count badge per tab. Default
    /// `true`. Arcade is `false`: a small dot indicator takes its place.
    var showsTabCountBadge: Bool { get }
    /// Whether task rows render as bordered "cabinet" cards with a hard offset
    /// shadow instead of a flat hover/press highlight. Default `false`.
    var usesCabinetRows: Bool { get }
    /// Label for the footer sound toggle, or `nil` for no label (an icon-only
    /// switch). Arcade: `"SFX"`.
    var soundToggleLabel: String? { get }
    /// Whether this theme wants the completion-FX overlay (score-pop, coin
    /// burst, confetti on stage-clear) driven by `AppModel.arcadeFXEvent`.
    /// Default `false`.
    var providesCompletionFX: Bool { get }
    /// Whether the expanded planning rail sits on the trailing (right) edge
    /// with the task column leading. Default `false` (rail leads/left).
    var railOnTrailing: Bool { get }
    /// Whether the footer appearance segment shows text labels next to each
    /// icon. Default `true`. Arcade is `false` (icon-only pill buttons).
    var showsAppearanceLabels: Bool { get }
    /// Whether header/row icon buttons render cabinet chrome at rest instead
    /// of the flat "invisible until hover" style. Default `false`.
    var usesCabinetIconButtons: Bool { get }
    /// Whether the composer + footer controls use the cabinet aesthetic (an
    /// opaque add button that never dims, hard offset shadow, squared sound
    /// switch). Default `false`.
    var usesCabinetControls: Bool { get }
    /// Whether the all-cleared celebration covers the list area (replacing the
    /// task rows) instead of rendering above them. Default `false`.
    var clearedStateCoversList: Bool { get }
    /// Whether a covering all-cleared state offers an interactive peek back to
    /// the list. Default `false` preserves current behavior.
    var clearedStateIsPeekable: Bool { get }
    /// Whether the main column expands to fill panel space left by its rail.
    /// Default `false` preserves the current fixed-width behavior.
    var mainColumnFlexes: Bool { get }

    /// Composer presentation, derived from the existing cabinet flag by
    /// default so macOS and Arcade retain their current branch.
    var composerStyle: ComposerStyle { get }
    /// Appearance-selector presentation, derived from the existing label flag.
    var appearanceSegmentStyle: AppearanceSegmentStyle { get }
    /// Sound-control presentation, derived from the existing cabinet flag.
    var soundControlStyle: SoundControlStyle { get }
    /// Tab indicator presentation. Existing themes use the shared thumb.
    var tabIndicatorStyle: TabIndicatorStyle { get }

    // MARK: Structural content builders (primitives only; nil → shared view
    // keeps its current layout)

    /// Leading content for the header row, replacing the default greeting/date
    /// stack when non-nil. `score` is the live derived arcade score. Default `nil`.
    func headerLeading(score: Int) -> AnyView?
    /// A status row rendered between the tab bar and the task list, or `nil`
    /// for none. `done`/`total` are the active tab's counts. Default `nil`.
    func statusRow(done: Int, total: Int, isToday: Bool) -> AnyView?
    /// Full content for the expanded-panel side rail, or `nil` to keep the
    /// shared `RailView` layout. Parameters are primitives already resolved
    /// by `AppModel`. Default `nil`.
    func railContent(done: Int, total: Int, remaining: Int, score: Int, best: Int, streak: Int) -> AnyView?
    /// Composer placeholder text, or `nil` to keep the shared default.
    /// `isToday` is `tab == .today`. Default `nil`.
    func composerPlaceholder(isToday: Bool) -> String?
    /// Content below the header and above the tabs (for example, a divider).
    func headerAccessory() -> AnyView?
    /// Content before the header's settings/expand controls.
    func headerTrailingAccessory(done: Int, total: Int, expanded: Bool) -> AnyView?
    /// Complete tab-bar replacement. `nil` keeps the shared segmented tabs.
    func tabBarContent(
        tab: TaskList,
        remaining: @escaping (TaskList) -> Int,
        onSelect: @escaping (TaskList) -> Void
    ) -> AnyView?
    /// Content preceding row actions, replacing the normal age/index marker.
    func rowTrailingAccessory(done: Bool, age: Int, triage: Bool, index: Int?) -> AnyView?
    /// All-cleared content with an optional escape hatch back to the list.
    func allClearedState(onPeek: @escaping () -> Void) -> AnyView
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

    // MARK: Structural capability defaults (only `ArcadeTheme` overrides these)

    public var showsDoneSection: Bool { true }
    public var showsTabCountBadge: Bool { true }
    public var usesCabinetRows: Bool { false }
    public var soundToggleLabel: String? { nil }
    public var providesCompletionFX: Bool { false }
    public var railOnTrailing: Bool { false }
    public var showsAppearanceLabels: Bool { true }
    public var usesCabinetIconButtons: Bool { false }
    public var usesCabinetControls: Bool { false }
    public var clearedStateCoversList: Bool { false }
    public var clearedStateIsPeekable: Bool { false }
    public var mainColumnFlexes: Bool { false }

    public var composerStyle: ComposerStyle { usesCabinetControls ? .cabinet : .card }
    public var appearanceSegmentStyle: AppearanceSegmentStyle {
        showsAppearanceLabels ? .iconAndLabel : .iconOnly
    }
    public var soundControlStyle: SoundControlStyle {
        usesCabinetControls ? .cabinetSwitch : .switchTrack
    }
    public var tabIndicatorStyle: TabIndicatorStyle { .thumb }
    public var layout: ThemeLayout { .legacy }

    public func headerLeading(score: Int) -> AnyView? { nil }
    public func statusRow(done: Int, total: Int, isToday: Bool) -> AnyView? { nil }
    public func railContent(done: Int, total: Int, remaining: Int, score: Int, best: Int, streak: Int) -> AnyView? { nil }
    public func composerPlaceholder(isToday: Bool) -> String? { nil }
    public func headerAccessory() -> AnyView? { nil }
    public func headerTrailingAccessory(done: Int, total: Int, expanded: Bool) -> AnyView? { nil }
    public func tabBarContent(
        tab: TaskList,
        remaining: @escaping (TaskList) -> Int,
        onSelect: @escaping (TaskList) -> Void
    ) -> AnyView? { nil }
    public func rowTrailingAccessory(done: Bool, age: Int, triage: Bool, index: Int?) -> AnyView? { nil }
    public func allClearedState(onPeek: @escaping () -> Void) -> AnyView { allClearedState() }
}

extension ResolvedAppearance {
    /// Resolve from a SwiftUI `ColorScheme`.
    public init(_ scheme: ColorScheme) {
        self = (scheme == .dark) ? .dark : .light
    }
}
