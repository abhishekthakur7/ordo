// OrdoUI — UI preferences over UserDefaults (contract C5, ARCHITECTURE §6.4). Holds
// ONLY UI prefs (theme, appearance, sound, expanded, hotkey, launch-at-login); the
// semantic `dayStartOffset` lives in store.json (C5). Side effects are the shell's.

import Foundation
import Observation
import OrdoThemes

@MainActor
@Observable
public final class AppSettings {

    /// The UserDefaults keys, namespaced so they never collide with system prefs.
    public enum Key {
        public static let themeID = "ordo.themeID"
        public static let appearance = "ordo.appearance"
        public static let soundEnabled = "ordo.soundEnabled"
        public static let panelExpanded = "ordo.panelExpanded"
        public static let hotkey = "ordo.hotkey"
        public static let launchAtLoginConsented = "ordo.launchAtLogin.consented"
        public static let launchAtLoginEnabled = "ordo.launchAtLogin.enabled"
    }

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: Preferences

    /// Selected theme (default macOS per REQUIREMENTS).
    public var themeID: ThemeID {
        didSet { defaults.set(themeID.rawValue, forKey: Key.themeID) }
    }

    /// Appearance mode (default System).
    public var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Global sound on/off (default on).
    public var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }

    /// Whether the panel opens expanded — remembered across opens (§4.2).
    public var panelExpanded: Bool {
        didSet { defaults.set(panelExpanded, forKey: Key.panelExpanded) }
    }

    /// The summon hotkey binding (default ⌃⌥Space). The shell registers it.
    public var hotkey: HotkeyBinding {
        didSet { persistHotkey() }
    }

    /// Whether the user has been shown (and answered) the launch-at-login consent.
    public var launchAtLoginConsented: Bool {
        didSet { defaults.set(launchAtLoginConsented, forKey: Key.launchAtLoginConsented) }
    }

    /// Whether launch-at-login is enabled (default on, once consented). The shell
    /// maps this onto SMAppService.
    public var launchAtLoginEnabled: Bool {
        didSet { defaults.set(launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled) }
    }

    // MARK: Init

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.themeID = ThemeID(rawValue: defaults.string(forKey: Key.themeID) ?? "") ?? .macOS
        self.appearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        self.soundEnabled = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        self.panelExpanded = defaults.object(forKey: Key.panelExpanded) as? Bool ?? false

        if let data = defaults.data(forKey: Key.hotkey),
           let decoded = try? JSONDecoder().decode(HotkeyBinding.self, from: data) {
            self.hotkey = decoded
        } else {
            self.hotkey = .default
        }

        self.launchAtLoginConsented = defaults.bool(forKey: Key.launchAtLoginConsented)
        // Default enabled = true (on by default, ARCHITECTURE §6.4) until the user
        // says otherwise; the shell only acts once `consented` is true.
        self.launchAtLoginEnabled = defaults.object(forKey: Key.launchAtLoginEnabled) as? Bool ?? true
    }

    private func persistHotkey() {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Key.hotkey)
        }
    }
}
