// OrdoCore — TaskStore: the single source of truth (ARCHITECTURE §2.2, §4.1, §6.3).
// Every mutation returns a diffable `ChangeSet` (contract C3). Single-actor
// confined (main), so a debounced save never races a mutation.

import Foundation

public final class TaskStore {
    // Injected collaborators.
    private let clock: OrdoClock
    private let persistence: Persistence
    private let scheduler: SaveScheduler
    private let undoWindow: TimeInterval
    private var engine: DayEngine

    // Live state.
    private var state: StoreState
    private var cachedStats: Stats?

    // Load diagnostics (surfaced once to the UI).
    public let isFirstLaunch: Bool
    public let corruptionNotice: Bool
    public let restoredFromBackup: Bool
    public let migratedFrom: Int?

    /// True when local state is unsaved: a debounced save is pending, or the last
    /// save failed (disk full) and state waits in memory to retry (ARCHITECTURE §8).
    /// Cleared on persist; `reloadFromDisk` flushes it first so local wins (§5.3).
    public private(set) var hasPendingSave = false

    /// The smallest gap between two `order` values before a reorder triggers a
    /// full renormalization of the list (ARCHITECTURE §3.5).
    static let minOrderGap = 1e-6

    // MARK: Init

    public init(clock: OrdoClock = SystemClock(),
                persistence: Persistence,
                scheduler: SaveScheduler,
                undoWindow: TimeInterval = 10) {
        self.clock = clock
        self.persistence = persistence
        self.scheduler = scheduler
        self.undoWindow = undoWindow

        let result = persistence.load()
        self.corruptionNotice = result.corruptionNoticed
        self.restoredFromBackup = result.restoredFromBackup
        self.migratedFrom = result.migratedFrom

        if let loaded = result.state {
            self.state = loaded
            self.engine = DayEngine(dayStartOffset: loaded.dayStartOffset)
            self.isFirstLaunch = false
        } else {
            // First launch (or unrecoverable corruption): fresh state, no catch-up
            // — lastProcessedDay = today (ARCHITECTURE §3.4).
            let engine0 = DayEngine(dayStartOffset: 0)
            let today = engine0.dayKey(for: clock.now, timeZone: clock.timeZone)
            self.engine = engine0
            self.state = StoreState(lastProcessedDay: today)
            self.isFirstLaunch = true
        }

        // Materialize the store file if absent (first launch, or a corruption→backup
        // restore where quarantine removed the live file). Re-persisting now means a
        // crash can't read as first-launch with backups present — no silent data loss (§5.2).
        let liveFileExists = FileManager.default.fileExists(atPath: persistence.storeURL.path)
        if isFirstLaunch || restoredFromBackup || !liveFileExists {
            try? persistence.save(state, backupDay: currentDayKey())
        }
    }

    /// Convenience initializer using the default debounced scheduler.
    public convenience init(directory: URL,
                            clock: OrdoClock = SystemClock(),
                            undoWindow: TimeInterval = 10) {
        self.init(clock: clock,
                  persistence: Persistence(directory: directory),
                  scheduler: DebouncedSaveScheduler(),
                  undoWindow: undoWindow)
    }

    // MARK: Day identity

    /// The current logical day (ARCHITECTURE §3.1). Uses the injected clock.
    public func currentDayKey() -> DayKey {
        engine.dayKey(for: clock.now, timeZone: clock.timeZone)
    }

    public var lastProcessedDay: DayKey { state.lastProcessedDay }
    public var dayStartOffset: Int { state.dayStartOffset }

    // MARK: Queries

    /// Tasks in a list, sorted by `order`, excluding soft-delete tombstones.
    public func tasks(in list: TaskList) -> [OrdoTask] {
        state.tasks
            .filter { $0.list == list && $0.deletedAt == nil }
            .sorted { $0.order < $1.order }
    }

    /// A live task by id, or nil if missing or tombstoned.
    public func task(id: UUID) -> OrdoTask? {
        state.tasks.first { $0.id == id && $0.deletedAt == nil }
    }

    /// All live (non-tombstoned) tasks, unsorted.
    public func allLiveTasks() -> [OrdoTask] {
        state.tasks.filter { $0.deletedAt == nil }
    }

    /// Derived age in days for a Today task (currentDay − addedToTodayOn), clamped
    /// to ≥0. nil for long-term tasks. Never stored (ARCHITECTURE §2.1).
    public func age(of task: OrdoTask) -> Int? {
        guard let added = task.addedToTodayOn else { return nil }
        return max(0, currentDayKey().days(since: added))
    }

