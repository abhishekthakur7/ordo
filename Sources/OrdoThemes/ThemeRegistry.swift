import Foundation

/// The catalog of available themes. V1 ships macOS, Arcade, and Zen Ink; the remaining
/// `ThemeID` cases are reserved and drop in by appending to `all` — no call site changes.
public struct ThemeRegistry: Sendable {

    /// All themes available in this build.
    public let all: [any Theme]

    /// The theme used when none is chosen (always macOS per REQUIREMENTS).
    public let defaultTheme: any Theme

    public init(all: [any Theme], defaultTheme: any Theme) {
        self.all = all
        self.defaultTheme = defaultTheme
    }

    /// The shipping registry.
    public static let shared = ThemeRegistry(
        all: [MacOSTheme(), ArcadeTheme(), ZenInkTheme()],
        defaultTheme: MacOSTheme()
    )

    /// Look up a theme by id, or nil if not present in this build.
    public func theme(id: ThemeID) -> (any Theme)? {
        all.first { $0.id == id }
    }

    /// Look up a theme by id, falling back to the default if absent.
    public func theme(idOrDefault id: ThemeID) -> any Theme {
        theme(id: id) ?? defaultTheme
    }
}
