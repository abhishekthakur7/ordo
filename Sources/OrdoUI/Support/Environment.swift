// OrdoUI — environment plumbing for the theme + resolved palette. The root resolves
// the palette once and injects it so every child reads one consistent value instead
// of re-resolving; the theme is injected for its signature views and voice.

import SwiftUI
import OrdoThemes

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any Theme = MacOSTheme()
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = MacOSTheme().palette(for: .light)
}

extension EnvironmentValues {
    /// The active theme (its tokens, voice and signature views).
    public var ordoTheme: any Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    /// The palette resolved for the current appearance + accessibility state.
    public var ordoPalette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
