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

    // MARK: Structural capabilities (Phase 4 — defaults keep macOS behavior)

    /// Whether completed rows move into a separate "Completed" section with its
    /// own header, driven by the two-phase reflow choreography in `AppModel.toggle`.
    /// Default `true` (macOS). Arcade is `false`: done rows dim IN PLACE (opacity
    /// + strikethrough) in stored order, with no header and no reflow.
    var showsDoneSection: Bool { get }
    /// Whether the tab bar shows a live open-count badge per tab. Default `true`
    /// (macOS). Arcade is `false`: a small dot indicator takes its place instead
    /// (hidden on the active tab), never a number.
    var showsTabCountBadge: Bool { get }
    /// Whether task rows render as bordered "cabinet" cards (2px border, hard
    /// offset shadow, hover translate(-1,-1) + bigger shadow, press translate(2,2)
    /// + no shadow) instead of a flat hover/press highlight. Default `false`
    /// (macOS). Arcade is `true`.
    var usesCabinetRows: Bool { get }
    /// Label for the footer sound toggle, or `nil` to render no label (macOS: an
    /// icon-only switch). Arcade: `"SFX"`.
    var soundToggleLabel: String? { get }
    /// Whether this theme wants the Phase 5 completion-FX overlay (score-pop,
    /// coin burst, confetti on stage-clear) driven by `AppModel.arcadeFXEvent`.
    /// Default `false` (macOS, and every other theme) — `AppModel` never emits
    /// the event and `PanelRootView` never mounts the overlay. Arcade is `true`.
    var providesCompletionFX: Bool { get }
    /// Whether the expanded planning rail sits on the trailing (right) edge with the
    /// task column leading. Default `false` (macOS: rail leads/left). Arcade is `true`
    /// (mockup `.panel-inner { .main; .side }` — task column left, rail right).
    var railOnTrailing: Bool { get }
    /// Whether the footer appearance segment shows text labels (Auto/Light/Dark) next
    /// to each icon. Default `true` (macOS). Arcade is `false` (icon-only pill buttons).
    var showsAppearanceLabels: Bool { get }
    /// Whether header/row icon buttons render cabinet chrome at rest (2px border,
    /// `cab-2` fill, hard offset shadow) instead of the flat macOS "invisible until
    /// hover" style. Default `false` (macOS). Arcade is `true`.
    var usesCabinetIconButtons: Bool { get }
    /// Whether the composer + footer controls (add button, "+" glyph, sound switch)
    /// use the cabinet aesthetic: opaque accent add button that never dims, hard
    /// offset shadow, accent "+" glyph, squared sound switch. Default `false` (macOS).
    /// Arcade is `true`.
    var usesCabinetControls: Bool { get }
    /// Whether the all-cleared celebration COVERS the list area (replacing the task
    /// rows entirely while shown) instead of rendering above them as an additional
    /// element in the scroll content. Default `false` (macOS): `allClearedState()`
    /// renders above the (still-visible, dimmed) done rows, per the current sun
    /// celebration. Arcade is `true` (mockup `.victory { position:absolute; inset:0;
    /// background:var(--screen); }` fully occludes `.list` — the task rows are
    /// hidden, not merely covered by a smaller card, while the stage is cleared).
    var clearedStateCoversList: Bool { get }

    // MARK: Structural content builders (Phase 4 — primitives only; nil → shared
    // view keeps its current layout)

    /// Leading content for the header row, replacing the default greeting/date
    /// stack when non-nil. `score` is the live derived arcade score
    /// (`AppModel.arcadeScore`); themes that don't use it may ignore the
    /// parameter. Default `nil`. Arcade returns the brand mark + "ORDO" wordmark
    /// + a right-aligned "SCORE" mini readout. The caller (`HeaderView`) keeps
    /// its own trailing icon buttons (gear/expand) — this builder supplies ONLY
    /// the leading content, not the whole row.
    func headerLeading(score: Int) -> AnyView?
    /// A status row rendered between the tab bar and the task list, or `nil` to
    /// render none (the current macOS layout has no such row). `done`/`total`
    /// are the active tab's counts; `isToday` is `tab == .today`. Default `nil`.
    /// Arcade returns the big reactive number + two-line pixel caption + segbar
    /// (one segment per task, `done` filled from the left).
    func statusRow(done: Int, total: Int, isToday: Bool) -> AnyView?
    /// Full content for the expanded-panel side rail, or `nil` to keep the
    /// shared `RailView`'s current kicker/ring/stats/quote layout. All
    /// parameters are primitives already resolved by `AppModel`
    /// (`railDone`/`railRemaining`/`railTotal`/`arcadeScore`/`arcadeBest`/
    /// `arcadeStreak`). Default `nil`. Arcade returns the STATS-labeled card
    /// stack (HIGH SCORE / SCORE / STREAK / CLEARED) plus the mascot card.
    func railContent(done: Int, total: Int, remaining: Int, score: Int, best: Int, streak: Int) -> AnyView?
    /// Composer placeholder text, or `nil` to keep the shared default
    /// (`UIStrings.composerPlaceholder`). `isToday` is `tab == .today`. Default
    /// `nil`. Arcade returns `"ADD A TASK…"` (Today) / `"ADD A QUEST…"` (Quests).
    func composerPlaceholder(isToday: Bool) -> String?
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

    // MARK: Structural capability defaults (macOS + every existing theme get
    // these for free; only `ArcadeTheme` overrides them).

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

    public func headerLeading(score: Int) -> AnyView? { nil }
    public func statusRow(done: Int, total: Int, isToday: Bool) -> AnyView? { nil }
    public func railContent(done: Int, total: Int, remaining: Int, score: Int, best: Int, streak: Int) -> AnyView? { nil }
    public func composerPlaceholder(isToday: Bool) -> String? { nil }
}

extension ResolvedAppearance {
    /// Resolve from a SwiftUI `ColorScheme`.
    public init(_ scheme: ColorScheme) {
        self = (scheme == .dark) ? .dark : .light
    }
}
