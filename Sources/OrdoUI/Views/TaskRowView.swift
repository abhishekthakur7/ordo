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

    var body: some View {
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
            }
            if hover && !isEditing {
                rowActions
                    .transition(.opacity)
            }
        }
        .animation(theme.motion.hoverFade.animation(reduceMotion: reduceMotion), value: hover)
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
