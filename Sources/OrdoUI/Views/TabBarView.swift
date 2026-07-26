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
                theme.typeScale.tab.styled(label(for: tab))
                    .foregroundStyle(isActive ? palette.ink : palette.ink2)
                CountBadge(count: remaining(for: tab), active: isActive)
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
