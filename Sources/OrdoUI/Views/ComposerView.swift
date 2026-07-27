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
        VStack(spacing: theme.layout.composerStackSpacing) {
            if let pending = model.pendingPaste {
                pasteConfirm(pending)
                    .transition(.opacity)
            }
            field
        }
        .padding(theme.layout.composerInsets.edgeInsets)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: palette.hairlineWidth)
        }
    }

    // MARK: Field

    @ViewBuilder
    private var field: some View {
        switch theme.composerStyle {
        case .ink:
            inkField
        case .card, .cabinet:
            cardField
        }
    }

    /// The existing macOS card and Arcade cabinet field share their original
    /// composition; the values now come from `ThemeLayout` so legacy remains
    /// pixel-identical while new themes can opt into a different wrapper.
    private var cardField: some View {
        HStack(spacing: theme.layout.composerFieldSpacing) {
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
        .padding(theme.layout.composerFieldInsets.edgeInsets)
        .frame(minHeight: CGFloat(theme.layout.composerFieldMinimumHeight))
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
        .shadow(color: focusedField ? palette.glow : .clear, radius: 6)
        .animation(theme.motion.titleColorFade.animation(reduceMotion: reduceMotion), value: focusedField)
        .animation(theme.motion.counterFade.animation(reduceMotion: reduceMotion), value: model.showCharacterCounter)
    }

    /// Zen Ink's deliberately unboxed composer: the plus remains a keyboard-
    /// equivalent submit target, but has no filled button chrome.
    private var inkField: some View {
        HStack(alignment: .bottom, spacing: theme.layout.composerFieldSpacing) {
            Button(action: submit) {
                SumiPlusShape()
                    .stroke(palette.inkFaint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 19, height: 19)
                    .frame(width: 22, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!model.canAdd)
            .accessibilityLabel("Add task")
            .accessibilityValue(model.canAdd ? "ready" : "empty")

            ZStack(alignment: .leading) {
                if model.composerText.isEmpty {
                    theme.typeScale.field.styled(theme.composerPlaceholder(isToday: model.tab == .today) ?? UIStrings.composerPlaceholder)
                        .italic()
                        .foregroundStyle(palette.inkFaint)
                }
                TextField("", text: $model.composerText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .typeToken(theme.typeScale.field)
                    .foregroundStyle(palette.ink)
                    .focused(focus, equals: .composer)
                    .onSubmit { submit() }
                    .accessibilityLabel("New task")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(focusedField ? palette.accent : palette.fieldLine)
                .frame(width: focusedField ? 42 : 30, height: palette.hairlineWidth)
                .padding(.bottom, 8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: focusedField)
        }
        .padding(theme.layout.composerFieldInsets.edgeInsets)
        .frame(minHeight: CGFloat(theme.layout.composerFieldMinimumHeight))
    }

    @ViewBuilder
    private var addButton: some View {
        if theme.composerStyle == .cabinet {
            arcadeAddButton
        } else {
            macOSAddButton
        }
    }

    /// 30×30/r9, dims to 35% opacity whenever the field is empty.
    private var macOSAddButton: some View {
        Button(action: submit) {
            StrokeIcon(systemName: "plus", size: 16, weight: .bold)
                .foregroundStyle(palette.accentInk)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.accent))
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.88))
        .shadow(color: palette.glow, radius: 6)
        .opacity(model.canAdd ? 1 : 0.35)
        .disabled(!model.canAdd)
        .animation(theme.motion.rowEntrance.animation(reduceMotion: reduceMotion), value: model.canAdd)
        .accessibilityLabel("Add task")
    }

    /// The Arcade add button: 40×40/r8, full-opacity accent that never dims for
    /// an empty field, with a hard offset shadow plus the dark-only glow.
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
        .shadow(color: palette.glow, radius: 6)
        .disabled(!model.canAdd)
        .accessibilityLabel("Add task")
    }

    /// The cabinet surface's hard-shadow color, read off the palette.
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

/// Keep the design-system layout token platform-neutral while allowing shared
/// SwiftUI views to consume it directly.
extension ThemeInsets {
    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}
