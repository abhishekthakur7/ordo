// OrdoCore — persistence (ARCHITECTURE §5). Owns all disk I/O: atomic writes,
// daily backup rotation, append-only monthly history, corruption quarantine +
// restore, forward-only migration, external-edit watcher. Directory injectable.

import Foundation

/// Errors surfaced by the persistence layer. `writeFailed` is treated as a soft
/// failure by `TaskStore` (disk-full → keep state in memory, retry later).
public enum PersistenceError: Error, Equatable {
    case writeFailed(Int32)
    case directoryUnavailable
    case injectedFault
}

/// The outcome of loading `store.json`.
public struct LoadResult: Sendable {
    /// Decoded state, or nil for a first launch (or unrecoverable corruption with
    /// no parseable backup — a fresh store is then created by `TaskStore`).
    public var state: StoreState?
    /// True when the live file was corrupt and a backup was restored.
    public var restoredFromBackup: Bool
    /// The old schema version if a migration ran, else nil.
    public var migratedFrom: Int?
    /// True when corruption was detected (drives the calm one-time UI notice).
    public var corruptionNoticed: Bool

    public init(state: StoreState?, restoredFromBackup: Bool = false,
                migratedFrom: Int? = nil, corruptionNoticed: Bool = false) {
        self.state = state
        self.restoredFromBackup = restoredFromBackup
        self.migratedFrom = migratedFrom
        self.corruptionNoticed = corruptionNoticed
    }
}

/// Reads and writes the on-disk Ordo store.
public final class Persistence {
    public let directory: URL

