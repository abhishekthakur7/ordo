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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                theme.typeScale.greeting.styled(model.greeting)
                    .foregroundStyle(palette.ink)
                theme.typeScale.date.styled(model.dateLine)
                    .foregroundStyle(palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            HStack(spacing: 6) {
                IconButton(action: toggleSettings, accessibilityLabel: UIStrings.settingsTitle) {
                    StrokeIcon(systemName: "gearshape")
                }

                IconButton(action: toggleExpand,
                           accessibilityLabel: model.settings.panelExpanded
                            ? "Collapse planning view" : "Expand planning view") {
                    ExpandGlyphIcon()
                        .rotationEffect(.degrees(model.settings.panelExpanded ? 180 : 0))
                        .animation(theme.motion.expandMorph.animation(reduceMotion: reduceMotion),
                                   value: model.settings.panelExpanded)
                }
            }
        }
        .padding(EdgeInsets(top: 15, leading: 18, bottom: 10, trailing: 12))
    }

    private func toggleSettings() {
        withAnimation(theme.motion.panelEnter.animation(reduceMotion: reduceMotion)) {
            model.settingsOpen.toggle()
        }
    }

    private func toggleExpand() {
        let next = !model.settings.panelExpanded
        model.settings.panelExpanded = next
        chrome.setExpanded(next)
    }
}
