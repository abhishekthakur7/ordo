// OrdoUI — AppModel: the observable façade the whole panel binds to (ARCHITECTURE
// §6.3). Owns the TaskStore, clock, theme and all view state. Every mutation routes
// through ONE diff path (`applyChange` → `rebuild`) so all sources animate identically.

import Foundation
import Observation
import SwiftUI
import OrdoCore
import OrdoThemes

@MainActor
@Observable
public final class AppModel {

    // MARK: Injected collaborators (not observed)

    @ObservationIgnored public let store: TaskStore
    @ObservationIgnored let clock: OrdoClock
    @ObservationIgnored let sounds: SoundPlaying
    @ObservationIgnored let scheduler: UIScheduler
    @ObservationIgnored let undoWindow: TimeInterval

    /// The settings object (observed by the UI directly).
    public let settings: AppSettings

    /// The active theme (its tokens, voice and signature views). Swapped live by
    /// the shell when the user changes theme.
    public var theme: any Theme

    /// The panel-chrome bridge, wired by the shell after construction. The model
    /// calls it to hold click-outside dismissal while a drag is in flight (§4.2).
    @ObservationIgnored public weak var chrome: PanelChrome?

    /// Last hold value pushed to the chrome, so we only notify on real transitions.
    @ObservationIgnored private var lastInteractionHold = false

    /// Mirrors `isAllClearedToday` as of the last `rebuild()`/`selectTab()` — the
    /// "before" value `toggle()` compares against to detect the transition into
    /// all-cleared. Only meaningful for themes with `providesCompletionFX`.
    @ObservationIgnored private var wasAllCleared = false

    // MARK: Exposed row state (the single source the list binds to)

    /// Open (not done) Today tasks, sorted by order.
    public private(set) var openToday: [OrdoTask] = []
    /// Done (still-live) Today tasks, sorted by order.
    public private(set) var doneToday: [OrdoTask] = []
    /// Open long-term tasks.
    public private(set) var openLongterm: [OrdoTask] = []
    /// Done (still-live) long-term tasks.
    public private(set) var doneLongterm: [OrdoTask] = []

    /// Open rows for the active tab.
    public var openRows: [OrdoTask] { tab == .today ? openToday : openLongterm }
    /// Done rows for the active tab.
    public var doneRows: [OrdoTask] { tab == .today ? doneToday : doneLongterm }

    /// All active-tab tasks in stored order, for themes where
    /// `showsDoneSection == false` (Arcade), which render one flat list.
    public var allRows: [OrdoTask] { store.tasks(in: tab) }

    // MARK: View state

    /// The active tab. Persists within a session; panel *open* resets it to Today.
    public var tab: TaskList = .today

    /// The selected row (keyboard highlight), or nil.
    public var selectedID: UUID?

    /// Whether the in-panel settings pane is showing.
    public var settingsOpen = false

    /// Reduce-Motion mirror, pushed from the SwiftUI environment by the root view.
    /// Drives whether reflow delays are honored (mockup skips them under reduced).
    public var reduceMotion = false {
        didSet { syncSystemAppearance() }
    }

    /// Whether the system is currently in dark mode (pushed from the environment /
    /// shell). Only consulted when `settings.appearance == .system`.
    public var systemIsDark = false

    // MARK: Composer

    /// The composer text field contents.
    public var composerText: String = "" {
        didSet { interactionDidChange() }
    }

    /// A pending large paste (> maxPasteLines) awaiting a quiet inline confirm.
    public private(set) var pendingPaste: PendingPaste?

    // MARK: Inline edit

    /// The task currently being inline-edited, or nil.
    public private(set) var editingTaskID: UUID? {
        didSet { interactionDidChange() }
    }
    /// The live text buffer for the inline editor.
    public var editingText: String = ""

    // MARK: Drag / undo

    /// Whether a reorder drag is in progress (blocks deferred rollover).
    public var isDragging = false {
        didSet { interactionDidChange() }
    }

    /// The active undo toast, or nil.
    public private(set) var undoToast: UndoToast?

    // MARK: Deferred work (§3.4 defer rule)

    @ObservationIgnored private var deferredRequests: [DeferredRequest] = []

    // MARK: Config

    /// Maximum lines added silently from a multi-line paste (§4.1). Beyond this a
    /// quiet inline confirm appears.
    public let maxPasteLines = 20
    /// Character cap for a title (mirrors OrdoCore's `sanitizedTitle`).
    public let titleCharacterLimit = 500
    /// The soft counter appears once the composer passes this length.
    public let counterThreshold = 400

