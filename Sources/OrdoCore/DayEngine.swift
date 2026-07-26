// OrdoCore — the Day Engine (ARCHITECTURE §3). Decides rollover: an incomplete
// Today task stays and ages, done tasks archive. A pure value (no I/O) —
// `computeCatchUp` returns an outcome that `TaskStore` applies.

import Foundation

/// The result of a rollover pass. `nil` is never returned from here — a no-op is
/// signalled by `computeCatchUp` returning `nil` directly.
public struct RolloverOutcome: Equatable, Sendable {
    /// Live tasks after archiving + tombstone purge (the new `state.tasks`).
    public let remainingTasks: [OrdoTask]
    /// Tasks moved to history, each under its true completion day.
    public let archived: [ArchivedTask]
    /// One summary per elapsed day that had ≥1 Today task (no empty-day noise).
    public let summaries: [DaySummary]
    /// The advanced `lastProcessedDay` (== today).
    public let newLastProcessedDay: DayKey
    /// Ids of soft-delete tombstones whose undo window had expired and were purged.
    public let purgedTombstoneIds: [UUID]
    /// UI-facing diff: removed = archived; updated = still-open Today tasks whose
    /// displayed age ticked up.
    public let changeSet: ChangeSet
}

/// Computes logical-day identity and performs rollover. Stateless apart from the
/// day-start offset, which is passed in from `StoreState`.
public struct DayEngine {
    /// Seconds after midnight that a logical day begins (ARCHITECTURE §3.1).
    /// Default 0 = midnight; e.g. 10_800 = 03:00 night-owl semantics.
    public var dayStartOffset: Int

    public init(dayStartOffset: Int = 0) {
        self.dayStartOffset = dayStartOffset
    }

    /// THE ONLY place an instant becomes a logical day (ARCHITECTURE §3.1):
    /// local calendar date of `instant − dayStartOffset`, in `timeZone`.
    /// DST-safe because it reads calendar-date components, not 24h arithmetic.
    public func dayKey(for instant: Date, timeZone: TimeZone) -> DayKey {
        let shifted = instant.addingTimeInterval(-Double(dayStartOffset))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return DayKey(from: shifted, calendar: cal)
    }

    /// The rollover algorithm (ARCHITECTURE §3.2). Returns `nil` for a no-op
    /// (`today <= lastProcessedDay` — the monotonic guard against clock/timezone
    /// going backwards). Idempotent: a second call with the same clock is `nil`.
    public func computeCatchUp(state: StoreState,
                               now: Date,
                               timeZone: TimeZone,
                               undoWindow: TimeInterval) -> RolloverOutcome? {
        let today = dayKey(for: now, timeZone: timeZone)
        guard today > state.lastProcessedDay else { return nil }

        // Step 3 (hoisted): purge soft-delete tombstones past their undo window.
        var purgedIds: [UUID] = []
        let afterPurge = state.tasks.filter { t in
            if let deletedAt = t.deletedAt, now.timeIntervalSince(deletedAt) >= undoWindow {
                purgedIds.append(t.id)
                return false
            }
            return true
        }

        // Step 1: archive done, non-deleted tasks completed before today, each
        // recorded under its TRUE completion day (not the processing day).
        var archived: [ArchivedTask] = []
        var remaining: [OrdoTask] = []
        for t in afterPurge {
            if t.done, t.deletedAt == nil, let completedAt = t.completedAt {
                let completionDay = dayKey(for: completedAt, timeZone: timeZone)
                if completionDay < today {
                    archived.append(ArchivedTask(task: t, archivedDay: completionDay))
                    continue
                }
            }
            remaining.append(t)
        }

        // Step 2: one DaySummary per elapsed day in [lastProcessedDay, today−1],
        // computed from the original task set, skipping days with no Today tasks.
        var summaries: [DaySummary] = []
        var day = state.lastProcessedDay
        while day < today {
            if let s = summary(for: day, allTasks: state.tasks, timeZone: timeZone) {
                summaries.append(s)
            }
            day = day.adding(1)
        }

        let changeSet = ChangeSet(
            removed: archived.map { $0.task.id },
            updated: remaining
                .filter { $0.list == .today && $0.deletedAt == nil }
                .map { $0.id })

        return RolloverOutcome(
            remainingTasks: remaining,
            archived: archived,
            summaries: summaries,
            newLastProcessedDay: today,
            purgedTombstoneIds: purgedIds,
            changeSet: changeSet)
    }

    /// Builds the summary for one elapsed day, or nil if no Today task existed
    /// that day. A task counts as "existed on X" when `addedToTodayOn <= X`.
    private func summary(for X: DayKey, allTasks: [OrdoTask], timeZone: TimeZone) -> DaySummary? {
        var completed = 0
        var stillOpen = 0
        for t in allTasks {
            guard t.deletedAt == nil, let added = t.addedToTodayOn, added <= X else { continue }
            if t.done, let completedAt = t.completedAt {
                let cd = dayKey(for: completedAt, timeZone: timeZone)
                if cd == X { completed += 1 }
                else if cd > X { stillOpen += 1 }
                // cd < X: completed on an earlier day → not attributable to X.
            } else {
                stillOpen += 1
            }
        }
        guard completed + stillOpen > 0 else { return nil }
        return DaySummary(day: X,
                          completed: completed,
                          stillOpen: stillOpen,
                          fullyCleared: completed > 0 && stillOpen == 0)
    }
}
