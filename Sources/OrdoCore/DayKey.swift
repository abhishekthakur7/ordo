// OrdoCore — DayKey: a timezone-free logical calendar day like "2026-07-26"
// (ARCHITECTURE §2.1, §3.1). Names a date, not an instant; only does pure
// calendar-date arithmetic (age, adding days), DST-free (no 24-hour math).

import Foundation

/// A logical calendar day, e.g. `2026-07-26`. Codable as an ISO date string.
public struct DayKey: Hashable, Comparable, Sendable, CustomStringConvertible, Codable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// A fixed UTC Gregorian calendar used for DayKey↔date arithmetic. Using UTC
    /// (never the local zone) is what makes age math and `adding(_:)` immune to
    /// DST — a DayKey is a date, not a wall-clock span.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Builds a DayKey from the calendar-date components of `date` in `calendar`.
    init(from date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Noon UTC on this calendar date — a stable anchor for day arithmetic.
    func utcDate() -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return DayKey.calendar.date(from: c)!
    }

    /// Returns the DayKey `days` days after (or before, if negative) this one.
    public func adding(_ days: Int) -> DayKey {
        let d = DayKey.calendar.date(byAdding: .day, value: days, to: utcDate())!
        return DayKey(from: d, calendar: DayKey.calendar)
    }

    /// Number of whole days from `earlier` to `self` (negative if `self` is
    /// earlier). Used for task age = currentDay − addedToTodayOn.
    public func days(since earlier: DayKey) -> Int {
        DayKey.calendar.dateComponents([.day], from: earlier.utcDate(), to: utcDate()).day!
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// `YYYY-MM`, used to name monthly history files.
    public var monthKey: String {
        String(format: "%04d-%02d", year, month)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    // MARK: Codable (ISO date string)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = DayKey(string: raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Invalid DayKey string: \(raw)"))
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }

    /// Parses a `YYYY-MM-DD` string. Returns nil if malformed.
    public init?(string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        self.init(year: y, month: m, day: d)
    }
}