    /// Default storage location: ~/Library/Application Support/Ordo/.
    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        return base.appendingPathComponent("Ordo", isDirectory: true)
    }

    // Test seams (used via @testable import): inject write faults to exercise the
    // disk-full and crash-mid-save paths without a real failing disk.
    var faultOnWrite: (() throws -> Void)?
    var faultBeforeRename: (() throws -> Void)?

    private let fm = FileManager.default
    private var watchSource: DispatchSourceFileSystemObject?
    private var watchDescriptor: Int32 = -1
    private let watchQueue = DispatchQueue(label: "ordo.persistence.watch")

    public init(directory: URL = Persistence.defaultDirectory) {
        self.directory = directory
    }

    // MARK: Paths

    public var storeURL: URL { directory.appendingPathComponent("store.json") }
    var historyDir: URL { directory.appendingPathComponent("history", isDirectory: true) }
    var backupsDir: URL { directory.appendingPathComponent("backups", isDirectory: true) }

    // MARK: Codecs

    private static func makeEncoder(pretty: Bool) -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                                    : [.sortedKeys, .withoutEscapingSlashes]
        return e
    }
    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
    private let prettyEncoder = Persistence.makeEncoder(pretty: true)
    private let lineEncoder = Persistence.makeEncoder(pretty: false)
    private let decoder = Persistence.makeDecoder()

    // MARK: Load

    /// Loads `store.json`, handling corruption and migration (ARCHITECTURE §5.2).
    public func load() -> LoadResult {
        guard fm.fileExists(atPath: storeURL.path) else {
            return LoadResult(state: nil) // first launch
        }
        guard let data = try? Data(contentsOf: storeURL) else {
            return LoadResult(state: nil, corruptionNoticed: true)
        }
        if let state = try? decoder.decode(StoreState.self, from: data) {
            return applyMigrationIfNeeded(state, rawData: data)
        }
        // Corrupt: quarantine, then restore the newest parseable backup.
        quarantine(data: data)
        if let (backupState, backupData) = newestParseableBackup() {
            var result = applyMigrationIfNeeded(backupState, rawData: backupData)
            result.restoredFromBackup = true
            result.corruptionNoticed = true
            return result
        }
        return LoadResult(state: nil, corruptionNoticed: true)
    }

    private func applyMigrationIfNeeded(_ state: StoreState, rawData: Data) -> LoadResult {
        guard state.schemaVersion < ordoSchemaVersion else {
            return LoadResult(state: state)
        }
        // Pre-migration backup of the exact bytes (ARCHITECTURE §5.2).
        writePreMigrationBackup(rawData, fromVersion: state.schemaVersion)
        let migrated = migrate(state, from: state.schemaVersion)
        return LoadResult(state: migrated, migratedFrom: state.schemaVersion)
    }

    /// Forward-only migration scaffold. No pre-v1 schemas ship, so this only
    /// stamps the current version; future versions add real steps here.
    private func migrate(_ state: StoreState, from old: Int) -> StoreState {
        var s = state
        s.schemaVersion = ordoSchemaVersion
        return s
    }

    private func quarantine(data: Data) {
        let ts = Int(Date().timeIntervalSince1970)
        let dest = directory.appendingPathComponent("store.corrupt-\(ts).json")
        try? data.write(to: dest)
        try? fm.removeItem(at: storeURL)
    }

    private func newestParseableBackup() -> (StoreState, Data)? {
        guard let files = try? fm.contentsOfDirectory(at: backupsDir,
                                                      includingPropertiesForKeys: nil) else {
            return nil
        }
        let candidates = files
            .filter { $0.lastPathComponent.hasPrefix("store-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } // newest date first
        for url in candidates {
            if let d = try? Data(contentsOf: url),
               let s = try? decoder.decode(StoreState.self, from: d) {
                return (s, d)
            }
        }
        return nil
    }

    // MARK: Save

    /// Atomically writes `state` (ARCHITECTURE §5.2). Performs daily backup
    /// rotation when `backupDay` is the first save of that day. Throws
    /// `PersistenceError.writeFailed` on disk failure — caller soft-fails.
    public func save(_ state: StoreState, backupDay: DayKey?) throws {
        try ensureDirectory(directory)
        cleanStrayTemps()

        // Backup rotation: first save of the day copies the current good store,
        // before it is overwritten (ARCHITECTURE §5.2).
        if let day = backupDay { rotateBackupIfNeeded(for: day) }

        let data = try prettyEncoder.encode(state)
        try faultOnWrite?()

        let tmp = directory.appendingPathComponent("store.json.tmp-\(UUID().uuidString)")
        do {
            try data.write(to: tmp)
        } catch {
            throw PersistenceError.writeFailed(errno)
        }
        try faultBeforeRename?()

        // Atomic replace via rename(2): replaces the destination even if present.
        let ok = tmp.withUnsafeFileSystemRepresentation { tmpPath -> Bool in
            storeURL.withUnsafeFileSystemRepresentation { storePath -> Bool in
                guard let tmpPath, let storePath else { return false }
                return rename(tmpPath, storePath) == 0
            }
        }
        guard ok else {
            let e = errno
            try? fm.removeItem(at: tmp)
            throw PersistenceError.writeFailed(e)
        }
    }

    private func rotateBackupIfNeeded(for day: DayKey) {
        guard fm.fileExists(atPath: storeURL.path) else { return }
        try? ensureDirectory(backupsDir)
        let backup = backupsDir.appendingPathComponent("store-\(day).json")
        guard !fm.fileExists(atPath: backup.path) else { return } // already backed up today
        try? fm.copyItem(at: storeURL, to: backup)
        trimBackups()
    }

    /// Keeps only the newest 7 daily backups (ARCHITECTURE §5.2).
    private func trimBackups() {
        guard let files = try? fm.contentsOfDirectory(at: backupsDir,
                                                      includingPropertiesForKeys: nil) else { return }
        let daily = files
            .filter { $0.lastPathComponent.hasPrefix("store-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } // newest first
        for url in daily.dropFirst(7) { try? fm.removeItem(at: url) }
    }

    private func writePreMigrationBackup(_ data: Data, fromVersion: Int) {
        try? ensureDirectory(backupsDir)
        let ts = Int(Date().timeIntervalSince1970)
        let dest = backupsDir.appendingPathComponent("premigration-v\(fromVersion)-\(ts).json")
        try? data.write(to: dest)
    }

    private func cleanStrayTemps() {
        guard let files = try? fm.contentsOfDirectory(at: directory,
                                                      includingPropertiesForKeys: nil) else { return }
        for url in files where url.lastPathComponent.hasPrefix("store.json.tmp-") {
            try? fm.removeItem(at: url)
        }
    }

    private func ensureDirectory(_ url: URL) throws {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue { return }
        }
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw PersistenceError.directoryUnavailable
        }
    }

    // MARK: History (append-only)

    /// Appends records to their monthly `history/YYYY-MM.jsonl` files. Never
    /// rewrites existing history (ARCHITECTURE §5.1).
    public func appendHistory(_ records: [HistoryRecord]) throws {
        guard !records.isEmpty else { return }
        try ensureDirectory(historyDir)
        let byMonth = Dictionary(grouping: records, by: { $0.monthKey })
        for (month, recs) in byMonth {
            let url = historyDir.appendingPathComponent("\(month).jsonl")
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            for r in recs {
                var line = try lineEncoder.encode(r)
                line.append(0x0A) // newline
                try handle.write(contentsOf: line)
            }
        }
    }

    /// Reads every day summary from history, oldest month first.
    public func loadSummaries() -> [DaySummary] {
        readHistory().compactMap { if case .summary(let s) = $0 { return s } else { return nil } }
    }

    /// Number of distinct archived tasks across all history. Deduped by task id so
    /// a rare crash-retry duplicate line (history is appended before the store
    /// advances) cannot inflate the lifetime count.
    public func archivedTaskCount() -> Int {
        var ids = Set<UUID>()
        for case .task(let t) in readHistory() { ids.insert(t.task.id) }
        return ids.count
    }

    /// All history records across every month file, oldest month first. Corrupt
    /// lines are skipped. Internal — used by stats and by tests.
    func readHistory() -> [HistoryRecord] {
        guard let files = try? fm.contentsOfDirectory(at: historyDir,
                                                      includingPropertiesForKeys: nil) else { return [] }
        let jsonl = files.filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var out: [HistoryRecord] = []
        for url in jsonl {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let d = line.data(using: .utf8) else { continue }
                if let r = try? decoder.decode(HistoryRecord.self, from: d) {
                    out.append(r) // corrupt lines are skipped — one bad line ≠ lost month
                }
            }
        }
        return out
    }

    // MARK: External-edit file watcher (ARCHITECTURE §5.3)

    /// Watches `store.json` for external writes and calls `onChange` (on a
    /// background queue) so `TaskStore` can reload. Re-arms across atomic renames.
    public func startWatching(onChange: @escaping @Sendable () -> Void) {
        stopWatching()
        guard fm.fileExists(atPath: storeURL.path) else { return }
        let fd = open(storeURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        watchDescriptor = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: watchQueue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.watchSource?.data ?? []
            onChange()
            // On rename/delete the fd is stale; re-arm against the new file.
            if flags.contains(.rename) || flags.contains(.delete) {
                self.watchQueue.asyncAfter(deadline: .now() + 0.05) {
                    self.startWatching(onChange: onChange)
                }
            }
        }
        source.setCancelHandler { [fd] in close(fd) }
        watchSource = source
        source.resume()
    }

    public func stopWatching() {
        watchSource?.cancel()
        watchSource = nil
        watchDescriptor = -1
    }

    deinit { watchSource?.cancel() }
}
