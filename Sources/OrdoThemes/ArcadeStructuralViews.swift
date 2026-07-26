import SwiftUI

// MARK: - Environment → palette bridge
//
// Mirrors `ArcadeSignatureViews.Themed` / `MacOSSignatureViews.Themed` exactly:
// reads the live appearance + accessibility environment and hands the resolved
// palette (and Reduce-Motion flag) to its content, keeping every structural
// builder's parameters primitives-only while still honoring System/Light/Dark
// and a11y. Duplicated per-file (rather than shared) to match the existing
// signature-view file layout.

private struct Themed<Content: View>: View {
    let theme: ArcadeTheme
    @ViewBuilder let content: (Palette, Bool) -> Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let palette = theme.palette(
            for: ResolvedAppearance(scheme),
            accessibility: AccessibilityOptions(
                reduceTransparency: reduceTransparency,
                increaseContrast: contrast == .increased
            )
        )
        content(palette, reduceMotion)
    }
}

// MARK: - Ad-hoc type roles
//
// The mockup's `score-mini .lbl` (header "SCORE" caption) and `.stat-big .k`
// ("HIGH SCORE" caption) share one CSS rule not otherwise represented in
// `TypeScale` or the arcade static token set: 6px pixel, `--ink-3`, ls 1px.
// `.stat-sm .k` / `.stat-card.stat-sm .k` (SCORE / STREAK / CLEARED TODAY
// captions) are already mapped to `theme.typeScale.railLine` (6px, ls 0.5px)
// per the doc comment on that token — reused as-is below.
private let arcadeMiniLabelType = TypeToken(
    size: 6, weight: .regular, trackingEm: 1.0 / 6,
    fontFamily: .named(FontRegistrar.pressStart2PFamily)
)

// MARK: - Header leading (brand + score)

/// The mockup `.head` leading content (`.brand` + `.head-spacer` + `.score-mini`):
/// the pixel Ordo glyph in its bordered box, the "ORDO" wordmark, a flexible
/// spacer, then a right-aligned SCORE readout. Deliberately excludes the
/// trailing icon buttons (gear/expand) — `HeaderView` keeps those.
struct ArcadeHeaderLeading: View {
    let theme: ArcadeTheme
    let score: Int

    var body: some View {
        Themed(theme: theme) { palette, _ in
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(palette.accent, lineWidth: theme.metrics.borderWidth)
                    ArcadeCheckStaircase()
                        .fill(palette.accent, style: FillStyle(antialiased: false))
                        .frame(width: 15, height: 15)
                }
                .frame(width: 26, height: 26)
                .shadow(color: palette.glow, radius: 6)
                .shadow(color: palette.glow, radius: 1)

                Text("ORDO")
                    .typeToken(ArcadeTheme.brandType)
                    .foregroundStyle(palette.ink)
                    .shadow(color: palette.glow, radius: 4)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 5) {
                    Text("SCORE")
                        .typeToken(arcadeMiniLabelType)
                        .foregroundStyle(palette.ink3)
                    Text("\(score)")
                        .typeToken(ArcadeTheme.scoreType)
                        .foregroundStyle(palette.coin)
                        .shadow(color: palette.coinGlow, radius: 6)
                        .shadow(color: palette.coinGlow, radius: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Score \(score)")
            }
        }
    }
}

// MARK: - Status row (reactive progress: big number + segbar)

/// The mockup `.status` row: a big reactive number + two-line pixel caption
/// (`.remain`), then a segmented bar with one segment per task (`.segbar`).
/// Today tab: number = tasks left, caption "LEFT/TODAY" ("TASK/LEFT" when
/// exactly one remains). Quests tab: number = done count, caption
/// "OF {total}/DONE".
struct ArcadeStatusRow: View {
    let theme: ArcadeTheme
    let done: Int
    let total: Int
    let isToday: Bool

    private var left: Int { max(0, total - done) }

    private var displayNumber: Int { isToday ? left : done }

    private var captionLines: (String, String) {
        if isToday {
            return left == 1 ? ("TASK", "LEFT") : ("LEFT", "TODAY")
        }
        return ("OF \(total)", "DONE")
    }

    private var accessibilitySummary: String {
        isToday
            ? (left == 1 ? "1 task left today" : "\(left) tasks left today")
            : "\(done) of \(total) done"
    }

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            // Mockup `.status { display:flex; align-items:center; gap:12px;
            // padding:12px 15px 10px }` — the whole row is vertically centered and
            // inset 15px from the panel edges (so the big number never collides with
            // the left border), with the `.remain` number+caption baseline-aligned.
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(displayNumber)")
                        .typeToken(ArcadeTheme.statusNumberType)
                        .foregroundStyle(palette.accent)
                        .shadow(color: palette.glow, radius: 6)
                        .shadow(color: palette.glow, radius: 1)
                        .fixedSize()

