// OrdoUI — the soft-delete undo toast (§2.2, §4.1): a theme-tokened banner with an
// Undo action, shown for ~10s (clock-driven expiry in AppModel). No dialogs.

import SwiftUI
import OrdoThemes

struct UndoToastView: View {
    @Bindable var model: AppModel
    let toast: UndoToast

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            theme.typeScale.field.styled(UIStrings.deletedToast(toast.title))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(UIStrings.undo) { model.undoDelete() }
                .buttonStyle(PressScaleButtonStyle())
                .typeToken(theme.typeScale.segmentButton)
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.material.usesFallback ? palette.material.fallbackOpaque : palette.segmentThumb)
                .ordoShadows(palette.panelShadow)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.divider, lineWidth: palette.hairlineWidth)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}
