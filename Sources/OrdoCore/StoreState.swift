// OrdoCore — the persisted live state: the root object of store.json.
// ARCHITECTURE §5.1: schemaVersion, lastProcessedDay, dayStartOffset, tasks[].
// Root-level unknown fields are preserved on rewrite (§2.1 / §5.2).

import Foundation

/// The current on-disk schema version. Forward-only migrations run on load.
public let ordoSchemaVersion = 1

/// The complete live state serialized to `store.json`.
public struct StoreState: Equatable, Sendable, Codable {
    /// Integer schema version for forward-only migration (ARCHITECTURE §5.2).
    public var schemaVersion: Int
    /// The last logical day the rollover engine has fully processed (§3.2).
    public var lastProcessedDay: DayKey
    /// Semantic setting: seconds after midnight that a logical day begins
    /// (default 0). Lives here — not UserDefaults — so CLI/MCP agents see it
    /// (ARCHITECTURE §3.1 / §5.1, PLAN.md C5).
    public var dayStartOffset: Int
    /// Live tasks (both lists; may include soft-delete tombstones pending purge).
    public var tasks: [OrdoTask]
    /// Root-level unknown JSON fields, preserved across rewrites.
    public var extra: [String: JSONValue]

    public init(schemaVersion: Int = ordoSchemaVersion,
                lastProcessedDay: DayKey,
                dayStartOffset: Int = 0,
                tasks: [OrdoTask] = [],
                extra: [String: JSONValue] = [:]) {
        self.schemaVersion = schemaVersion
        self.lastProcessedDay = lastProcessedDay
        self.dayStartOffset = dayStartOffset
        self.tasks = tasks
        self.extra = extra
    }

    // MARK: Codable with root unknown-field preservation

    private static let knownKeys: Set<String> = [
        "schemaVersion", "lastProcessedDay", "dayStartOffset", "tasks",
    ]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: AnyCodingKey("schemaVersion")) ?? 0
        lastProcessedDay = try c.decode(DayKey.self, forKey: AnyCodingKey("lastProcessedDay"))
        dayStartOffset = try c.decodeIfPresent(Int.self, forKey: AnyCodingKey("dayStartOffset")) ?? 0
        tasks = try c.decodeIfPresent([OrdoTask].self, forKey: AnyCodingKey("tasks")) ?? []
        extra = try c.decodeExtra(excluding: StoreState.knownKeys)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(schemaVersion, forKey: AnyCodingKey("schemaVersion"))
        try c.encode(lastProcessedDay, forKey: AnyCodingKey("lastProcessedDay"))
        try c.encode(dayStartOffset, forKey: AnyCodingKey("dayStartOffset"))
        try c.encode(tasks, forKey: AnyCodingKey("tasks"))
        try c.encodeExtra(extra)
    }
}
