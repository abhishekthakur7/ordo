// OrdoCore — the injectable clock (ARCHITECTURE §6.2, cross-module contract C6).
// Nothing reads wall-clock time directly; everything takes an `OrdoClock` so tests
// drive time and zone deterministically. Named `OrdoClock` to avoid stdlib `Clock`.

import Foundation

/// Supplies the current instant and time zone. Injected everywhere time matters.
public protocol OrdoClock: AnyObject {
    /// The current instant (UTC-agnostic `Date`).
    var now: Date { get }
    /// The zone used to resolve calendar dates. Re-read on each access so that a
    /// travelling user's day identity re-evaluates (ARCHITECTURE §3.1/§3.3).
    var timeZone: TimeZone { get }
}

/// Production clock: reads the real system time and the current local zone.
public final class SystemClock: OrdoClock {
    public init() {}
    public var now: Date { Date() }
    public var timeZone: TimeZone { TimeZone.current }
}

/// Test clock: both the instant and the zone are freely settable, so a test can
/// step across midnight, jump zones, or simulate a clock set backwards.
public final class FixedClock: OrdoClock {
    public var now: Date
    public var timeZone: TimeZone

    public init(now: Date, timeZone: TimeZone = TimeZone(identifier: "UTC")!) {
        self.now = now
        self.timeZone = timeZone
    }

    /// Convenience: set `now` from Y/M/D h:m:s in a given zone.
    public convenience init(year: Int, month: Int, day: Int,
                            hour: Int = 12, minute: Int = 0, second: Int = 0,
                            timeZone: TimeZone = TimeZone(identifier: "UTC")!) {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = second
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        self.init(now: cal.date(from: comps)!, timeZone: timeZone)
    }

    /// Advance the clock by a number of seconds.
    public func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }

    /// Set the clock to a specific wall-clock moment in the current `timeZone`.
    public func set(year: Int, month: Int, day: Int,
                    hour: Int = 12, minute: Int = 0, second: Int = 0) {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = second
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        now = cal.date(from: comps)!
    }
}
