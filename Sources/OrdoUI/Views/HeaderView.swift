// OrdoUI — panel header (mockup .head): theme greeting by hour, long date line,
// gear (settings) + expand/collapse icon buttons. The expand glyph rotates 180°
// with the drawer curve when expanded (mockup .expand-glyph).

import SwiftUI
import OrdoThemes

struct HeaderView: View {
    @Bindable var model: AppModel
    let chrome: PanelChrome

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: theme.layout.headerContentSpacing) {
            leadingContent
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: theme.layout.headerTrailingAccessorySpacing) {
                if let accessory = theme.headerTrailingAccessory(
                    done: model.doneRows.count,
                    total: model.openRows.count + model.doneRows.count,
                    expanded: model.settings.panelExpanded
                ) {
                    accessory
                }

                HStack(spacing: theme.layout.headerControlsSpacing) {
                    IconButton(action: toggleSettings, accessibilityLabel: UIStrings.settingsTitle) {
                        StrokeIcon(systemName: "gearshape")
                    }

                    IconButton(action: toggleExpand,
                               accessibilityLabel: model.settings.panelExpanded
                                ? "Collapse planning view" : "Expand planning view") {
                        ExpandGlyphIcon()
                            .rotationEffect(.degrees(180 * model.panelExpansionProgress))
                    }
                }
            }
        }
        .padding(headerInsets)
    }

    /// The header's leading cluster. When the theme supplies `headerLeading`
    /// (Arcade's brand mark + wordmark + score), it replaces the greeting/date
    /// stack entirely; `nil` keeps the default greeting/date `VStack`.
    @ViewBuilder
    private var leadingContent: some View {
        if let leading = theme.headerLeading(score: model.arcadeScore) {
            leading
        } else {
            VStack(alignment: .leading, spacing: theme.layout.headerTextSpacing) {
                theme.typeScale.greeting.styled(model.greeting)
                    .foregroundStyle(palette.ink)
                theme.typeScale.date.styled(model.dateLine)
                    .foregroundStyle(palette.ink2)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var headerInsets: EdgeInsets {
        let insets = theme.layout.headerInsets
        return EdgeInsets(top: insets.top, leading: insets.leading,
                          bottom: insets.bottom, trailing: insets.trailing)
    }

    private func toggleSettings() {
        withAnimation(theme.motion.panelEnter.animation(reduceMotion: reduceMotion)) {
            model.settingsOpen.toggle()
        }
    }

    private func toggleExpand() {
        let next = !model.settings.panelExpanded
        model.settings.panelExpanded = next
        // The chrome bridge schedules one coalesced post-layout frame morph, so
        // this button and ⌘E cannot start competing AppKit transitions.
        chrome.setExpanded(next)
    }
}
