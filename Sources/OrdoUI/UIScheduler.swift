// OrdoUI — injectable delayed-work scheduler for the undo-toast expiry and checkbox-
// reflow delay. Injecting it keeps AppModel deterministic under test (a manual
// scheduler fires on demand); production uses the main run loop.

import Foundation

/// Schedules `work` to run after `interval` seconds on the main actor.
@MainActor
public protocol UIScheduler: AnyObject {
    func after(_ interval: TimeInterval, _ work: @escaping @MainActor () -> Void)
}

/// Production scheduler: main-queue `asyncAfter`.
@MainActor
public final class MainQueueScheduler: UIScheduler {
    public nonisolated init() {}
    public func after(_ interval: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            MainActor.assumeIsolated { work() }
        }
    }
}
