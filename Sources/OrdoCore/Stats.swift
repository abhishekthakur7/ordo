// OrdoCore — derived stats & streaks (ARCHITECTURE §7). Computed from history +
// the live store, cached in memory, NEVER persisted as truth (so a manual data
// edit can't desync a streak).

import Foundation

/// A snapshot of derived stats. Cheap value type; recomputed on demand.
public struct Stats: Equatable, Sendable {
    /// Consecutive cleared days ending yesterday-or-today; zero-task days neutral.
    public let currentStreak: Int
    /// Live Today tasks still open.
    public let todayOpen: Int
    /// Live Today tasks completed (not yet archived).
    public let todayDone: Int
    /// True iff ≥1 Today task exists and all are done right now.
    public let todayCleared: Bool
    /// All-time count of archived (completed & rolled-over) tasks in history.
    public let lifetimeCompleted: Int
    /// Number of cleared days recorded in history.
    public let clearedDays: Int

    /// Live Today tasks in total (open + done).
    public var todayTotal: Int { todayOpen + todayDone }
}

/// Pure stats computation. Kept separate from `TaskStore` so it is unit-testable
/// with hand-built summaries.
public enum StatsEngine {
    /// Computes stats from live Today tasks and historical day summaries. Summaries
    /// may arrive in any order with rare crash-retry duplicate days (last wins);
    /// `archivedCount` is deduped upstream.
    public static func compute(liveTodayTasks: [OrdoTask],
                               today: DayKey,
                               summaries: [DaySummary],
                               archivedCount: Int) -> Stats {
        let todayDone = liveTodayTasks.filter { $0.done }.count
        let todayOpen = liveTodayTasks.count - todayDone
        let todayHasTasks = !liveTodayTasks.isEmpty
        let todayCleared = todayHasTasks && todayOpen == 0

        // De-dupe summaries by day (guards against crash-retry duplicate lines).
        var byDay: [DayKey: DaySummary] = [:]
        for s in summaries { byDay[s.day] = s }
        let clearedDays = byDay.values.filter { $0.fullyCleared }.count

        let streak = computeStreak(today: today,
                                   todayHasTasks: todayHasTasks,
                                   todayCleared: todayCleared,
                                   summariesByDay: byDay)

        return Stats(currentStreak: streak,
                     todayOpen: todayOpen,
                     todayDone: todayDone,
                     todayCleared: todayCleared,
                     lifetimeCompleted: archivedCount,
                     clearedDays: clearedDays)
    }

    /// Walks backwards from today counting cleared days: cleared extends the streak,
    /// zero-task days are neutral (skipped), has-tasks-not-cleared breaks — except
    /// today itself, which gets a grace pass so a streak can "end at yesterday".
    static func computeStreak(today: DayKey,
                              todayHasTasks: Bool,
                              todayCleared: Bool,
                              summariesByDay: [DayKey: DaySummary]) -> Int {
        // Nothing recorded and nothing live → no streak.
        let earliest = summariesByDay.keys.min()
        var streak = 0
        var day = today
        var isToday = true

        while true {
            // Below all recorded history: only neutral days remain → stop.
            if let earliest, day < earliest, !isToday { break }
            if earliest == nil, !isToday { break }

            let hasTasks: Bool
            let cleared: Bool
            if isToday {
                hasTasks = todayHasTasks
                cleared = todayCleared
            } else if let s = summariesByDay[day] {
                hasTasks = (s.completed + s.stillOpen) > 0
                cleared = s.fullyCleared
            } else {
                hasTasks = false
                cleared = false
            }

            if cleared {
                streak += 1
            } else if !hasTasks {
                // neutral: skip without breaking
            } else {
                // has tasks but not cleared
                if isToday {
                    // today in progress: don't break, allow streak to end yesterday
                } else {
                    break
                }
            }

            day = day.adding(-1)
            isToday = false
        }
        return streak
    }
}
