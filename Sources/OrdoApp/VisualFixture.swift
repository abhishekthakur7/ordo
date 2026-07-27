// OrdoApp — deterministic, isolated launch fixtures for visual parity captures.
//
// Set ORDO_VISUAL_FIXTURE to one of the scenes below. Fixture mode is deliberately
// available in both DEBUG and release builds when explicitly requested: it is a
// capture aid, not a user-facing feature. It always uses an isolated temp store and
// UserDefaults suite, so it never reads or writes the normal Application Support
// store or the user's preferences.

import Foundation
import OrdoCore
import OrdoThemes
import OrdoUI

@MainActor
struct VisualFixture {

    enum Scene: String, CaseIterable {
        case populated
        case oneCompleted = "one-completed"
        case allCleared = "all-cleared"
        case peeked
        case firstRun = "first-run"
        case agedTriage = "aged-triage"
        case settings
        case undo
        case completionMid = "completion-mid"
        /// Explicit reset is an alias for the clean first-run fixture.
        case reset

        var seededScene: Scene { self == .reset ? .firstRun : self }
    }

    /// A fixed UTC instant makes ages, greetings, completed dates, and persisted
    /// JSON independent of the host machine's date, locale, and time zone.
    let clock = FixedClock(year: 2026, month: 7, day: 27, hour: 10,
                           timeZone: TimeZone(identifier: "UTC")!)
    let scene: Scene
    let directory: URL
    let defaultsSuiteName: String
    let appearance: AppAppearance
    let expanded: Bool
    let themeID: ThemeID
    let settleAnimations: Bool

    /// `peeked` is intentionally carried as a typed launch request until Phase 5
    /// introduces AppModel.clearedPeek. At that point AppController can consume it
    /// after `panelWillOpen()` without changing the fixture file format.
    var requestsClearedPeek: Bool { scene == .peeked }

    private static let fixturePrefix = "ordo-visual-fixture-"

    static func activate(environment: [String: String] = ProcessInfo.processInfo.environment) -> VisualFixture? {
        guard let rawScene = environment["ORDO_VISUAL_FIXTURE"], !rawScene.isEmpty else {
            return nil
        }

        let normalized = rawScene.lowercased().replacingOccurrences(of: "_", with: "-")
        let scene: Scene
        if normalized == "help" || normalized == "--help" {
            write("usage ORDO_VISUAL_FIXTURE=<\(Scene.allCases.map(\.rawValue).joined(separator: "|"))>; using first-run")
            scene = .firstRun
        } else if let parsed = Scene(rawValue: normalized) {
            scene = parsed
        } else {
            write("unknown scene '\(rawScene)'; using first-run. Available: \(Scene.allCases.map(\.rawValue).joined(separator: ", "))")
            scene = .firstRun
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fixturePrefix)\(pid)", isDirectory: true)
        let suite = "com.ordo.visual-fixture.\(pid)"
        let appearance = AppAppearance(rawValue: environment["ORDO_VISUAL_APPEARANCE"]?.lowercased() ?? "") ?? .light
        let expanded = environment["ORDO_VISUAL_EXPANDED"] == "1"
        let requestedTheme = ThemeID(rawValue: environment["ORDO_VISUAL_THEME"]?.lowercased() ?? "") ?? .macOS
        let themeID: ThemeID
        // Zen remains intentionally absent from the user-facing registry until
        // Phase 6, but fixture captures must be able to exercise its Phase 3
        // chrome before then. AppController resolves this one capture-only case
        // directly without making it selectable in Settings.
        if requestedTheme == .zenInk || ThemeRegistry.shared.theme(id: requestedTheme) != nil {
            themeID = requestedTheme
        } else {
            write("theme '\(requestedTheme.rawValue)' is not registered; using macos")
            themeID = .macOS
        }

        // A fixture may never retain state between launches. RESET=1 makes that
        // intent explicit for scripts; RESET=0 is rejected because retaining a
        // previous capture's state would make screenshots non-deterministic.
        if let reset = environment["ORDO_VISUAL_FIXTURE_RESET"], reset != "1" {
            write("ORDO_VISUAL_FIXTURE_RESET=\(reset) ignored; fixtures always reset before launch")
        }

        let fixture = VisualFixture(
            scene: scene.seededScene,
            directory: directory,
            defaultsSuiteName: suite,
            appearance: appearance,
            expanded: expanded,
            themeID: themeID,
            settleAnimations: environment["ORDO_VISUAL_FIXTURE_MOTION"] != "1"
        )
        fixture.resetAndSeed()
        write("scene=\(fixture.scene.rawValue) store=\(fixture.directory.path) appearance=\(fixture.appearance.rawValue) expanded=\(fixture.expanded)")
        return fixture
    }

