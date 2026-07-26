// OrdoCore — debounced-save scheduling (ARCHITECTURE §5.2). Saves are debounced
// (~300 ms) and coalesced. Injectable so tests never sleep — use
// `ImmediateSaveScheduler` (synchronous) or call `TaskStore.flush()`.

import Foundation

/// Schedules a (debounced) save; `schedule` replaces any pending work item. The
/// closure is intentionally non-`Sendable`: `TaskStore` is single-actor confined
/// and the production scheduler fires on main, so a save never races a mutation.
public protocol SaveScheduler: AnyObject {
    /// Requests that `work` run after the debounce interval, cancelling any
    /// previously scheduled-but-unfired work.
    func schedule(_ work: @escaping () -> Void)
    /// Cancels pending work without running it (used by `flush`).
    func cancelPending()
}

/// Production scheduler: coalesces saves on a serial queue with a debounce delay.
public final class DebouncedSaveScheduler: SaveScheduler {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private var pending: DispatchWorkItem?

    /// Defaults to the main queue so the save runs on the same thread that owns
    /// `TaskStore`, avoiding a data race with concurrent mutations.
    public init(interval: TimeInterval = 0.3, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    public func schedule(_ work: @escaping () -> Void) {
        pending?.cancel()
        let item = DispatchWorkItem(block: work)
        pending = item
        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }

    public func cancelPending() {
        pending?.cancel()
        pending = nil
    }
}

/// Test/embedding scheduler: runs the save synchronously and immediately, so a
/// mutation is on disk the moment it returns. Deterministic, no sleeps.
public final class ImmediateSaveScheduler: SaveScheduler {
    public init() {}
    public func schedule(_ work: @escaping () -> Void) { work() }
    public func cancelPending() {}
}
