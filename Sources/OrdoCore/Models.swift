// OrdoCore — domain models (ARCHITECTURE §2.1, §3.2, §3.5).

import Foundation

/// The two task lists. Raw values are the on-disk representation; theme-facing
/// display strings (e.g. macOS theme calling Long-term "Horizon") live in
/// OrdoThemes, never here.
public enum TaskList: String, Codable, Hashable, Sendable, CaseIterable {
    case today
    case longterm
}

/// A single task. Named `OrdoTask` (not `Task`) to avoid colliding with Swift
/// Concurrency's `Task`. Unknown JSON fields survive a decode→encode round-trip
/// via `extra` (ARCHITECTURE §2.1).
public struct OrdoTask: Hashable, Sendable, Identifiable, Codable {
    /// Stable identity, preserved across promote/demote.
    public var id: UUID
    /// 1…500 chars, trimmed, non-empty. Enforce via `sanitizedTitle`.
    public var title: String
    public var list: TaskList
    public var done: Bool
    public var pinned: Bool
    /// The instant the task was created (UTC).
    public var createdAt: Date
    /// The logical day the task entered the Today list; nil for long-term tasks.
    /// Age is derived (`currentDay − addedToTodayOn`) and never stored.
    public var addedToTodayOn: DayKey?
    /// The instant the task was completed; nil while open.
    public var completedAt: Date?
    /// Fractional index within its list (ARCHITECTURE §3.5).
    public var order: Double
    /// Reserved for V2 external-item provenance ("jira:PROJ-123"); nil in V1.
    public var origin: String?

    /// The logical day the user last chose "Keep" in triage. Snoozes the triage
    /// nudge for 7 more days WITHOUT resetting age (ARCHITECTURE §3.5). nil = the
    /// user has never pressed Keep on this task.
    public var triageKeptOn: DayKey?

    /// Soft-delete tombstone: the instant the task was deleted. While non-nil the
    /// task is hidden from queries; it is purged at the first save after the undo
    /// window closes (ARCHITECTURE §2.2). nil = live.
    public var deletedAt: Date?

    /// Unknown JSON fields captured on decode and re-emitted on encode.
    public var extra: [String: JSONValue]

    public init(id: UUID = UUID(),
                title: String,
                list: TaskList,
                done: Bool = false,
                pinned: Bool = false,
                createdAt: Date,
                addedToTodayOn: DayKey? = nil,
                completedAt: Date? = nil,
                order: Double,
                origin: String? = nil,
                triageKeptOn: DayKey? = nil,
                deletedAt: Date? = nil,
                extra: [String: JSONValue] = [:]) {
        self.id = id
        self.title = title
        self.list = list
        self.done = done
        self.pinned = pinned
        self.createdAt = createdAt
        self.addedToTodayOn = addedToTodayOn
        self.completedAt = completedAt
        self.order = order
        self.origin = origin
        self.triageKeptOn = triageKeptOn
        self.deletedAt = deletedAt
        self.extra = extra
    }

    // MARK: Codable with unknown-field preservation

