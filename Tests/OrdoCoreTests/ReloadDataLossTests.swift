import XCTest
@testable import OrdoCore

/// Regression suite for the data-loss class fixed in phase 4:
///  • `reloadFromDisk` must flush a debounced-pending local mutation before adopting
///    the file, so a self-triggered watcher event can never discard unsaved work.
///  • a corruption→backup restore must be re-persisted at init so a later crash does
///    not look like a first launch with backups sitting right there.
final class ReloadDataLossTests: XCTestCase {
    var dir: URL!
    var clock: FixedClock!

    override func setUp() {
        super.setUp()
        dir = T.tempDir()
        clock = FixedClock(year: 2026, month: 7, day: 26, hour: 12, timeZone: T.utc)
    }
    override func tearDown() { if let dir { T.cleanup(dir) }; super.tearDown() }

    private func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    /// A scheduler that captures the save work WITHOUT running it, so a mutation is
    /// "debounced but unfired" — exactly the window the kill chain exploited.
    final class HoldingSaveScheduler: SaveScheduler {
        private(set) var pending: (() -> Void)?
        func schedule(_ work: @escaping () -> Void) { pending = work }
        func cancelPending() { pending = nil }
        func fire() { let w = pending; pending = nil; w?() }
    }

    // FINDING 1 — the exact kill chain: a debounced-pending mutation must survive a
    // reload (in memory AND on disk), not be overwritten by a staler file read.
    func testReloadPreservesDebouncedPendingMutation() {
        let scheduler = HoldingSaveScheduler()
        let store = TaskStore(clock: clock,
                              persistence: Persistence(directory: dir),
                              scheduler: scheduler,
                              undoWindow: 10)
        // Mutate; the save is scheduled but NOT yet on disk.
        let cs = store.add("survive", to: .today)
        let id = cs.inserted[0]
        XCTAssertTrue(store.hasPendingSave, "a scheduled-but-unfired save marks the store dirty")

        // A watcher-driven reload lands mid-typing. It must flush first, not clobber.
        let diff = store.reloadFromDisk()

        // The task survives in memory…
        XCTAssertNotNil(store.task(id: id))
        XCTAssertEqual(store.tasks(in: .today).count, 1)
        // …and on disk (a fresh reader sees it).
        let onDisk = Persistence(directory: dir).load().state
        XCTAssertEqual(onDisk?.tasks.first?.title, "survive")
        // And because we flushed then re-read our own bytes, the reload is a no-op.
        XCTAssertTrue(diff.isEmpty)
    }

    // FINDING 1(c) — a reload of identical on-disk state returns an empty ChangeSet
    // (neutralizes the benign self-triggered watcher event after our own save).
    func testReloadOfIdenticalStateReturnsEmptyChangeSet() {
        let store = TaskStore(clock: clock,
                              persistence: Persistence(directory: dir),
                              scheduler: ImmediateSaveScheduler(),
                              undoWindow: 10)
        store.add("a", to: .today) // immediate save → disk == memory
        XCTAssertFalse(store.hasPendingSave)
        let diff = store.reloadFromDisk()
        XCTAssertTrue(diff.isEmpty)
        XCTAssertEqual(store.tasks(in: .today).count, 1)
    }

    // FINDING 2 — a corruption→backup restore is re-persisted immediately, so the
    // store file exists again and a relaunch is NOT treated as first launch.
    func testRestoredBackupIsRePersistedAndSurvivesRelaunch() throws {
        let p = Persistence(directory: dir)
        let good = StoreState(lastProcessedDay: T.day(2026, 7, 20),
                              tasks: [OrdoTask(title: "from-backup", list: .today,
                                               createdAt: iso("2026-07-20T12:00:00Z"), order: 1)])
        try p.save(good, backupDay: nil)
        try FileManager.default.createDirectory(at: p.backupsDir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: p.storeURL,
                                         to: p.backupsDir.appendingPathComponent("store-2026-07-20.json"))
        // Corrupt the live store.
        try Data("this is not json".utf8).write(to: p.storeURL)

        let store = TaskStore(clock: clock,
                              persistence: Persistence(directory: dir),
                              scheduler: ImmediateSaveScheduler(),
                              undoWindow: 10)
        XCTAssertTrue(store.restoredFromBackup)
        XCTAssertFalse(store.isFirstLaunch)

        // store.json exists on disk immediately after init, with the restored content.
        XCTAssertTrue(FileManager.default.fileExists(atPath: Persistence(directory: dir).storeURL.path))
        let onDisk = Persistence(directory: dir).load().state
        XCTAssertEqual(onDisk?.tasks.first?.title, "from-backup")

        // Relaunch (simulating a crash right after restore): sees the restored task,
        // NOT an empty first-launch store.
        let relaunch = TaskStore(clock: clock,
                                 persistence: Persistence(directory: dir),
                                 scheduler: ImmediateSaveScheduler(),
                                 undoWindow: 10)
        XCTAssertFalse(relaunch.isFirstLaunch)
        XCTAssertEqual(relaunch.tasks(in: .today).first?.title, "from-backup")
    }
}
