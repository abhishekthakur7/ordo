// OrdoApp — TriggerCenter: fires defer-aware `model.requestRollover()` on every
// rollover trigger (§3.3: launch, day-change, wake, clock change, day-boundary timer),
// and hops external-edit callbacks to the main actor as reloads (§5.3).

import AppKit
import Foundation
import OrdoCore
import OrdoUI

@MainActor
final class TriggerCenter {

    private let model: AppModel
    private let store: TaskStore
    private let clock: OrdoClock

    private var observers: [NSObjectProtocol] = []
    private var boundaryTimer: Timer?

    init(model: AppModel, store: TaskStore, clock: OrdoClock) {
        self.model = model
        self.store = store
        self.clock = clock
    }

    func start() {
        // App launch trigger.
        fireRollover()

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fireRollover() }
        })
        observers.append(nc.addObserver(forName: NSNotification.Name("NSSystemClockDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fireRollover() }
        })

        let wnc = NSWorkspace.shared.notificationCenter
        observers.append(wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fireRollover() }
        })

        // External-edit watcher: store calls back off-main; hop to main.
        store.startWatchingExternalEdits { [weak self] in
            Task { @MainActor in self?.model.requestExternalReload() }
        }

        armBoundaryTimer()
    }

    func stop() {
        let nc = NotificationCenter.default
        let wnc = NSWorkspace.shared.notificationCenter
        for o in observers { nc.removeObserver(o); wnc.removeObserver(o) }
        observers.removeAll()
        boundaryTimer?.invalidate()
        boundaryTimer = nil
        store.stopWatchingExternalEdits()
    }

    // MARK: Rollover

    private func fireRollover() {
        model.requestRollover()
        // The logical day may have advanced; re-arm for the next boundary.
        armBoundaryTimer()
    }

    // MARK: Boundary timer

    private func armBoundaryTimer() {
        boundaryTimer?.invalidate()
        let fireDate = nextBoundaryDate()
        let interval = max(1, fireDate.timeIntervalSince(clock.now))
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.boundaryFired() }
        }
        // Tolerance keeps the timer power-friendly; a few seconds' slack is fine for
        // a day boundary. Wake/day-changed notifications cover the exact instant.
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        boundaryTimer = timer
    }

    private func boundaryFired() {
        model.requestRollover()
        armBoundaryTimer()
    }

    /// The next logical day boundary: (calendar midnight + dayStartOffset) strictly
    /// after now, in the clock's current time zone.
    private func nextBoundaryDate() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = clock.timeZone
        let now = clock.now
        let offset = TimeInterval(store.dayStartOffset)

        let startOfToday = cal.startOfDay(for: now)
        var boundary = startOfToday.addingTimeInterval(offset)
        if boundary <= now {
            let nextMidnight = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
            boundary = nextMidnight.addingTimeInterval(offset)
        }
        return boundary
    }
}