    private static let knownKeys: Set<String> = [
        "id", "title", "list", "done", "pinned", "createdAt", "addedToTodayOn",
        "completedAt", "order", "origin", "triageKeptOn", "deletedAt",
    ]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        id = try c.decode(UUID.self, forKey: AnyCodingKey("id"))
        title = try c.decode(String.self, forKey: AnyCodingKey("title"))
        list = try c.decode(TaskList.self, forKey: AnyCodingKey("list"))
        done = try c.decodeIfPresent(Bool.self, forKey: AnyCodingKey("done")) ?? false
        pinned = try c.decodeIfPresent(Bool.self, forKey: AnyCodingKey("pinned")) ?? false
        createdAt = try c.decode(Date.self, forKey: AnyCodingKey("createdAt"))
        addedToTodayOn = try c.decodeIfPresent(DayKey.self, forKey: AnyCodingKey("addedToTodayOn"))
        completedAt = try c.decodeIfPresent(Date.self, forKey: AnyCodingKey("completedAt"))
        order = try c.decodeIfPresent(Double.self, forKey: AnyCodingKey("order")) ?? 0
        origin = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("origin"))
        triageKeptOn = try c.decodeIfPresent(DayKey.self, forKey: AnyCodingKey("triageKeptOn"))
        deletedAt = try c.decodeIfPresent(Date.self, forKey: AnyCodingKey("deletedAt"))
        extra = try c.decodeExtra(excluding: OrdoTask.knownKeys)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(id, forKey: AnyCodingKey("id"))
        try c.encode(title, forKey: AnyCodingKey("title"))
        try c.encode(list, forKey: AnyCodingKey("list"))
        try c.encode(done, forKey: AnyCodingKey("done"))
        try c.encode(pinned, forKey: AnyCodingKey("pinned"))
        try c.encode(createdAt, forKey: AnyCodingKey("createdAt"))
        try c.encodeIfPresent(addedToTodayOn, forKey: AnyCodingKey("addedToTodayOn"))
        try c.encodeIfPresent(completedAt, forKey: AnyCodingKey("completedAt"))
        try c.encode(order, forKey: AnyCodingKey("order"))
        try c.encodeIfPresent(origin, forKey: AnyCodingKey("origin"))
        try c.encodeIfPresent(triageKeptOn, forKey: AnyCodingKey("triageKeptOn"))
        try c.encodeIfPresent(deletedAt, forKey: AnyCodingKey("deletedAt"))
        // Extras never shadow known keys (unknown = not in knownKeys by construction).
        try c.encodeExtra(extra)
    }

    /// True while the task is a soft-delete tombstone.
    public var isDeleted: Bool { deletedAt != nil }
}

/// Sanitizes a candidate title: trims whitespace/newlines and caps at 500
/// characters. Returns nil if empty after trimming (ARCHITECTURE §2.1, §4.1).
public func sanitizedTitle(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.count > 500 { return String(trimmed.prefix(500)) }
    return trimmed
}

/// A per-day summary written to history at rollover (ARCHITECTURE §3.2, §7).
/// Feeds streaks and stats; never used as live truth.
public struct DaySummary: Hashable, Sendable, Codable {
    /// The logical day this summarizes.
    public let day: DayKey
    /// Number of Today tasks completed on `day`.
    public let completed: Int
    /// Number of Today tasks that existed on `day` and were still open at its end.
    public let stillOpen: Int
    /// True iff ≥1 Today task existed and all were completed (a "cleared" day, §7).
    public let fullyCleared: Bool

    public init(day: DayKey, completed: Int, stillOpen: Int, fullyCleared: Bool) {
        self.day = day
        self.completed = completed
        self.stillOpen = stillOpen
        self.fullyCleared = fullyCleared
    }
}

/// A task archived into history under its true completion day (ARCHITECTURE §3.2).
public struct ArchivedTask: Hashable, Sendable, Codable {
    /// The full task snapshot at archival (done == true).
    public let task: OrdoTask
    /// The task's true completion day (`dayKey(completedAt)`), which decides the
    /// month file it lands in — not the day the rollover happened to run.
    public let archivedDay: DayKey

    public init(task: OrdoTask, archivedDay: DayKey) {
        self.task = task
        self.archivedDay = archivedDay
    }
}

/// One line of a monthly `history/YYYY-MM.jsonl` file: either an archived task or
/// a day summary. Append-only; never rewritten (ARCHITECTURE §5.1).
public enum HistoryRecord: Hashable, Sendable, Codable {
    case task(ArchivedTask)
    case summary(DaySummary)

    private enum CodingKeys: String, CodingKey { case type }
    private enum Kind: String, Codable { case task, summary }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .task: self = .task(try ArchivedTask(from: decoder))
        case .summary: self = .summary(try DaySummary(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let t):
            try c.encode(Kind.task, forKey: .type)
            try t.encode(to: encoder)
        case .summary(let s):
            try c.encode(Kind.summary, forKey: .type)
            try s.encode(to: encoder)
        }
    }

    /// The `YYYY-MM` month file this record belongs to.
    var monthKey: String {
        switch self {
        case .task(let t): return t.archivedDay.monthKey
        case .summary(let s): return s.day.monthKey
        }
    }
}
