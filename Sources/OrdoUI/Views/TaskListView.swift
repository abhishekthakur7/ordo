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
    // Measured viewport height (mockup `.viewport{ position:relative }`, the
    // container `.victory{ position:absolute; inset:0 }` covers) — a plain
    // `.frame(maxHeight: .infinity)` on a `ScrollView`'s content is a no-op when
    // that content is shorter than the visible area (the scroll axis is proposed
    // an unbounded/ideal height, not the viewport's bound), so covering the list
    // needs this container's own measured height fed back in as a `minHeight`.
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            // Cabinet rows (Arcade) cast a hard offset shadow that bleeds 2–3pt
            // past their own frame (mockup `.list{ gap:6px }`), so they need a
            // real gap to avoid the next row's opaque card painting over the
            // shadow bleed. macOS rows have no shadow bleed and keep spacing 0.
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
            // Arcade: the victory panel COVERS the entire list viewport (mockup
            // `.victory{ position:absolute; inset:0; }` occludes `.list`) — the
            // done rows are hidden behind it, not merely dimmed beneath it, so the
            // task-row ForEach(s) are skipped entirely while cleared.
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
                // Arcade (and any future `showsDoneSection == false` theme): every
                // active-tab task in ONE flat ForEach, stored order, no "Completed"
                // header and no separate done section — done rows dim in place
                // (TaskRowView handles the opacity + strikethrough), and there is
                // no reflow to choreograph (`AppModel.toggle` already skips it).
                // The 1-based position is threaded through as `index` so the
                // cabinet row can show a pixel "01"/"02" trailing badge.
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