    /// Whether a task should show the triage affordance right now: a Today task
    /// aged ≥7 whose triage nudge is not currently snoozed by a recent "Keep"
    /// (ARCHITECTURE §3.5).
    public func isInTriage(_ task: OrdoTask) -> Bool {
        guard task.list == .today, let age = age(of: task), age >= 7 else { return false }
        if let kept = task.triageKeptOn {
            return currentDayKey().days(since: kept) >= 7
        }
        return true
    }

    // MARK: Mutations — add

    /// Adds a task at the bottom of its list. Rejects empty/whitespace titles;
    /// caps at 500 chars. Returns the created id in `inserted` (empty = rejected).
    @discardableResult
    public func add(_ rawTitle: String, to list: TaskList) -> ChangeSet {
        guard let title = sanitizedTitle(rawTitle) else { return .empty }
        let task = makeTask(title: title, list: list, order: nextOrder(in: list))
        state.tasks.append(task)
        scheduleSave()
        return ChangeSet(inserted: [task.id])
    }

    /// Adds multiple tasks (multi-line paste), one per line, appended at the bottom
    /// in order (ARCHITECTURE §4.1). Empty lines are skipped. The 20-line cap and
    /// its confirmation are a UI policy, not enforced here.
    @discardableResult
    public func addBatch(_ rawTitles: [String], to list: TaskList) -> ChangeSet {
        var inserted: [UUID] = []
        var order = nextOrder(in: list)
        for raw in rawTitles {
            guard let title = sanitizedTitle(raw) else { continue }
            let task = makeTask(title: title, list: list, order: order)
            order += 1
            state.tasks.append(task)
            inserted.append(task.id)
        }
        if !inserted.isEmpty { scheduleSave() }
        return ChangeSet(inserted: inserted)
    }

    /// Splits `text` on newlines and batch-adds one task per non-empty line.
    @discardableResult
    public func addLines(_ text: String, to list: TaskList) -> ChangeSet {
        addBatch(text.components(separatedBy: .newlines), to: list)
    }

    // MARK: Mutations — complete / edit

    /// Sets a live task's done state. Uncheck works only while live — archived
    /// tasks are gone from the store, so their id resolves to a no-op.
    @discardableResult
    public func setDone(_ id: UUID, _ done: Bool) -> ChangeSet {
        guard let i = liveIndex(id), state.tasks[i].done != done else { return .empty }
        state.tasks[i].done = done
        state.tasks[i].completedAt = done ? clock.now : nil
        scheduleSave()
        return ChangeSet(updated: [id])
    }

    /// Toggles a live task's done state.
    @discardableResult
    public func toggleDone(_ id: UUID) -> ChangeSet {
        guard let t = task(id: id) else { return .empty }
        return setDone(id, !t.done)
    }

    /// Edits a title. Trims/caps; an empty commit is a no-op (not a delete).
    @discardableResult
    public func editTitle(_ id: UUID, to rawTitle: String) -> ChangeSet {
        guard let i = liveIndex(id) else { return .empty }
        guard let title = sanitizedTitle(rawTitle) else { return .empty } // empty = cancel
        guard state.tasks[i].title != title else { return .empty }
        state.tasks[i].title = title
        scheduleSave()
        return ChangeSet(updated: [id])
    }

    // MARK: Mutations — soft delete / undo

    /// Soft-deletes a task: hidden immediately, purged at the first save after the
    /// undo window closes (ARCHITECTURE §2.2).
    @discardableResult
    public func delete(_ id: UUID) -> ChangeSet {
        guard let i = liveIndex(id) else { return .empty }
        state.tasks[i].deletedAt = clock.now
        scheduleSave()
        return ChangeSet(removed: [id])
    }

    /// Restores a soft-deleted task if still within the undo window; else no-op.
    @discardableResult
    public func undoDelete(_ id: UUID) -> ChangeSet {
        guard let i = state.tasks.firstIndex(where: { $0.id == id }),
              let deletedAt = state.tasks[i].deletedAt,
              clock.now.timeIntervalSince(deletedAt) < undoWindow else { return .empty }
        state.tasks[i].deletedAt = nil
        scheduleSave()
        return ChangeSet(inserted: [id])
    }

    // MARK: Mutations — reorder

    /// Moves a task to `index` within its list (fractional order; renormalizes
    /// when neighbor gaps get too tight, ARCHITECTURE §3.5).
    @discardableResult
    public func move(_ id: UUID, toIndex index: Int) -> ChangeSet {
        guard let moving = liveTask(id) else { return .empty }
        let list = moving.list
        let siblings = tasks(in: list).filter { $0.id != id }
        let clamped = max(0, min(index, siblings.count))
        let before = clamped > 0 ? siblings[clamped - 1].order : nil
        let after = clamped < siblings.count ? siblings[clamped].order : nil

        if let b = before, let a = after, (a - b) < TaskStore.minOrderGap {
            return renormalizeAndPlace(id: id, at: clamped, list: list)
        }
        let newOrder: Double
        switch (before, after) {
        case (nil, nil): newOrder = 1
        case (nil, let a?): newOrder = a - 1
        case (let b?, nil): newOrder = b + 1
        case (let b?, let a?): newOrder = (b + a) / 2
        }
        setOrder(id, newOrder)
        scheduleSave()
        return ChangeSet(moved: [id])
    }

