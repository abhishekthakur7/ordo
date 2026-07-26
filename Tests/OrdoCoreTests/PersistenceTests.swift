import XCTest
@testable import OrdoCore

final class PersistenceTests: XCTestCase {
    var dir: URL!
    override func setUp() { super.setUp(); dir = T.tempDir() }
    override func tearDown() { T.cleanup(dir); super.tearDown() }

    private func iso(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: s)!
    }
    private func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]
        return e
    }
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    // PLAN §5: unknown-field JSON round-trip (task).
    func testUnknownFieldsOnTaskSurviveRoundTrip() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","title":"t","list":"today","done":false,
         "createdAt":"2026-07-26T12:00:00Z","order":1,
         "priority":5,"tags":["a","b"],"meta":{"nested":[1,2,3],"flag":true}}
        """
        let task = try decoder().decode(OrdoTask.self, from: Data(json.utf8))
        XCTAssertEqual(task.extra["priority"], .int(5))
        XCTAssertEqual(task.extra["tags"], .array([.string("a"), .string("b")]))
        XCTAssertEqual(task.extra["meta"],
                       .object(["nested": .array([.int(1), .int(2), .int(3)]), "flag": .bool(true)]))

        // Re-encode and decode again — extras and known fields are preserved.
        let data = try encoder().encode(task)
        let again = try decoder().decode(OrdoTask.self, from: data)
        XCTAssertEqual(again, task)
    }

    // PLAN §5: unknown-field JSON round-trip (store root).
    func testUnknownFieldsOnRootSurviveRoundTrip() throws {
        let json = """
        {"schemaVersion":1,"lastProcessedDay":"2026-07-26","dayStartOffset":0,
         "tasks":[],"syncMeta":{"cursor":"abc","rev":42},"experimentalFlag":true}
        """
        let state = try decoder().decode(StoreState.self, from: Data(json.utf8))
        XCTAssertEqual(state.extra["experimentalFlag"], .bool(true))
        XCTAssertEqual(state.extra["syncMeta"], .object(["cursor": .string("abc"), "rev": .int(42)]))

        let data = try encoder().encode(state)
        let again = try decoder().decode(StoreState.self, from: data)
        XCTAssertEqual(again, state)

        // And through the real Persistence save/load path.
        try Data(json.utf8).write(to: Persistence(directory: dir).storeURL)
        let loaded = Persistence(directory: dir).load().state
        XCTAssertEqual(loaded?.extra["experimentalFlag"], .bool(true))
    }

    func testStoreJSONIsStableAcrossReencodes() throws {
        let p = Persistence(directory: dir)
        let s = StoreState(lastProcessedDay: T.day(2026, 7, 26),
                           tasks: [OrdoTask(title: "a", list: .today,
                                            createdAt: iso("2026-07-26T12:00:00Z"), order: 1)])
        try p.save(s, backupDay: nil)
        let first = try Data(contentsOf: p.storeURL)
        try p.save(s, backupDay: nil)
        let second = try Data(contentsOf: p.storeURL)
        XCTAssertEqual(first, second) // deterministic, stable key order
    }

    // PLAN §5: corruption → quarantine + newest-parseable-backup restore + notice.
    func testCorruptStoreQuarantinedAndBackupRestored() throws {
        let p = Persistence(directory: dir)
        let good = StoreState(lastProcessedDay: T.day(2026, 7, 20),
                              tasks: [OrdoTask(title: "from-backup", list: .today,
                                               createdAt: iso("2026-07-20T12:00:00Z"), order: 1)])
        try p.save(good, backupDay: nil)
        // Stage a valid backup, then corrupt the live store.
        try FileManager.default.createDirectory(at: p.backupsDir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: p.storeURL,
                                         to: p.backupsDir.appendingPathComponent("store-2026-07-20.json"))
        try Data("this is not json".utf8).write(to: p.storeURL)

        let result = Persistence(directory: dir).load()
        XCTAssertTrue(result.corruptionNoticed)
        XCTAssertTrue(result.restoredFromBackup)
        XCTAssertEqual(result.state?.tasks.first?.title, "from-backup")
        // The bad file is quarantined.
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("store.corrupt-") })
    }

    func testCorruptStoreWithNoBackupStartsFreshWithNotice() throws {
        let p = Persistence(directory: dir)
        try Data("garbage".utf8).write(to: p.storeURL)
        let result = p.load()
        XCTAssertNil(result.state)              // fresh start
        XCTAssertTrue(result.corruptionNoticed) // but the user is told
    }

    // PLAN §5: atomic-write crash simulation — a fault before rename leaves the
    // previous store intact.
    func testAtomicWriteCrashLeavesPreviousStoreIntact() throws {
        let p = Persistence(directory: dir)
        let v1 = StoreState(lastProcessedDay: T.day(2026, 7, 26),
                            tasks: [OrdoTask(title: "v1", list: .today,
                                             createdAt: iso("2026-07-26T12:00:00Z"), order: 1)])
        try p.save(v1, backupDay: nil)

        p.faultBeforeRename = { throw PersistenceError.injectedFault }
        let v2 = StoreState(lastProcessedDay: T.day(2026, 7, 26),
                            tasks: [OrdoTask(title: "v2", list: .today,
                                             createdAt: iso("2026-07-26T12:00:00Z"), order: 1)])
        XCTAssertThrowsError(try p.save(v2, backupDay: nil))

        // store.json still holds v1 — the rename never happened.
        let loaded = Persistence(directory: dir).load().state
        XCTAssertEqual(loaded?.tasks.first?.title, "v1")
    }

    // PLAN §5: backup rotation keeps the last 7.
    func testBackupRotationKeepsSeven() throws {
        let p = Persistence(directory: dir)
        // Ten first-saves on ten different days.
        for i in 0..<10 {
            let day = T.day(2026, 7, 20).adding(i)
            let s = StoreState(lastProcessedDay: day, dayStartOffset: i, tasks: [])
            try p.save(s, backupDay: day)
        }
        let backups = try FileManager.default.contentsOfDirectory(atPath: p.backupsDir.path)
            .filter { $0.hasPrefix("store-") && $0.hasSuffix(".json") }
            .sorted()
        XCTAssertEqual(backups.count, 7)
        // Backups are named by the day of the first-save that snapshotted the prior
        // store (07-21…07-29 for saves 1…9); the newest 7 are kept.
        XCTAssertEqual(backups.first, "store-2026-07-23.json")
        XCTAssertEqual(backups.last, "store-2026-07-29.json")
    }

    func testSecondSaveSameDayDoesNotDuplicateBackup() throws {
        let p = Persistence(directory: dir)
        let day = T.day(2026, 7, 26)
        try p.save(StoreState(lastProcessedDay: day), backupDay: day) // creates store.json (no prior)
        try p.save(StoreState(lastProcessedDay: day), backupDay: day) // first backup today
        try p.save(StoreState(lastProcessedDay: day), backupDay: day) // no second backup today
        let backups = try FileManager.default.contentsOfDirectory(atPath: p.backupsDir.path)
            .filter { $0.hasPrefix("store-") }
        XCTAssertEqual(backups.count, 1)
    }

    // PLAN §5: pre-migration backup taken before a forward migration.
    func testPreMigrationBackupTaken() throws {
        let p = Persistence(directory: dir)
        // A legacy v0 store on disk.
        let legacy: [String: Any] = [
            "schemaVersion": 0,
            "lastProcessedDay": "2026-07-26",
            "dayStartOffset": 0,
            "tasks": [],
        ]
        try JSONSerialization.data(withJSONObject: legacy).write(to: p.storeURL)

        let result = p.load()
        XCTAssertEqual(result.migratedFrom, 0)
        XCTAssertEqual(result.state?.schemaVersion, ordoSchemaVersion)
        let backups = try FileManager.default.contentsOfDirectory(atPath: p.backupsDir.path)
        XCTAssertTrue(backups.contains { $0.hasPrefix("premigration-v0-") })
    }

    // PLAN §5 / §8: disk-full soft-fail keeps state in memory and retries.
    func testDiskFullSoftFailKeepsStateAndRetries() throws {
        let p = Persistence(directory: dir)
        let clock = FixedClock(year: 2026, month: 7, day: 26, timeZone: T.utc)
        let store = TaskStore(clock: clock, persistence: p, scheduler: ImmediateSaveScheduler())

        p.faultOnWrite = { throw PersistenceError.injectedFault } // "disk full"
        store.add("survives-in-memory", to: .today)
        XCTAssertTrue(store.hasPendingSave)
        XCTAssertEqual(store.tasks(in: .today).count, 1) // still present in memory

        p.faultOnWrite = nil // disk recovers
        store.flush()
        XCTAssertFalse(store.hasPendingSave)
        // A fresh store reads the persisted task.
        let reopened = TaskStore(clock: clock, persistence: Persistence(directory: dir),
                                 scheduler: ImmediateSaveScheduler())
        XCTAssertEqual(reopened.tasks(in: .today).first?.title, "survives-in-memory")
    }

    // ARCHITECTURE §5.3: external edit reload produces a diff and adopts the file.
    func testReloadFromDiskAdoptsExternalChangeWithDiff() throws {
        let clock = FixedClock(year: 2026, month: 7, day: 26, timeZone: T.utc)
        let store = TaskStore(clock: clock, persistence: Persistence(directory: dir),
                              scheduler: ImmediateSaveScheduler())
        let kept = store.add("kept", to: .today).inserted[0]
        let removed = store.add("removed", to: .today).inserted[0]

        // Simulate an external writer: keep `kept`, drop `removed`, add a new task.
        var external = store.snapshot
        external.tasks.removeAll { $0.id == removed }
        let newTask = OrdoTask(title: "external", list: .today,
                               createdAt: clock.now, addedToTodayOn: T.day(2026, 7, 26), order: 99)
        external.tasks.append(newTask)
        let p = Persistence(directory: dir)
        try p.save(external, backupDay: nil)

        let diff = store.reloadFromDisk()
        XCTAssertEqual(diff.inserted, [newTask.id])
        XCTAssertEqual(diff.removed, [removed])
        XCTAssertEqual(Set(store.tasks(in: .today).map { $0.id }), [kept, newTask.id])
    }
}