                    VStack(alignment: .leading, spacing: 0) {
                        Text(captionLines.0)
                        Text(captionLines.1)
                    }
                    .typeToken(theme.typeScale.ringSub)
                    .foregroundStyle(palette.ink3)
                    .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)

                segbar(palette: palette, reduceMotion: reduceMotion)
            }
            .padding(EdgeInsets(top: 12, leading: 15, bottom: 10, trailing: 15))
        }
    }

    @ViewBuilder
    private func segbar(palette: Palette, reduceMotion: Bool) -> some View {
        if total <= 0 {
            // Graceful empty state: a single faint placeholder track, no segments.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(palette.checkRing, lineWidth: 1.5)
                .frame(height: 14)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        } else {
            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { index in
                    let filled = index < done
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(filled ? palette.accent : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .strokeBorder(filled ? palette.accent : palette.checkRing, lineWidth: 1.5)
                        )
                        .shadow(color: filled ? palette.glow : .clear, radius: 3)
                        // `.seg` transitions background/border-color/transform at
                        // 260ms ease-out — no named `MotionToken` matches that
                        // exact duration+curve except `strikethrough`'s (reused
                        // here for its numbers, not its semantic role).
                        .animation(theme.motion.strikethrough.animation(reduceMotion: reduceMotion), value: filled)
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Rail content (STATS cards + mascot)

/// The mockup `.side-inner`: a "STATS" `side-h` kicker, a HIGH SCORE `stat-big`
/// card, a two-up `stat-row` (SCORE / STREAK), a CLEARED TODAY card, and a
/// bottom-pinned mascot card. Width is fixed to `theme.metrics.railWidth`.
///
/// Every pixel-text group below (`sideHeader`, the HIGH SCORE `VStack`, each
/// `smallStat`) wears `.pixelSnappedHeight()`. The un-hinted "Press Start 2P"
/// face reports fractional intrinsic line-heights at these tiny sizes (6–8px);
/// left alone, that fraction accumulates down this tightly-spaced (8–9pt) outer
/// `VStack` — each sibling's absolute Y-origin inherits the previous ones'
/// fractional heights — landing every downstream label on a half-pixel row,
/// which for a hard-edged pixel font reads as a doubled/ghosted stroke. The
/// header's "SCORE" mini-label (same type token, `ArcadeHeaderLeading`) has
/// nothing stacked above it in its own tree, so it never inherits a fraction —
/// which is why it renders clean while the rail's labels didn't. Rounding each
/// group's own height up to a whole point, one at a time, stops the fraction
/// from compounding onto the next.
struct ArcadeRailContent: View {
    let theme: ArcadeTheme
    let done: Int
    let total: Int
    let remaining: Int
    let score: Int
    let best: Int
    let streak: Int

    var body: some View {
        Themed(theme: theme) { palette, _ in
            VStack(alignment: .leading, spacing: 14) {
                sideHeader(palette: palette)

                statCard(palette: palette) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("HIGH SCORE")
                            .typeToken(arcadeMiniLabelType)
                            .foregroundStyle(palette.ink3)
                        Text("\(best)")
                            .typeToken(ArcadeTheme.statBigType)
                            .foregroundStyle(palette.coin)
                            .shadow(color: palette.coinGlow, radius: 8)
                            .shadow(color: palette.coinGlow, radius: 1)
                    }
                    .pixelSnappedHeight()
                }

                HStack(spacing: 10) {
                    statCard(palette: palette) {
                        smallStat(key: "SCORE", value: "\(score)", palette: palette)
                    }
                    statCard(palette: palette) {
                        smallStat(key: "STREAK", value: "×\(streak)", palette: palette)
                    }
                }

                statCard(palette: palette) {
                    smallStat(key: "CLEARED TODAY", value: "\(done) / \(total)", palette: palette)
                }

                Spacer(minLength: 0)

                mascotCard(palette: palette)
            }
            .padding(EdgeInsets(top: 16, leading: 15, bottom: 16, trailing: 15))
            .frame(width: theme.metrics.railWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func sideHeader(palette: Palette) -> some View {
        HStack(spacing: 6) {
            Text("STATS")
                .typeToken(theme.typeScale.railKicker)
                .foregroundStyle(palette.ink3)
                .fixedSize()
            Rectangle()
                .fill(palette.divider)
                .frame(height: 2)
        }
        .pixelSnappedHeight()
    }

    @ViewBuilder
    private func smallStat(key: String, value: String, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(key)
                .typeToken(theme.typeScale.railLine)
                .foregroundStyle(palette.ink3)
            Text(value)
                .typeToken(ArcadeTheme.statSmallType)
                .foregroundStyle(palette.accent)
                .shadow(color: palette.glow, radius: 6)
                .shadow(color: palette.glow, radius: 1)
        }
        .pixelSnappedHeight()
        .accessibilityElement(children: .combine)
    }

    /// `.stat-card`: `--screen` fill, 2px `--line` border, r8, hard 2×2 shadow.
    @ViewBuilder
    private func statCard<Content: View>(palette: Palette, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous)
                    .fill(palette.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: theme.metrics.borderWidth)
            )
            .shadow(color: hardShadowColor(palette), radius: 0, x: 2, y: 2)
    }

    @ViewBuilder
    private func mascotCard(palette: Palette) -> some View {
        VStack(spacing: 8) {
            // JUDGMENT CALL: the mockup's `--accent-2` (mascot feet dim tone) has
            // no dedicated `Palette` field; approximated as a dimmed `accent`.
            ArcadeMascotMark(accent: palette.accent, accentDim: palette.accent.opacity(0.7),
                              screen: palette.segmentBackground, bobbing: true)
                .frame(width: 48, height: 48)
            Text("KEEP\nTHE\nSTREAK")
                .typeToken(theme.typeScale.railQuote)
                .foregroundStyle(palette.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous)
                .fill(palette.fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: theme.metrics.borderWidth)
        )
        .shadow(color: hardShadowColor(palette), radius: 0, x: 2, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Keep the streak")
    }

    /// The cabinet surface's hard-shadow color (`--hard`), read off the palette's
    /// `.cabinet` surface rather than re-deriving it — Arcade always sets `.cabinet`.
    private func hardShadowColor(_ palette: Palette) -> Color {
        if case .cabinet(let cab) = palette.surface { return cab.hardShadow.color }
        return .clear
    }
}

// MARK: - Pixel-snapped height (rail label ghosting fix)
//
// See the doc comment on `ArcadeRailContent` above. Measures a group's natural
// height (same GeometryReader+PreferenceKey technique `SlidingSegment` already
// uses to measure segment frames), then locks it to that height rounded up to
// the next whole point, so it can never hand a fractional height down to its
// next sibling in the rail's outer `VStack`.

private struct RailHeightSnapKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PixelSnappedHeightModifier: ViewModifier {
    @State private var snapped: CGFloat?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: RailHeightSnapKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(RailHeightSnapKey.self) { snapped = $0.rounded(.up) }
            .frame(height: snapped)
    }
}

private extension View {
    func pixelSnappedHeight() -> some View {
        modifier(PixelSnappedHeightModifier())
    }
}

// MARK: - Theme conformance: structural capabilities + content builders

extension ArcadeTheme {
    public var showsDoneSection: Bool { false }
    public var showsTabCountBadge: Bool { false }
    public var usesCabinetRows: Bool { true }
    public var soundToggleLabel: String? { "SFX" }
    /// Phase 5 juice (score-pop, coin burst, confetti) is Arcade-only.
    public var providesCompletionFX: Bool { true }
    /// Parity fixes: rail sits right (task column left), footer segment is icon-only,
    /// icon buttons + composer/footer controls wear the cabinet chrome.
    public var railOnTrailing: Bool { true }
    public var showsAppearanceLabels: Bool { false }
    public var usesCabinetIconButtons: Bool { true }
    public var usesCabinetControls: Bool { true }
    /// Mockup `.victory { position:absolute; inset:0; }` fully occludes `.list` —
    /// the STAGE CLEAR panel covers the task rows rather than sitting above them.
    public var clearedStateCoversList: Bool { true }

    public func headerLeading(score: Int) -> AnyView? {
        AnyView(ArcadeHeaderLeading(theme: self, score: score))
    }

    public func statusRow(done: Int, total: Int, isToday: Bool) -> AnyView? {
        AnyView(ArcadeStatusRow(theme: self, done: done, total: total, isToday: isToday))
    }

    public func railContent(done: Int, total: Int, remaining: Int, score: Int, best: Int, streak: Int) -> AnyView? {
        AnyView(ArcadeRailContent(theme: self, done: done, total: total, remaining: remaining,
                                  score: score, best: best, streak: streak))
    }

    /// Verbatim from the mockup's composer placeholder (uppercase literal).
    public func composerPlaceholder(isToday: Bool) -> String? {
        isToday ? "ADD A TASK…" : "ADD A QUEST…"
    }
}