    private func renormalizeAndPlace(id: UUID, at index: Int, list: TaskList) -> ChangeSet {
        guard let moving = liveTask(id) else { return .empty }
        var ordered = tasks(in: list).filter { $0.id != id }
        let idx = max(0, min(index, ordered.count))
        ordered.insert(moving, at: idx)
        var updated: [UUID] = []
        for (n, t) in ordered.enumerated() {
            let newOrder = Double(n + 1)
            if let i = anyIndex(of: t.id), state.tasks[i].order != newOrder {
                state.tasks[i].order = newOrder
                if t.id != id { updated.append(t.id) }
            }
        }
        scheduleSave()
        return ChangeSet(moved: [id], updated: updated)
    }

    // MARK: Mutations — promote / demote / triage

    /// Long-term → Today: sets addedToTodayOn = today, keeps id/createdAt
    /// (ARCHITECTURE §2.2). Appended at the bottom of Today.
    @discardableResult
    public func promote(_ id: UUID) -> ChangeSet {
        guard let i = liveIndex(id), state.tasks[i].list == .longterm else { return .empty }
        state.tasks[i].list = .today
        state.tasks[i].addedToTodayOn = currentDayKey()
        state.tasks[i].triageKeptOn = nil
        state.tasks[i].order = nextOrder(in: .today)
        scheduleSave()
        return ChangeSet(updated: [id])
    }

    /// Today → Long-term: clears addedToTodayOn (ARCHITECTURE §2.2). Also the
    /// triage "Move to Long-term" path.
    @discardableResult
    public func demote(_ id: UUID) -> ChangeSet {
        guard let i = liveIndex(id), state.tasks[i].list == .today else { return .empty }
        state.tasks[i].list = .longterm
        state.tasks[i].addedToTodayOn = nil
        state.tasks[i].triageKeptOn = nil
        state.tasks[i].order = nextOrder(in: .longterm)
        scheduleSave()
        return ChangeSet(updated: [id])
    }

    /// Triage "Keep": snoozes the nudge for 7 more days without resetting age
    /// (ARCHITECTURE §3.5).
    @discardableResult
    public func keepInTriage(_ id: UUID) -> ChangeSet {
        guard let i = liveIndex(id), state.tasks[i].list == .today else { return .empty }
        state.tasks[i].triageKeptOn = currentDayKey()
        scheduleSave()
        return ChangeSet(updated: [id])
    }

    // MARK: Semantic setting

    /// Sets the day-start offset (seconds after midnight). Changes day identity,
    /// so all Today ages recompute (ARCHITECTURE §3.1). Persisted in store.json.
    @discardableResult
    public func setDayStartOffset(_ seconds: Int) -> ChangeSet {
        guard state.dayStartOffset != seconds else { return .empty }
        state.dayStartOffset = seconds
        engine.dayStartOffset = seconds
        scheduleSave()
        return ChangeSet(updated: tasks(in: .today).map { $0.id })
    }

    // MARK: Rollover

    /// Runs the rollover engine at the current clock time (ARCHITECTURE §3.2).
    /// Idempotent and monotonic; safe at every trigger. History is appended before
    /// the store advances, so a crash can duplicate a line (deduped) but never lose one.
    @discardableResult
    public func catchUp() -> ChangeSet {
        guard let outcome = engine.computeCatchUp(state: state,
                                                  now: clock.now,
                                                  timeZone: clock.timeZone,
                                                  undoWindow: undoWindow) else {
            return .empty
        }
        var records: [HistoryRecord] = outcome.archived.map { .task($0) }
        records += outcome.summaries.map { .summary($0) }
        do {
            try persistence.appendHistory(records)
        } catch {
            // Couldn't archive to history — abort this pass; state is untouched
            // and the next trigger retries.
            hasPendingSave = true
            return .empty
        }
        state.tasks = outcome.remainingTasks
        state.lastProcessedDay = outcome.newLastProcessedDay
        cachedStats = nil
        persist()
        return outcome.changeSet
    }

    // MARK: External edit reload (ARCHITECTURE §5.3)