    // MARK: Init

    public init(store: TaskStore,
                clock: OrdoClock,
                theme: any Theme,
                settings: AppSettings,
                sounds: SoundPlaying,
                scheduler: UIScheduler = MainQueueScheduler(),
                undoWindow: TimeInterval = 10) {
        self.store = store
        self.clock = clock
        self.theme = theme
        self.settings = settings
        self.sounds = sounds
        self.scheduler = scheduler
        self.undoWindow = undoWindow
        self.sounds.isEnabled = settings.soundEnabled
        rebuild()
    }

    // MARK: Lifecycle (called by the shell)

    /// Panel opened: the guaranteed-fresh moment. Runs catch-up, resets to the
    /// Today tab, clears transient state (§4.1). Rebuild is unanimated — the
    /// panel's own entrance animation carries it.
    public func panelWillOpen() {
        _ = store.catchUp()
        tab = .today
        selectedID = nil
        // Composer DRAFT is preserved across close/reopen within a session (§4.1) —
        // do NOT clear composerText here. Only the transient large-paste confirm is
        // dropped. Defensively clear a stuck drag flag so the defer system can't wedge.
        pendingPaste = nil
        isDragging = false
        settingsOpen = false
        rebuild()
    }

    /// Panel closed: commit any active inline edit (blur commits per §4.1 — an empty
    /// edit still cancels), run deferred rollover/reload, then flush to disk.
    public func panelDidClose() {
        commitEditing()
        drainDeferred()
        store.flush()
    }

    // MARK: Deferred rollover / external reload (§3.4)

    /// Request a rollover pass. Deferred while the user is interacting.
    public func requestRollover() {
        if interactionActive { enqueue(.rollover) } else { performRollover() }
    }

    /// Request an external-edit reload. Deferred while the user is interacting.
    public func requestExternalReload() {
        if interactionActive { enqueue(.reload) } else { performReload() }
    }

