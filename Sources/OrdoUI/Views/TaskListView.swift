import SwiftUI
import UniformTypeIdentifiers
import OrdoCore
import OrdoThemes

struct TaskListView: View {
    @Bindable var model: AppModel
    let expanded: Bool

    @Environment(\.ordoTheme) private var theme

    @State private var draggingID: UUID?

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                listContent
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)
            .scrollDisabled(hidesScrollableContent)
            .opacity(hidesScrollableContent ? 0 : 1)
            .allowsHitTesting(!hidesScrollableContent)
            .accessibilityHidden(hidesScrollableContent)

            if showsViewportFirstRunState {
                firstRunState
                    .padding(listInsets)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(theme.layout.stageInsets.edgeInsets)
        .padding(.top, theme.layout.stageTopSpacing)
        .animation(completedListAnimation, value: hidesScrollableContent)
    }

    @ViewBuilder
    private var listContent: some View {
        LazyVStack(alignment: .leading, spacing: listRowSpacing) {
            content
        }
        .padding(listInsets)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        if model.isFirstRunEmpty {
            if !showsViewportFirstRunState {
                theme.firstRunEmptyState()
                    .padding(stateInsets(theme.layout.emptyStateInsets))
                    .frame(maxWidth: .infinity)
            }
        } else {
            if model.isAllClearedToday && !theme.clearedStateCoversList {
                theme.allClearedState()
                    .padding(stateInsets(theme.layout.clearedStateInsets))
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            if theme.showsDoneSection {
                ForEach(model.openRows) { task in
                    row(task)
                        .modifier(ReorderModifier(
                            enabled: expanded,
                            task: task,
                            model: model,
                            draggingID: $draggingID
                        ))
                }

                if !model.doneRows.isEmpty {
                    theme.doneSectionHeader(count: model.doneRows.count)
                        .transition(.opacity)
                    ForEach(model.doneRows) { task in
                        row(task)
                    }
                }
            } else {
                ForEach(Array(model.allRows.enumerated()), id: \.element.id) { i, task in
                    row(task, index: i + 1)
                        .modifier(ReorderModifier(
                            enabled: expanded,
                            task: task,
                            model: model,
                            draggingID: $draggingID
                        ))
                }
            }
        }
    }

    /// Zen's absolute `.empty` state belongs to the finite stage viewport, not
    /// to a self-sizing scroll document. Legacy themes retain their historical
    /// in-list first-run treatment.
    private var showsViewportFirstRunState: Bool {
        model.isFirstRunEmpty && theme.layout.clearedStateFillsAvailableSpace
    }

    private var hidesScrollableContent: Bool {
        showsViewportFirstRunState
    }

    private var firstRunState: some View {
        theme.firstRunEmptyState()
            .padding(stateInsets(theme.layout.emptyStateInsets))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listInsets: EdgeInsets {
        // The legacy signature views already own their historic 12/4/8 wrapper.
        // Only new layouts consume their explicit list token here, avoiding a
        // second inset around macOS and Arcade states.
        if theme.layout == .legacy {
            return EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12)
        }
        return theme.layout.listInsets.edgeInsets
    }

    private var listRowSpacing: CGFloat {
        theme.layout == .legacy
            ? (theme.usesCabinetRows ? 6 : 0)
            : theme.layout.listRowSpacing
    }

    private func stateInsets(_ insets: ThemeInsets) -> EdgeInsets {
        // macOS and Arcade signature state views already include the legacy
        // state insets. Zen's state primitives intentionally do not.
        theme.layout == .legacy ? .init() : insets.edgeInsets
    }

    private var completedListAnimation: Animation? {
        model.reduceMotion ? nil : .easeOut(duration: 0.38)
    }

    private func row(_ task: OrdoTask, index: Int? = nil) -> some View {
        TaskRowView(model: model, task: task, expanded: expanded, index: index)
            .id(task.id)
            // Reduce Motion keeps list mutations in place; the full Zen entrance
            // otherwise consumes its authored translate/scale/blur transform.
            .transition(model.reduceMotion
                ? .opacity
                : .ordoRowEntrance(theme.motion.rowEntranceTransform))
    }
}

/// Attaches drag-to-reorder to open rows in the expanded view. FLIP motion comes
/// from `AppModel.move` → the single diff path.
private struct ReorderModifier: ViewModifier {
    let enabled: Bool
    let task: OrdoTask
    let model: AppModel
    @Binding var draggingID: UUID?

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    model.isDragging = true
                    draggingID = task.id
                    return NSItemProvider(object: task.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(
                    target: task, model: model, draggingID: $draggingID
                ))
        } else {
            content
        }
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let target: OrdoTask
    let model: AppModel
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingID,
              dragging != target.id,
              let draggingTask = model.store.task(id: dragging),
              canReorder(draggingTask) else { return }
        let ids = model.reorderableRows(for: draggingTask).map(\.id)
        guard let toIndex = AppModel.reorderIndex(orderedIDs: ids, dragging: dragging, target: target.id) else { return }
        model.move(dragging, toIndex: toIndex)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let dragging = draggingID,
              let draggingTask = model.store.task(id: dragging),
              canReorder(draggingTask) else {
            return DropProposal(operation: .forbidden)
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        model.isDragging = false
        return true
    }

    func dropExited(info: DropInfo) {
        // A drag released outside every drop target ends without a performDrop, which
        // would otherwise leave `isDragging` stuck true and wedge the defer system.
        // Clearing it here is safe: re-entering a row re-arms the drag via onDrag.
        model.isDragging = false
    }

    private func canReorder(_ dragging: OrdoTask) -> Bool {
        dragging.pinned == target.pinned && dragging.done == target.done
    }
}