    /// Re-reads the store from disk and returns the diff. Last-write-wins with a
    /// twist: an unsaved local change is flushed first (local wins), then the file
    /// is re-read.
    @discardableResult
    public func reloadFromDisk() -> ChangeSet {
        // Flush unsaved local state FIRST (local wins), so a debounced-pending
        // mutation is never clobbered by re-reading a staler file (ARCHITECTURE §5.3).
        if hasPendingSave { persist() }
        let result = persistence.load()
        guard let newState = result.state else { return .empty }
        // Short-circuit identical state: our own atomic save self-triggers the file
        // watcher, so most reloads see exactly what we just wrote. Return empty and
        // do NOT rebuild — this also neutralizes those benign self-triggered events.
        guard newState != state else { return .empty }
        let diff = TaskStore.diff(from: state.tasks, to: newState.tasks)
        state = newState
        engine.dayStartOffset = newState.dayStartOffset
        cachedStats = nil
        return diff
    }

    // MARK: Persistence control

    /// Forces an immediate save (panel close, app termination, before rollover).
    public func flush() {
        purgeExpiredTombstones()
        persist()
    }

    /// A read-only snapshot of the persisted state (for integrators/tests).
    public var snapshot: StoreState { state }

    // MARK: Stats

    /// Current derived stats (ARCHITECTURE §7). Cached; invalidated on mutation.
    public func stats() -> Stats {
        if let cached = cachedStats { return cached }
        let s = StatsEngine.compute(
            liveTodayTasks: tasks(in: .today),
            today: currentDayKey(),
            summaries: persistence.loadSummaries(),
            archivedCount: persistence.archivedTaskCount())
        cachedStats = s
        return s
    }

    // MARK: File watching (delegates to persistence; app hops to main)

    public func startWatchingExternalEdits(onChange: @escaping @Sendable () -> Void) {
        persistence.startWatching(onChange: onChange)
    }

    public func stopWatchingExternalEdits() {
        persistence.stopWatching()
    }

    // MARK: Internals

    private func makeTask(title: String, list: TaskList, order: Double) -> OrdoTask {
        OrdoTask(title: title,
                 list: list,
                 createdAt: clock.now,
                 addedToTodayOn: list == .today ? currentDayKey() : nil,
                 order: order)
    }

    private func nextOrder(in list: TaskList) -> Double {
        let maxOrder = state.tasks
            .filter { $0.list == list && $0.deletedAt == nil }
            .map { $0.order }
            .max()
        return (maxOrder ?? 0) + 1
    }

    private func liveIndex(_ id: UUID) -> Int? {
        state.tasks.firstIndex { $0.id == id && $0.deletedAt == nil }
    }

    private func anyIndex(of id: UUID) -> Int? {
        state.tasks.firstIndex { $0.id == id }
    }

    private func liveTask(_ id: UUID) -> OrdoTask? {
        state.tasks.first { $0.id == id && $0.deletedAt == nil }
    }

    private func setOrder(_ id: UUID, _ order: Double) {
        if let i = liveIndex(id) { state.tasks[i].order = order }
    }

    private func purgeExpiredTombstones() {
        let now = clock.now
        let window = undoWindow
        state.tasks.removeAll { t in
            if let d = t.deletedAt { return now.timeIntervalSince(d) >= window }
            return false
        }
    }

    private func scheduleSave() {
        cachedStats = nil
        // Track dirtiness truthfully: a scheduled save marks the store dirty until it
        // persists (cleared in `persist`). Immediate scheduler flips it back
        // synchronously; debounced stays true until the timer fires (or flush/reload).
        hasPendingSave = true
        scheduler.schedule { [weak self] in self?.flush() }
    }

    private func persist() {
        scheduler.cancelPending()
        do {
            try persistence.save(state, backupDay: currentDayKey())
            hasPendingSave = false
        } catch {
            hasPendingSave = true // soft-fail: keep state in memory, retry later
        }
    }

    /// Diffs two task arrays into a change set (used for external reloads).
    static func diff(from old: [OrdoTask], to new: [OrdoTask]) -> ChangeSet {
        let oldLive = old.filter { $0.deletedAt == nil }
        let newLive = new.filter { $0.deletedAt == nil }
        let oldByID = Dictionary(uniqueKeysWithValues: oldLive.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: newLive.map { ($0.id, $0) })

        var inserted: [UUID] = []
        var removed: [UUID] = []
        var moved: [UUID] = []
        var updated: [UUID] = []

        for t in newLive where oldByID[t.id] == nil { inserted.append(t.id) }
        for t in oldLive where newByID[t.id] == nil { removed.append(t.id) }
        for t in newLive {
            guard let prev = oldByID[t.id], prev != t else { continue }
            // Only order changed → a move; anything else → an update.
            var probe = prev
            probe.order = t.order
            if probe == t && prev.order != t.order {
                moved.append(t.id)
            } else {
                updated.append(t.id)
            }
        }
        return ChangeSet(inserted: inserted, removed: removed, moved: moved, updated: updated)
    }
}
