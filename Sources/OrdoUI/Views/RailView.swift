// OrdoUI — the expanded planning rail (mockup .rail): Overview kicker, the theme's
// progress ring (percent + done today), Completed/Remaining/Total stat lines on
// hairline rules, and the quote. Content fades/slides in with the drawer motion.

import SwiftUI
import OrdoThemes

struct RailView: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    var body: some View {
        if let railContent = theme.railContent(done: model.railDone, total: model.railTotal,
                                                 remaining: model.railRemaining, score: model.arcadeScore,
                                                 best: model.arcadeBest, streak: model.arcadeStreak) {
            railContent
        } else {
            VStack(alignment: .leading, spacing: 0) {
                theme.typeScale.railKicker.styled(UIStrings.railKicker)
                    .foregroundStyle(palette.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                theme.progressRing(done: model.railDone, total: model.railTotal)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    statLine(UIStrings.railCompleted, model.railDone)
                    railDivider
                    statLine(UIStrings.railRemaining, model.railRemaining)
                    railDivider
                    statLine(UIStrings.railTotal, model.railTotal)
                }
                .padding(.top, 22)

                Spacer(minLength: 12)

                Text(UIStrings.railQuote)
                    .typeToken(theme.typeScale.railQuote)
                    .foregroundStyle(palette.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(railInsets)
            .frame(width: theme.metrics.railWidth, alignment: .leading)
        }
    }

    private var railInsets: EdgeInsets {
        // `ThemeLayout.legacy.railInsets` is deliberately zero, while the
        // existing shared rail has its own 26/22/26 content inset. Retain that
        // compatibility geometry for the two shipped themes; non-legacy shared
        // rails consume their explicit layout token. Full rail replacements do
        // not enter this branch, so a Zen rail is never double-padded.
        let insets = theme.layout == .legacy
            ? ThemeInsets(top: 26, leading: 22, bottom: 26, trailing: 22)
            : theme.layout.railInsets
        return EdgeInsets(top: insets.top, leading: insets.leading,
                          bottom: insets.bottom, trailing: insets.trailing)
    }

    /// A 0.5px stat-row hairline (mockup .rail-line border-bottom), thickening under
    /// Increase Contrast via `hairlineWidth`.
    private var railDivider: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: palette.hairlineWidth)
    }

    private func statLine(_ label: String, _ value: Int) -> some View {
        HStack {
            theme.typeScale.railLine.styled(label)
                .foregroundStyle(palette.ink2)
            Spacer()
            Text("\(value)")
                .typeToken(theme.typeScale.railLineValue)
                .monospacedDigit()
                .foregroundStyle(palette.ink)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 9)
    }
}