    func makeSettings() -> AppSettings {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults.set(themeID.rawValue, forKey: AppSettings.Key.themeID)
        defaults.set(appearance.rawValue, forKey: AppSettings.Key.appearance)
        defaults.set(false, forKey: AppSettings.Key.soundEnabled)
        defaults.set(expanded, forKey: AppSettings.Key.panelExpanded)
        // Suppress the real first-run login-item question while still rendering
        // the model's first-run empty state.
        defaults.set(true, forKey: AppSettings.Key.launchAtLoginConsented)
        defaults.set(false, forKey: AppSettings.Key.launchAtLoginEnabled)
        return AppSettings(defaults: defaults)
    }

    private func resetAndSeed() {
        let fm = FileManager.default
        // The target is an exact, PID-scoped child of NSTemporaryDirectory; never
        // derive this from user input or persistence's Application Support path.
        guard directory.lastPathComponent.hasPrefix(Self.fixturePrefix) else {
            Self.write("refusing to reset unexpected fixture path \(directory.path)")
            return
        }
        do {
            if fm.fileExists(atPath: directory.path) {
                try fm.removeItem(at: directory)
            }
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Self.write("could not reset fixture store \(directory.path): \(error)")
            return
        }

        guard let state = seedState else { return }
        do {
            try Persistence(directory: directory).save(state, backupDay: state.lastProcessedDay)
        } catch {
            // Keep using the isolated directory. TaskStore will materialize a clean
            // first-run state there instead of ever falling back to user storage.
            Self.write("could not seed fixture store: \(error)")
        }
    }

    private var seedState: StoreState? {
        let day = DayKey(year: 2026, month: 7, day: 27)
        let created = clock.now.addingTimeInterval(-3_600)
        switch scene {
        case .firstRun, .reset:
            return nil
        case .populated, .settings, .undo, .completionMid:
            return StoreState(lastProcessedDay: day, tasks: populatedTasks(created: created, day: day, includesCompleted: false))
        case .oneCompleted:
            return StoreState(lastProcessedDay: day, tasks: populatedTasks(created: created, day: day, includesCompleted: true))
        case .allCleared, .peeked:
            return StoreState(lastProcessedDay: day, tasks: [
                task(1, "Review the visual parity notes", list: .today, done: true, created: created, day: day, order: 1),
                task(2, "Polish the task mark", list: .today, done: true, created: created, day: day, order: 2),
                task(3, "Send the capture set", list: .today, done: true, created: created, day: day, order: 3),
            ])
        case .agedTriage:
            return StoreState(lastProcessedDay: day, tasks: [
                task(1, "Decide whether this still matters", list: .today, created: created.addingTimeInterval(-9 * 86_400), day: day.adding(-9), order: 1),
                task(2, "Capture the settled panel", list: .today, created: created, day: day, order: 2),
                task(3, "Keep a calm backlog", list: .longterm, created: created, day: nil, order: 1),
            ])
        }
    }

    private func populatedTasks(created: Date, day: DayKey, includesCompleted: Bool) -> [OrdoTask] {
        [
            task(1, "Review the visual parity notes", list: .today, created: created, day: day, order: 1),
            task(2, "Polish the task mark", list: .today, created: created, day: day, order: 2),
            task(3, "Send the capture set", list: .today, done: includesCompleted, created: created, day: day, order: 3),
            task(4, "Plan next week's quiet work", list: .longterm, created: created, day: nil, order: 1),
        ]
    }

    private func task(_ ordinal: UInt8, _ title: String, list: TaskList,
                      done: Bool = false, created: Date, day: DayKey?, order: Double) -> OrdoTask {
        // Stable UUIDs make SwiftUI identity, ordering, and any fixture diagnostics
        // repeatable. Completion is deliberately the same injected instant.
        let id = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ordinal))
        return OrdoTask(id: id, title: title, list: list, done: done,
                        createdAt: created, addedToTodayOn: day,
                        completedAt: done ? clock.now : nil, order: order)
    }

    static func write(_ message: String) {
        FileHandle.standardError.write(Data("OrdoApp visual fixture: \(message)\n".utf8))
    }
}
