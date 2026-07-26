// OrdoUI — the add-task composer (mockup .composer / .field): plus glyph,
// placeholder, filled-state accent add button, add on Return, a soft character
// counter past 400/500, and the quiet inline confirm for a >20-line paste (§4.1).

import SwiftUI
import OrdoThemes

struct ComposerView: View {
    @Bindable var model: AppModel
    var focus: FocusState<PanelFocus?>.Binding

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if let pending = model.pendingPaste {
                pasteConfirm(pending)
                    .transition(.opacity)
            }
            field
        }
        .padding(EdgeInsets(top: 8, leading: 14, bottom: 10, trailing: 14))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: palette.hairlineWidth)
        }
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: 9) {
            // Arcade's inline "+" is accent-green (never the dim `ink3` macOS uses),
            // gated on the cabinet-controls capability so macOS is untouched.
            StrokeIcon(systemName: "plus", size: 16, weight: .medium)
                .foregroundStyle(theme.usesCabinetControls ? palette.accent : palette.ink3)

            ZStack(alignment: .leading) {
                if model.composerText.isEmpty {
                    theme.typeScale.field.styled(theme.composerPlaceholder(isToday: model.tab == .today) ?? UIStrings.composerPlaceholder)
                        .foregroundStyle(palette.ink3)
                }
                TextField("", text: $model.composerText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .typeToken(theme.typeScale.field)
                    .foregroundStyle(palette.ink)
                    .focused(focus, equals: .composer)
                    .onSubmit { submit() }
            }

            if model.showCharacterCounter {
                Text("\(model.charactersRemaining)")
                    .typeToken(theme.typeScale.ageMarker)
                    .monospacedDigit()
                    .foregroundStyle(model.charactersRemaining < 0 ? palette.accent : palette.ink3)
                    .transition(.opacity)
            }

            addButton
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(minHeight: 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(focusedField ? palette.accent : palette.fieldLine,
                                      lineWidth: focusedField ? 1.5 : 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.accentSoft, lineWidth: focusedField ? 3 : 0)
                        .padding(-1.5)
                )
        )
        // Focused-field glow: `palette.glow` is non-clear only in arcade dark
        // (arcade light and macOS both set it to `.clear`), so this is a no-op
        // everywhere else — no branch on `theme.id` needed.
        .shadow(color: focusedField ? palette.glow : .clear, radius: 6)
        .animation(theme.motion.titleColorFade.animation(reduceMotion: reduceMotion), value: focusedField)
        .animation(theme.motion.counterFade.animation(reduceMotion: reduceMotion), value: model.showCharacterCounter)
    }

    @ViewBuilder
    private var addButton: some View {
        if theme.usesCabinetControls {
            arcadeAddButton
        } else {
            macOSAddButton
        }
    }

    /// UNCHANGED: 30×30/r9, dims to 35% opacity whenever the field is empty.
    private var macOSAddButton: some View {
        Button(action: submit) {
            StrokeIcon(systemName: "plus", size: 16, weight: .bold)
                .foregroundStyle(palette.accentInk)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.accent))
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.88))
        // `palette.glow` is `.clear` for macOS, so this glow is a no-op here.
        .shadow(color: palette.glow, radius: 6)
        .opacity(model.canAdd ? 1 : 0.35)
        .disabled(!model.canAdd)
        .animation(theme.motion.rowEntrance.animation(reduceMotion: reduceMotion), value: model.canAdd)
        .accessibilityLabel("Add task")
    }

    /// Arcade `.add-btn`: 40×40/r8, full-opacity accent that never dims for an
    /// empty field (only `.disabled` gates the actual interaction), a crisp hard
    /// `2px 2px 0` offset shadow (visible in both appearances, mirroring
    /// `TaskRowView`'s cabinet-shadow technique) plus the existing dark-only glow.
    private var arcadeAddButton: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(arcadeAddButtonHardShadowColor)
                .frame(width: 40, height: 40)
                .offset(x: 2, y: 2)

            Button(action: submit) {
                StrokeIcon(systemName: "plus", size: 16, weight: .bold)
                    .foregroundStyle(palette.accentInk)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.accent))
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.88))
        }
        // `palette.glow` is `.clear` for arcade-light, so this is dark-only —
        // additive to the hard shadow above, never a replacement for it.
        .shadow(color: palette.glow, radius: 6)
        .disabled(!model.canAdd)
        .accessibilityLabel("Add task")
    }

    /// The cabinet surface's hard-shadow color (`--hard`), read off the palette's
    /// `.cabinet` surface — mirrors `TaskRowView.cabinetHardShadowLayer`.
    private var arcadeAddButtonHardShadowColor: Color {
        if case .cabinet(let cab) = palette.surface { return cab.hardShadow.color }
        return .clear
    }

    // MARK: Paste confirm (§4.1)

    private func pasteConfirm(_ pending: PendingPaste) -> some View {
        HStack(spacing: 8) {
            theme.typeScale.field.styled(UIStrings.confirmPaste(pending.count))
                .foregroundStyle(palette.ink)
            Spacer(minLength: 0)
            Button(UIStrings.confirmCancel) { withAnimation { model.cancelPendingPaste() } }
                .buttonStyle(PressScaleButtonStyle())
                .foregroundStyle(palette.ink2)
            Button(UIStrings.confirmAdd) {
                withAnimation(theme.motion.rowEntrance.animation(reduceMotion: reduceMotion)) {
                    model.confirmPendingPaste()
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            .foregroundStyle(palette.accent)
        }
        .typeToken(theme.typeScale.segmentButton)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.accentSoft))
    }

    private var focusedField: Bool { focus.wrappedValue == .composer }

    private func submit() {
        withAnimation(theme.motion.rowEntrance.animation(reduceMotion: reduceMotion)) {
            model.submitComposer()
        }
    }
}