    /// Whether the user is actively touching the list (typing a non-empty composer,
    /// inline-editing, or dragging). Incoming rollover/reload defers while true.
    public var interactionActive: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || editingTaskID != nil
            || isDragging
    }

    private func enqueue(_ request: DeferredRequest) {
        if !deferredRequests.contains(request) { deferredRequests.append(request) }
    }

    private func interactionDidChange() {
        if !interactionActive { drainDeferred() }
        // Hold click-outside dismissal ONLY while a drag is in flight. Typing and
        // inline edits do not hold: drafts survive a close (§4.1) and an active edit
        // commits on blur (panelDidClose), so a click-outside there loses nothing.
        let shouldHold = isDragging
        if shouldHold != lastInteractionHold {
            lastInteractionHold = shouldHold
            chrome?.notifyInteraction(active: shouldHold)
        }
    }

    private func drainDeferred() {
        guard !deferredRequests.isEmpty else { return }
        let requests = deferredRequests
        deferredRequests = []
        for request in requests {
            switch request {
            case .rollover: performRollover()
            case .reload: performReload()
            }
        }
    }

    private func performRollover() {
        let change = store.catchUp()
        applyChange(change, animation: theme.motion.flipMove)
    }

    private func performReload() {
        let change = store.reloadFromDisk()
        applyChange(change, animation: theme.motion.flipMove)
    }

    // MARK: Tab & selection

    public func selectTab(_ newTab: TaskList) {
        guard tab != newTab else { return }
        tab = newTab
        selectedID = nil
        wasAllCleared = isAllClearedToday
        sounds.play(.tabSwitch)
    }

    /// Move the keyboard selection through the flattened visible list (open then done).
    public func moveSelection(_ direction: MoveDirection) {
        let order = openRows.map(\.id) + doneRows.map(\.id)
        guard !order.isEmpty else { selectedID = nil; return }
        guard let current = selectedID, let index = order.firstIndex(of: current) else {
            selectedID = direction == .down ? order.first : order.last
            return
        }
        let next: Int
        switch direction {
        case .down: next = min(index + 1, order.count - 1)
        case .up:   next = max(index - 1, 0)
        }
        selectedID = order[next]
    }

    // MARK: Add

    /// Submit the composer. Single line → one task; multi-line → one task per line
    /// (≤ maxPasteLines added directly, more triggers a quiet confirm). Empty → no-op.
    public func submitComposer() {
        let lines = AppModel.nonEmptyLines(composerText)
        guard !lines.isEmpty else { return }

        if lines.count == 1 {
            addSingle(lines[0])
            return
        }
        if lines.count > maxPasteLines {
            pendingPaste = PendingPaste(lines: lines)
            return
        }
        addBatch(lines)
    }

    private func addSingle(_ title: String) {
        let change = store.add(title, to: tab)
        composerText = ""
        guard !change.isEmpty else { return }
        sounds.play(.add)
        applyChange(change, animation: theme.motion.rowEntrance)
    }

    private func addBatch(_ lines: [String]) {
        let change = store.addBatch(lines, to: tab)
        composerText = ""
        guard !change.isEmpty else { return }
        sounds.play(.add)
        applyChange(change, animation: theme.motion.rowEntrance)
    }

    /// Confirm a pending large paste — adds every line.
    public func confirmPendingPaste() {
        guard let pending = pendingPaste else { return }
        pendingPaste = nil
        addBatch(pending.lines)
    }

    /// Dismiss a pending large paste without adding.
    public func cancelPendingPaste() {
        pendingPaste = nil
        composerText = ""
    }

    /// Whether the composer currently holds an addable (non-empty) title.
    public var canAdd: Bool {
        sanitizedTitle(composerText) != nil
    }

    /// Whether the soft character counter should show.
    public var showCharacterCounter: Bool {
        composerText.count > counterThreshold
    }

    /// Characters remaining before the hard cap.
    public var charactersRemaining: Int {
        titleCharacterLimit - composerText.count
    }

    // MARK: Complete / uncheck (the hero, with reflow choreography)

    /// Toggle a task's done state with the mockup's two-phase choreography: the
    /// checkbox flips in place, then after the reflow delay the row travels to
    /// (or from) the done section.
    public func toggle(_ id: UUID) {
        guard let task = store.task(id: id) else { return }
        let becomingDone = !task.done
        let change = store.toggleDone(id)
        guard !change.isEmpty else { return }

        sounds.play(becomingDone ? .complete : .uncheck)

        guard theme.showsDoneSection else {
            let clearedBefore = wasAllCleared
            applyChange(change, animation: theme.motion.titleColorFade)

            if theme.providesCompletionFX && !reduceMotion && becomingDone {
                if !clearedBefore && isAllClearedToday {
                    arcadeFXEvent = ArcadeFXEvent(kind: .stageClear)
                } else {
                    arcadeFXEvent = ArcadeFXEvent(kind: .complete(taskID: id))
                }
            }
            return
        }

        if reduceMotion {
            applyChange(change, animation: theme.motion.flipMove)
            return
        }

        // Phase 1: flip done in the display arrays without moving the row.
        setDisplayDone(id, becomingDone)

        // Phase 2: reflow after the theme's delay.
        let seq = theme.motion.checkboxSequence
        let delay = becomingDone ? seq.completeReflowDelay : seq.uncheckReflowDelay
        scheduler.after(delay) { [weak self] in
            guard let self else { return }
            withAnimation(self.theme.motion.flipMove.animation(reduceMotion: self.reduceMotion)) {
                self.rebuild()
            }
        }
    }

    // MARK: Inline edit (§4.1)

    public func beginEditing(_ id: UUID) {
        guard let task = store.task(id: id) else { return }
        selectedID = id
        editingText = task.title
        editingTaskID = id
    }

    /// Commit the inline edit. Empty commit = cancel (never a delete, §4.1).
    public func commitEditing() {
        guard let id = editingTaskID else { return }
        let change = store.editTitle(id, to: editingText)
        editingTaskID = nil
        editingText = ""
        applyChange(change, animation: theme.motion.titleColorFade)
    }

    public func cancelEditing() {
        editingTaskID = nil
        editingText = ""
    }

    // MARK: Delete + undo (§2.2, §4.1)

    public func delete(_ id: UUID) {
        guard let task = store.task(id: id) else { return }
        if selectedID == id { moveSelectionAfterDelete(of: id) }
        let change = store.delete(id)
        guard !change.isEmpty else { return }

        undoToast = UndoToast(taskID: id, title: task.title, expiresAt: clock.now.addingTimeInterval(undoWindow))
        applyChange(change, animation: theme.motion.flipMove)

        scheduler.after(undoWindow) { [weak self] in
            self?.expireUndo(id)
        }
    }

    public func undoDelete() {
        guard let toast = undoToast else { return }
        let change = store.undoDelete(toast.taskID)
        undoToast = nil
        applyChange(change, animation: theme.motion.rowEntrance)
    }

    private func expireUndo(_ id: UUID) {
        guard let toast = undoToast, toast.taskID == id, clock.now >= toast.expiresAt else { return }
        withAnimation(theme.motion.panelExit.animation(reduceMotion: reduceMotion)) {
            undoToast = nil
        }
    }

    private func moveSelectionAfterDelete(of id: UUID) {
        let order = openRows.map(\.id) + doneRows.map(\.id)
        guard let index = order.firstIndex(of: id) else { selectedID = nil; return }
        let remaining = order.filter { $0 != id }
        guard !remaining.isEmpty else { selectedID = nil; return }
        selectedID = remaining[min(index, remaining.count - 1)]
    }

    // MARK: Reorder (expanded view, §4.1)

    /// Move a task within its list to a new visible index (open-section order).
    public func move(_ id: UUID, toIndex index: Int) {
        let change = store.move(id, toIndex: index)
        applyChange(change, animation: theme.motion.flipMove)
    }

    /// The index to hand `store.move` so a dragged row lands at the target's visual
    /// slot. `store.move` indexes the sibling list (dragged row excluded), so a
    /// downward drag must decrement to compensate for the removal shift. Pure/testable.
    public static func reorderIndex(orderedIDs ids: [UUID], dragging: UUID, target: UUID) -> Int? {
        guard let from = ids.firstIndex(of: dragging),
              let to = ids.firstIndex(of: target) else { return nil }
        return from < to ? to - 1 : to
    }

    // MARK: Promote / demote / triage (§2.2, §3.5)

    /// Long-term → Today ("Do today").
    public func promote(_ id: UUID) {
        let change = store.promote(id)
        applyChange(change, animation: theme.motion.flipMove)
    }

    /// Today → Long-term ("Move to Long-term", also the triage path).
    public func demote(_ id: UUID) {
        let change = store.demote(id)
        applyChange(change, animation: theme.motion.flipMove)
    }

    /// Triage "Keep": snooze the nudge 7 more days without resetting age.
    public func keepInTriage(_ id: UUID) {
        let change = store.keepInTriage(id)
        applyChange(change, animation: theme.motion.titleColorFade)
    }

    // MARK: Derived (age, triage, rail stats, header)

    public func age(of task: OrdoTask) -> Int { store.age(of: task) ?? 0 }
    public func isInTriage(_ task: OrdoTask) -> Bool { store.isInTriage(task) }

    /// Live remaining (open) counts for the tab badges.
    public var todayRemaining: Int { openToday.count }
    public var longtermRemaining: Int { openLongterm.count }

    /// Rail figures for the active tab (mockup Completed/Remaining/Total + ring).
    public var railDone: Int { doneRows.count }
    public var railRemaining: Int { openRows.count }
    public var railTotal: Int { openRows.count + doneRows.count }

    /// Store-wide derived stats (streaks etc.), for any consumer that wants them.
    public func stats() -> Stats { store.stats() }

    // MARK: Gamification (Arcade — derived, non-persistent, visual-only)

    /// Score = Today tasks done × 100, regardless of the active tab. Derived,
    /// never persisted; other themes never read it.
    public var arcadeScore: Int { doneToday.count * 100 }

    /// Session high-water mark for `arcadeScore` since this `AppModel` was
    /// created. Never persisted — resets on relaunch.
    public private(set) var arcadeBest: Int = 0

    /// The current streak (consecutive cleared days), read straight from `Stats`.
    public var arcadeStreak: Int { stats().currentStreak }

    /// One-shot completion-FX trigger, observed by `ArcadeFXOverlay`. Set only
    /// from `toggle(_:)` when `theme.providesCompletionFX && !reduceMotion`;
    /// every event gets a fresh id so `.onChange` fires even on a repeat `kind`.
    public private(set) var arcadeFXEvent: ArcadeFXEvent?

    /// The current day-start offset in whole hours (advanced setting, §3.1).
    public var dayStartOffsetHours: Int { store.dayStartOffset / 3600 }

    /// Set the day-start offset (in whole hours). Writes through the store — NOT
    /// UserDefaults (C5) — and recomputes ages via the diff path.
    public func setDayStartOffsetHours(_ hours: Int) {
        let change = store.setDayStartOffset(hours * 3600)
        applyChange(change, animation: theme.motion.titleColorFade)
    }

    /// True when the active tab is Today, has ≥1 task, and all are done (§4.3).
    public var isAllClearedToday: Bool {
        tab == .today && openToday.isEmpty && !doneToday.isEmpty
    }

    /// True on the very first run with no tasks anywhere (§4.3).
    public var isFirstRunEmpty: Bool {
        store.isFirstLaunch && openToday.isEmpty && doneToday.isEmpty
            && openLongterm.isEmpty && doneLongterm.isEmpty
    }

    /// Whether the active tab's list is completely empty (no open, no done).
    public var isActiveTabEmpty: Bool {
        openRows.isEmpty && doneRows.isEmpty
    }

    /// The theme-voiced greeting for the current hour (from the injected clock).
    public var greeting: String { theme.greeting(forHour: currentHour) }

    /// The formatted long date line ("Sunday, 26 July"), locale-aware.
    public var dateLine: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = clock.timeZone
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: clock.now)
    }

    private var currentHour: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = clock.timeZone
        return calendar.component(.hour, from: clock.now)
    }

    // MARK: Sound + appearance sync

    /// Toggle global sound (footer switch). Plays the matching toggle sound.
    public func setSoundEnabled(_ enabled: Bool) {
        settings.soundEnabled = enabled
        sounds.isEnabled = enabled
        // Preview the flip so the change is audible regardless of the new state.
        if enabled { sounds.play(.toggleOn) }
    }

    /// The resolved appearance for the current setting + system state.
    public var resolvedAppearance: ResolvedUIAppearance {
        resolveAppearance(settings.appearance, systemIsDark: systemIsDark)
    }

    private func syncSystemAppearance() { /* hook for future live re-eval */ }

    // MARK: The single diff path

    /// Apply a ChangeSet by rebuilding the exposed arrays inside one animation.
    /// Every mutation source funnels through here (§6.3).
    func applyChange(_ change: ChangeSet, animation: MotionToken) {
        guard !change.isEmpty else { return }
        withAnimation(animation.animation(reduceMotion: reduceMotion)) {
            rebuild()
        }
    }

    /// Recompute the four exposed arrays from the store's live truth.
    func rebuild() {
        let today = store.tasks(in: .today)
        let longterm = store.tasks(in: .longterm)
        openToday = today.filter { !$0.done }
        doneToday = today.filter { $0.done }
        openLongterm = longterm.filter { !$0.done }
        doneLongterm = longterm.filter { $0.done }
        arcadeBest = max(arcadeBest, arcadeScore)
        wasAllCleared = isAllClearedToday
    }

    /// Phase-1 checkbox flip: set `done` on the display copy without re-sectioning.
    private func setDisplayDone(_ id: UUID, _ done: Bool) {
        func patch(_ array: inout [OrdoTask]) {
            if let i = array.firstIndex(where: { $0.id == id }) { array[i].done = done }
        }
        patch(&openToday); patch(&doneToday)
        patch(&openLongterm); patch(&doneLongterm)
    }

    // MARK: Helpers

    static func nonEmptyLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .compactMap { sanitizedTitle($0) }
    }
}

