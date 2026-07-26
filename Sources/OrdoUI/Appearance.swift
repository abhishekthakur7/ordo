// OrdoUI — appearance resolution (ARCHITECTURE §6.3). Pure function: the user's
// setting (System/Light/Dark) plus the live system appearance resolve to a concrete
// light/dark value the root view forces onto `.colorScheme` for themes to self-resolve.

import SwiftUI
import OrdoThemes

/// The appearance setting the user picks (ARCHITECTURE §6.4, default `.system`).
public enum AppAppearance: String, Codable, CaseIterable, Sendable, Hashable {
    case system
    case light
    case dark
}

/// The concrete appearance a palette is rendered for, after resolution.
public enum ResolvedUIAppearance: Sendable, Hashable {
    case light
    case dark

    /// The SwiftUI color scheme to force on the root environment.
    public var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }

    /// The OrdoThemes resolution the theme understands.
    public var themeAppearance: ResolvedAppearance {
        self == .dark ? .dark : .light
    }
}

/// Pure appearance resolution. `systemIsDark` comes from the shell
/// (`NSApp.effectiveAppearance`); tests drive it directly.
public func resolveAppearance(_ setting: AppAppearance, systemIsDark: Bool) -> ResolvedUIAppearance {
    switch setting {
    case .system: return systemIsDark ? .dark : .light
    case .light:  return .light
    case .dark:   return .dark
    }
}
