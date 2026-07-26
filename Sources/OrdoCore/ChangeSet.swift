// OrdoCore — the diffable change set (ARCHITECTURE §6.3, PLAN.md contract C3).
// One shape returned by every mutation; OrdoUI animates insertions/removals/
// moves/updates from it through a single path.

import Foundation

/// Ids of tasks affected by a mutation, grouped by the kind of animation the UI
/// should apply. All four groups are stable-ordered and free of duplicates.
public struct ChangeSet: Equatable, Sendable {
    /// Tasks that appeared (added, promoted-in, undo-restored, reload-added).
    public var inserted: [UUID]
    /// Tasks that disappeared (soft-deleted, archived at rollover, reload-removed).
    public var removed: [UUID]
    /// Tasks whose position within a list changed (reorder).
    public var moved: [UUID]
    /// Tasks whose content changed in place (edit, toggle, promote/demote,
    /// triage-keep, age tick).
    public var updated: [UUID]

    public init(inserted: [UUID] = [], removed: [UUID] = [],
                moved: [UUID] = [], updated: [UUID] = []) {
        self.inserted = inserted
        self.removed = removed
        self.moved = moved
        self.updated = updated
    }

    /// An empty change set (a no-op mutation returns this).
    public static let empty = ChangeSet()

    /// True when no task was affected.
    public var isEmpty: Bool {
        inserted.isEmpty && removed.isEmpty && moved.isEmpty && updated.isEmpty
    }

    /// Merges two change sets, preserving order and de-duplicating within each
    /// group. Used when several mutations are coalesced (e.g. a multi-day catchUp
    /// or an external reload that both adds and removes).
    public func combined(with other: ChangeSet) -> ChangeSet {
        ChangeSet(
            inserted: ChangeSet.union(inserted, other.inserted),
            removed: ChangeSet.union(removed, other.removed),
            moved: ChangeSet.union(moved, other.moved),
            updated: ChangeSet.union(updated, other.updated))
    }

    private static func union(_ a: [UUID], _ b: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var out: [UUID] = []
        for id in a + b where seen.insert(id).inserted { out.append(id) }
        return out
    }
}