// MARK: - Supporting value types

/// A deferred time-driven request queued during an interaction (§3.4).
public enum DeferredRequest: Sendable, Hashable {
    case rollover
    case reload
}

/// Keyboard selection direction.
public enum MoveDirection: Sendable, Hashable {
    case up
    case down
}

/// A pending large multi-line paste awaiting a quiet inline confirm (§4.1).
public struct PendingPaste: Sendable, Hashable {
    public let lines: [String]
    public var count: Int { lines.count }
    public init(lines: [String]) { self.lines = lines }
}

/// A one-shot completion-FX trigger for themes that opt in via
/// `Theme.providesCompletionFX` (Arcade). `id` is a fresh `UUID` per event so
/// a repeated `kind` still produces a distinct value to re-trigger on.
public struct ArcadeFXEvent: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        /// A task was completed — drives the score-pop + burst.
        case complete(taskID: UUID)
        /// The active Today list just transitioned into fully cleared — drives confetti.
        case stageClear
    }

    public let id: UUID
    public let kind: Kind

    public init(kind: Kind) {
        self.id = UUID()
        self.kind = kind
    }
}

/// The transient undo affordance shown after a soft-delete (§2.2).
public struct UndoToast: Sendable, Hashable, Identifiable {
    public let taskID: UUID
    public let title: String
    public let expiresAt: Date
    public var id: UUID { taskID }
    public init(taskID: UUID, title: String, expiresAt: Date) {
        self.taskID = taskID
        self.title = title
        self.expiresAt = expiresAt
    }
}
