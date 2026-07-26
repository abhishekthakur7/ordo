import XCTest
import Foundation
@testable import OrdoCore
@testable import OrdoThemes
@testable import OrdoUI

/// A UIScheduler that never fires on its own — the test drives it, so delayed work
/// (checkbox reflow, undo-toast expiry) is deterministic with no sleeps.
@MainActor
final class ManualUIScheduler: UIScheduler {
    private(set) var pending: [@MainActor () -> Void] = []
    func after(_ interval: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        pending.append(work)
    }
    /// Run and clear every queued work item.
    func fireAll() {
        let work = pending
        pending = []
        for item in work { item() }
    }
}

/// A SoundPlaying spy that records what would have played.
final class RecordingSoundPlayer: SoundPlaying {
    var isEnabled: Bool = true
    private(set) var played: [SoundEvent] = []
    func play(_ event: SoundEvent) { if isEnabled { played.append(event) } }
}

/// Shared helpers for OrdoUI model tests.
enum UT {
    static let utc = TimeZone(identifier: "UTC")!

    static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ordo-ui-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func cleanup(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    /// A UserDefaults suite unique to a test, so prefs never leak between runs.
    static func defaults() -> UserDefaults {
        let name = "ordo.ui.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }
}

/// Base test case: temp dir, fixed clock, a manual scheduler, a sound spy, and a
/// factory for a store + model wired for deterministic behavior.
@MainActor
class UIModelTestCase: XCTestCase {
    var dir: URL!
    var clock: FixedClock!
    var scheduler: ManualUIScheduler!
    var sounds: RecordingSoundPlayer!
    var settings: AppSettings!

    override func setUp() {
        super.setUp()
        dir = UT.tempDir()
        clock = FixedClock(year: 2026, month: 7, day: 26, hour: 9, timeZone: UT.utc)
        scheduler = ManualUIScheduler()
        sounds = RecordingSoundPlayer()
        settings = AppSettings(defaults: UT.defaults())
    }

    override func tearDown() {
        if let dir { UT.cleanup(dir) }
        super.tearDown()
    }

    func makeStore(undoWindow: TimeInterval = 10) -> TaskStore {
        TaskStore(clock: clock,
                  persistence: Persistence(directory: dir),
                  scheduler: ImmediateSaveScheduler(),
                  undoWindow: undoWindow)
    }

    func makeModel(store: TaskStore, undoWindow: TimeInterval = 10) -> AppModel {
        AppModel(store: store,
                 clock: clock,
                 theme: MacOSTheme(),
                 settings: settings,
                 sounds: sounds,
                 scheduler: scheduler,
                 undoWindow: undoWindow)
    }
}
