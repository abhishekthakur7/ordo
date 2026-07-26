// OrdoUI — segmented tabs (mockup .tabs) with a sliding thumb (460ms drawer) and
// live remaining-count badges. Labels are theme voice (Today / Horizon).

import SwiftUI
import OrdoCore
import OrdoThemes

struct TabBarView: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    var body: some View {
        SlidingSegment(
            options: TaskList.allCases,
            selection: model.tab,
            motion: theme.motion.tabThumb,
            height: 28,
            cornerRadius: 7,
            thumbInset: 3,
            trackCornerRadius: 9, // mockup .tabs border-radius
            onSelect: { model.selectTab($0) }
        ) { tab, isActive in
            HStack(spacing: 6) {
                if !theme.showsTabCountBadge {
                    // Arcade: a 5px dot takes the count badge's place, hidden
                    // when the tab is active (mockup `.tab .dot`, opacity .55 /
                    // 0 on the active tab) instead of a live open-count number.
                    TabDot(color: labelColor(isActive: isActive), visible: !isActive)
                }
                theme.typeScale.tab.styled(label(for: tab))
                    .foregroundStyle(labelColor(isActive: isActive))
                if theme.showsTabCountBadge {
                    CountBadge(count: remaining(for: tab), active: isActive)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private func label(for tab: TaskList) -> String {
        tab == .today ? theme.todayTabLabel : theme.longtermTabLabel
    }

    private func remaining(for tab: TaskList) -> Int {
        tab == .today ? model.todayRemaining : model.longtermRemaining
    }

    /// The tab label's foreground. `showsTabCountBadge == false` is the arcade
    /// signal: its active tab sits on an accent-filled sliding thumb (not a
    /// neutral one), so the active label needs accent-contrast ink instead of
    /// the regular `ink`; the inactive label uses the dimmer `ink3` (mockup
    /// `.tab` pixel 8px `--ink-3` / on `--accent-ink`). Every count-badge theme
    /// (macOS included) keeps the original `ink`/`ink2` pair unchanged.
    private func labelColor(isActive: Bool) -> Color {
        guard !theme.showsTabCountBadge else {
            return isActive ? palette.ink : palette.ink2
        }
        return isActive ? palette.accentInk : palette.ink3
    }
}

/// Arcade's tab dot (mockup `.tab .dot`): a 5×5 currentColor-equivalent square
/// before the label, opacity .55 normally, hidden (opacity 0) on the active
/// tab — takes the live count badge's place when `showsTabCountBadge == false`.
/// "currentColor" is approximated as the label's own foreground color so the
/// dot and label always agree.
private struct TabDot: View {
    let color: Color
    let visible: Bool

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 5, height: 5)
            .opacity(visible ? 0.55 : 0)
            .accessibilityHidden(true)
    }
}

private struct CountBadge: View {
    let count: Int
    let active: Bool

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    var body: some View {
        Text("\(count)")
            .typeToken(theme.typeScale.tabCount)
            .monospacedDigit()
            .foregroundStyle(active ? palette.accent : palette.ink3)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(active ? palette.accentSoft : palette.inkFaint)
            )
            .contentTransition(.numericText())
    }
}
