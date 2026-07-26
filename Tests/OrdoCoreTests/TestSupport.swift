import XCTest
import Foundation
@testable import OrdoCore

/// Shared helpers for OrdoCore tests: temp directories, clocks, and a store
/// wired for deterministic (synchronous, no-sleep) persistence.
enum T {
    static let utc = TimeZone(identifier: "UTC")!
    static let ny = TimeZone(identifier: "America/New_York")!
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    static let honolulu = TimeZone(identifier: "Pacific/Honolulu")!

    /// A fresh, unique temp directory (auto-registered for cleanup via `cleanup`).
    static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ordo-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey {
        DayKey(year: y, month: m, day: d)
    }
}

/// A test case base that manages a temp dir + a FixedClock and builds stores.
class CoreTestCase: XCTestCase {
    var dir: URL!
    var clock: FixedClock!

    override func setUp() {
        super.setUp()
        dir = T.tempDir()
        clock = FixedClock(year: 2026, month: 7, day: 26, hour: 12, timeZone: T.utc)
    }

    override func tearDown() {
        if let dir { T.cleanup(dir) }
        super.tearDown()
    }

    /// A store using immediate (synchronous) saves so disk is always current.
    func makeStore(undoWindow: TimeInterval = 10) -> TaskStore {
        TaskStore(clock: clock,
                  persistence: Persistence(directory: dir),
                  scheduler: ImmediateSaveScheduler(),
                  undoWindow: undoWindow)
    }
}
