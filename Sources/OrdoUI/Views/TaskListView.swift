// OrdoUI — the scrolling list (mockup .list-scroll / .list): a LazyVStack of open
// rows, the themed done-section header, done rows, and the theme's empty / all-
// cleared states. Drag-to-reorder is enabled only in the expanded view (§4.1).

import SwiftUI
import UniformTypeIdentifiers
import OrdoCore
import OrdoThemes

struct TaskListView: View {
    @Bindable var model: AppModel
    let expanded: Bool

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    @State private var draggingID: UUID?
    /// Measured viewport height, fed back as a `minHeight` so the all-cleared
    /// state can cover the list even when its own content is shorter.
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.usesCabinetRows ? 6 : 0) {
                content
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ListViewportHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ListViewportHeightKey.self) { viewportHeight = $0 }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
    }

    @ViewBuilder
    private var content: some View {
        if model.isFirstRunEmpty {
            theme.firstRunEmptyState()
                .frame(maxWidth: .infinity)
        } else if model.isAllClearedToday && theme.clearedStateCoversList {
            theme.allClearedState()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: viewportHeight)
                .transition(.opacity)
        } else {
            if model.isAllClearedToday {
                theme.allClearedState()
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

    private func row(_ task: OrdoTask, index: Int? = nil) -> some View {
        TaskRowView(model: model, task: task, expanded: expanded, index: index)
            .id(task.id)
            .transition(.ordoRowEntrance(theme.motion.rowEntranceTransform))
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
        guard let dragging = draggingID, dragging != target.id else { return }
        let ids = model.store.tasks(in: model.tab).map(\.id)
        guard let toIndex = AppModel.reorderIndex(orderedIDs: ids, dragging: dragging, target: target.id) else { return }
        model.move(dragging, toIndex: toIndex)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
}

/// The `ScrollView`'s own (viewport) height, measured via a background
/// `GeometryReader` — see the doc comment on `TaskListView.viewportHeight`.
private struct ListViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
