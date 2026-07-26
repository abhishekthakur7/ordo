// OrdoUI — a single task row (mockup .task): the theme's checkbox + title + age
// marker, plus hover-revealed actions, the quiet triage affordance (§3.5), inline
// edit (§4.1), selection highlight, and full VoiceOver (§4.6). Every value is a token.

import SwiftUI
import OrdoCore
import OrdoThemes

struct TaskRowView: View {
    @Bindable var model: AppModel
    let task: OrdoTask
    let expanded: Bool
    /// 1-based position in the active tab's stored order. Only meaningful (and
    /// only ever non-nil) for cabinet rows (`theme.usesCabinetRows`), where it
    /// drives the pixel "01"/"02" trailing index badge; macOS rows always pass
    /// `nil` (the default) and ignore it entirely.
    var index: Int? = nil

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hover = false
    @State private var checkboxHover = false
    @FocusState private var editFocused: Bool
    /// Latches once the editor has actually GAINED focus, so a blur that fires before
    /// focus is ever established (the non-activating-panel race) can't insta-commit.
    @State private var editorHadFocus = false

    private var isSelected: Bool { model.selectedID == task.id }
    private var isEditing: Bool { model.editingTaskID == task.id }
    private var age: Int { model.age(of: task) }
    private var triage: Bool { model.isInTriage(task) }

    @ViewBuilder
    var body: some View {
        if theme.usesCabinetRows {
            cabinetBody
        } else {
            macOSBody
        }
    }

