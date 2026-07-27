// OrdoUI — segmented tabs (mockup .tabs) with a sliding thumb (460ms drawer) and
// live remaining-count badges. Labels are theme voice (Today / Horizon).

import SwiftUI
import OrdoCore
import OrdoThemes

struct TabBarView: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    @ViewBuilder
    var body: some View {
        if let tabBarContent = theme.tabBarContent(
            tab: model.tab,
            remaining: remaining(for:),
            onSelect: { model.selectTab($0) }
        ) {
            tabBarContent
        } else {
            SlidingSegment(
                options: TaskList.allCases,
                selection: model.tab,
                motion: theme.motion.tabThumb,
                height: theme.layout.tabHeight,
                cornerRadius: theme.layout.tabCornerRadius,
                thumbInset: theme.layout.tabThumbInset,
                trackCornerRadius: theme.layout.tabTrackCornerRadius,
                onSelect: { model.selectTab($0) }
            ) { tab, isActive in
                HStack(spacing: theme.layout.tabLabelSpacing) {
                    if !theme.showsTabCountBadge {
                        TabDot(color: labelColor(isActive: isActive), visible: !isActive)
                    }
                    theme.typeScale.tab.styled(label(for: tab))
                        .foregroundStyle(labelColor(isActive: isActive))
                    if theme.showsTabCountBadge {
                        CountBadge(count: remaining(for: tab), active: isActive)
                    }
                }
            }
            .padding(tabInsets)
        }
    }

    private func label(for tab: TaskList) -> String {
        tab == .today ? theme.todayTabLabel : theme.longtermTabLabel
    }

    private func remaining(for tab: TaskList) -> Int {
        tab == .today ? model.todayRemaining : model.longtermRemaining
    }

    private var tabInsets: EdgeInsets {
        let insets = theme.layout.tabInsets
        return EdgeInsets(top: insets.top, leading: insets.leading,
                          bottom: insets.bottom, trailing: insets.trailing)
    }

    /// The tab label's foreground. Themes without a count badge (Arcade) sit
    /// their active tab on an accent-filled thumb, needing accent-contrast ink.
    private func labelColor(isActive: Bool) -> Color {
        guard !theme.showsTabCountBadge else {
            return isActive ? palette.ink : palette.ink2
        }
        return isActive ? palette.accentInk : palette.ink3
    }
}

/// Arcade's tab dot: a 5×5 square before the label, dimmed normally, hidden
/// on the active tab — takes the count badge's place.
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