    /// UNCHANGED from pre-Phase-4: flat hover/press tint background (`rowBackground`),
    /// no shadow layer, no offset, no done-opacity dimming (macOS reflows done rows
    /// into their own section instead — see `TaskListView`).
    private var macOSBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            mainRow
            if triage && !isEditing {
                triageAffordance
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous))
        .onHover { hover = $0 }
        .onTapGesture { model.selectedID = task.id }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(task.done ? [.isSelected] : [])
        .accessibilityActions { accessibilityActions }
    }

    // MARK: Cabinet rows (Arcade) — 2px border "screen" card + hard offset shadow

    /// The cabinet card and its hard shadow are two SIBLINGS in a `ZStack`, not a
    /// single view with a CSS-style `box-shadow`: the shadow shape sits fixed at
    /// (2,2) and never moves, while only the front card (fill + border + content)
    /// translates by (-1,-1) on hover. That reproduces the mockup's
    /// `2px 2px 0 hard` → `3px 3px 0 hard` growth exactly (the absolute shadow
    /// position is unchanged; the card recedes from it), without needing to
    /// animate the shadow's own offset.
    private var cabinetBody: some View {
        ZStack(alignment: .topLeading) {
            cabinetHardShadowLayer
            cabinetCardContent
                .offset(x: hover ? -1 : 0, y: hover ? -1 : 0)
        }
        .animation(theme.motion.hoverFade.animation(reduceMotion: reduceMotion), value: hover)
        .onHover { hover = $0 }
        .onTapGesture { model.selectedID = task.id }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(task.done ? [.isSelected] : [])
        .accessibilityActions { accessibilityActions }
    }

    private var cabinetCardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            mainRow
            if triage && !isEditing {
                triageAffordance
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(cabinetCardBackground)
        .contentShape(RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous))
        // Arcade dims done rows IN PLACE (stored order, no reflow) — the title
        // strikethrough itself is drawn by `OrdoArcadeTaskTitle`.
        .opacity(task.done ? 0.62 : 1)
    }

    /// The "screen" card fill + border, replacing macOS's accentSoft-selection /
    /// rowHover flat tint entirely for cabinet rows.
    @ViewBuilder
    private var cabinetCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous)
        ZStack {
            shape.fill(palette.fieldBackground)
            shape.strokeBorder(cabinetBorderColor, lineWidth: theme.metrics.borderWidth)
        }
    }

    /// Rest: `palette.divider` (mockup `--line`). Hover: `palette.checkRing`, the
    /// same token the checkbox's own border uses — it resolves to the mockup's
    /// `--line-2`, the exact "lighter line" the spec calls for on row hover.
    /// Selected: `palette.accent`, a border tint standing in for macOS's
    /// accentSoft fill (the row already has its own screen-color fill).
    private var cabinetBorderColor: Color {
        if isSelected { return palette.accent }
        if hover { return palette.checkRing }
        return palette.divider
    }

    /// A crisp, zero-blur offset shadow: a second copy of the row's own shape,
    /// filled with the palette's hard-shadow color and held at a FIXED (2,2)
    /// offset (see `cabinetBody`'s doc comment for why it never itself moves).
    /// Falls back to a plain translucent black if the active palette somehow
    /// isn't a `.cabinet` surface (defensive only — `usesCabinetRows` themes
    /// always pair with a cabinet surface in practice).
    private var cabinetHardShadowLayer: some View {
        let color: Color = {
            if case .cabinet(let cab) = palette.surface { return cab.hardShadow.color }
            return .black.opacity(0.3)
        }()
        return RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous)
            .fill(color)
            .offset(x: 2, y: 2)
    }

    // MARK: Main row

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 11) {
            checkbox
            titleOrEditor
            trailing
        }
    }

    private var checkbox: some View {
        // Press state via ButtonStyle.isPressed; a simultaneous DragGesture would
        // swallow the Button's click on macOS.
        Button {
            model.toggle(task.id)
        } label: {
            EmptyView()
        }
        .buttonStyle(CheckboxButtonStyle(theme: theme, done: task.done, hover: checkboxHover))
        .onHover { checkboxHover = $0 }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var titleOrEditor: some View {
        if isEditing {
            TextField("", text: $model.editingText)
                .textFieldStyle(.plain)
                .typeToken(theme.typeScale.taskTitle)
                .foregroundStyle(palette.ink)
                .focused($editFocused)
                // Set focus AFTER the field is inserted (a synchronous set on a
                // non-activating panel loses the race and the field vanishes).
                .onAppear { editorHadFocus = false; DispatchQueue.main.async { editFocused = true } }
                .onSubmit { model.commitEditing() }
                .onExitCommand { model.cancelEditing() }
                .onChange(of: editFocused) { _, focused in
                    if focused {
                        editorHadFocus = true
                    } else if editorHadFocus && model.editingTaskID == task.id {
                        model.commitEditing() // blur commits, but only once focus was really gained
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            theme.taskTitle(task.title, done: task.done)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(task.title)
                .onTapGesture { handleTitleTap() }
        }
    }

    private var trailing: some View {
        HStack(spacing: 6) {
            if age >= 1 {
                theme.ageMarker(days: age, triage: triage)
            } else if theme.usesCabinetRows, let index {
                // The mockup's index slot ("01", "02", …) yields to the age
                // marker once a task is aged — this branch only ever shows one
                // or the other, matching `.idx-style` in the spec.
                indexBadge(index)
            }
            if hover && !isEditing {
                rowActions
                    .transition(.opacity)
            }
        }
        .animation(theme.motion.hoverFade.animation(reduceMotion: reduceMotion), value: hover)
    }

    /// Cabinet-only pixel index badge ("01", "02", …), zero-padded to 2 digits.
    /// `ArcadeTheme.indexType` is an Arcade-only type role (not part of the
    /// shared `TypeScale` schema) — read directly since this whole branch is
    /// already gated on `theme.usesCabinetRows`, mirroring how the signature
    /// views reach for `ArcadeTheme.victoryTitleType` etc.
    private func indexBadge(_ index: Int) -> some View {
        Text(String(format: "%02d", index))
            .typeToken(ArcadeTheme.indexType)
            .foregroundStyle(palette.ink3)
            .opacity(0.65)
    }

    private var rowActions: some View {
        HStack(spacing: 2) {
            IconButton(action: { model.tab == .today ? model.demote(task.id) : model.promote(task.id) },
                       size: 24, cornerRadius: 6,
                       accessibilityLabel: model.tab == .today ? UIStrings.actionMoveToLongterm : UIStrings.actionDoToday) {
                StrokeIcon(systemName: model.tab == .today ? "arrow.uturn.forward" : "arrow.uturn.backward", size: 13)
            }
            IconButton(action: { model.delete(task.id) },
                       size: 24, cornerRadius: 6,
                       accessibilityLabel: UIStrings.actionDelete) {
                StrokeIcon(systemName: "trash", size: 13)
            }
        }
    }

    // MARK: Triage affordance (§3.5) — quiet, non-modal

    private var triageAffordance: some View {
        HStack(spacing: 8) {
            Text(UIStrings.triagePrompt)
                .typeToken(theme.typeScale.emptyBody)
                .foregroundStyle(palette.ink3)
            Spacer(minLength: 0)
            triageButton(UIStrings.triageMoveToLongterm) { model.demote(task.id) }
            triageButton(UIStrings.triageKeep) { model.keepInTriage(task.id) }
            triageButton(UIStrings.triageDelete, destructive: true) { model.delete(task.id) }
        }
        .padding(.leading, theme.metrics.checkboxSize + 11)
        .padding(.trailing, 2)
    }

    private func triageButton(_ title: String, destructive: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .typeToken(theme.typeScale.ageMarker)
                .foregroundStyle(destructive ? palette.accent : palette.ink2)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(palette.inkFaint))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: Background + selection

    @ViewBuilder
    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: theme.metrics.rowCornerRadius, style: .continuous)
        ZStack {
            if isSelected {
                shape.fill(palette.accentSoft)
            } else if hover {
                shape.fill(palette.rowHover)
            }
        }
    }

    // MARK: Interaction

    private func handleTitleTap() {
        if isSelected {
            model.beginEditing(task.id)
        } else {
            model.selectedID = task.id
        }
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        var parts = [task.title]
        parts.append(task.done ? "done" : "not done")
        if age >= 1 { parts.append("carried over \(age) day\(age == 1 ? "" : "s")") }
        if triage { parts.append("needs triage") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var accessibilityActions: some View {
        Button(task.done ? UIStrings.actionReopen : UIStrings.actionComplete) { model.toggle(task.id) }
        Button(UIStrings.actionEdit) { model.beginEditing(task.id) }
        if model.tab == .today {
            Button(UIStrings.actionMoveToLongterm) { model.demote(task.id) }
        } else {
            Button(UIStrings.actionDoToday) { model.promote(task.id) }
        }
        Button(UIStrings.actionDelete) { model.delete(task.id) }
    }
}

/// Draws the theme checkbox, taking pressed state from `isPressed` — no DragGesture
/// to fight the Button for the click.
private struct CheckboxButtonStyle: ButtonStyle {
    let theme: any Theme
    let done: Bool
    let hover: Bool

    func makeBody(configuration: Configuration) -> some View {
        theme.checkbox(done: done, hover: hover, pressed: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
