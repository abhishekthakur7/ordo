// FontRegistrar.swift
// OrdoThemes — Phase 0a: bundled font infrastructure for the "Arcade" theme.
//
// Discovered font identities (verified 2026-07-26 via fontTools name-table
// inspection AND a live CTFontManagerRegisterFontsForURL + CTFontCopy* probe —
// the CoreText-resolved values are the authoritative ones for `Font.custom`):
//
//   Press Start 2P → file "PressStart2P-Regular.ttf"
//     - family (name ID 1 / kCTFontFamilyNameKey): "Press Start 2P"
//     - full name (name ID 4):                    "Press Start 2P Regular"
//     - PostScript name (name ID 6):               "PressStart2P-Regular"
//     Single static weight — no variable axes.
//
//   Space Grotesk → file "SpaceGrotesk-Variable.ttf"
//     The upstream floriankarsten/space-grotesk static TTFs (Regular/Medium/
//     SemiBold/Bold) 404 as of this writing, so this is the google/fonts
//     variable font `SpaceGrotesk[wght].ttf`, renamed for clarity.
//     - CoreText-resolved family (kCTFontFamilyNameKey): "Space Grotesk"
//       (this is the typographic/preferred family, name ID 16 — NOT the
//       literal name ID 1 string "Space Grotesk Light"; CoreText prefers
//       ID 16 when present, and this is the string CTFontCreateWithName /
//       Font.custom(_:size:) should be given)
//     - variation axis: "wght" (tag 0x77676874 / identifier 2003265652),
//       range 300...700, DEFAULT 300 (i.e. the unadorned family name alone
//       resolves to the "Light" instance, PostScript "SpaceGrotesk-Light",
//       NOT a 400-weight "Regular" as one might assume)
//     - named instances present in `fvar` (weight → PostScript name):
//         300 (Light)   → "SpaceGrotesk-Light"
//         400 (Regular) → "SpaceGrotesk-Light_Regular"
//         500 (Medium)  → "SpaceGrotesk-Light_Medium"
//         700 (Bold)    → "SpaceGrotesk-Light_Bold"
//       There is NO named 600 (SemiBold) instance. To render a 600-weight
//       glyph, Phase 1 must build a CTFontDescriptor with a variation
//       dictionary entry for axis identifier 2003265652 (or the "wght"
//       axis tag) set to 600, rather than looking up a "SemiBold" name —
//       SwiftUI's `Font.custom` has no direct variable-axis API, so this
//       likely means going through `NSFont`/`CTFont` with
//       `kCTFontVariationAttribute` and wrapping the result for SwiftUI,
//       or picking the nearest named instance (Medium/Bold) as a stand-in.
//
// Both fonts are SIL Open Font License 1.1 (see Resources/Fonts/OFL.txt).
//
// Phase 1 should reference `FontRegistrar.pressStart2PFamily` and
// `FontRegistrar.spaceGroteskFamily` rather than hardcoding these strings.

import AppKit
import CoreText

/// Registers Ordo's bundled Arcade-theme fonts with CoreText at runtime.
///
/// Fonts live in `Sources/OrdoThemes/Resources/Fonts` and are shipped via
/// SwiftPM's `.process(...)` resource pipeline, which places them in
/// `Bundle.module`. `registerAll()` is safe to call from any thread, any
/// number of times — registration work happens exactly once.
public enum FontRegistrar {

    /// CoreText/AppKit-resolved family name for Press Start 2P.
    /// PostScript name: "PressStart2P-Regular".
    public static let pressStart2PFamily = "Press Start 2P"

    /// CoreText/AppKit-resolved family name for Space Grotesk (variable font).
    /// Default instance PostScript name: "SpaceGrotesk-Light" (weight 300).
    /// Named instances: Light(300)/Regular(400)/Medium(500)/Bold(700);
    /// no discrete SemiBold(600) instance — see file header for the
    /// variation-axis workaround.
    public static let spaceGroteskFamily = "Space Grotesk"

    /// Registers every bundled `.ttf`/`.otf` font exactly once, idempotently
    /// and thread-safely. Safe to call redundantly from any call site that
    /// is about to render themed text.
    public static func registerAll() {
        _ = registrationResult
    }

    /// Backing storage for the one-time registration. Swift guarantees
    /// `static let` initializers run at most once, atomically, even under
    /// concurrent access — this is the idiomatic replacement for
    /// `dispatch_once` in Swift.
    private static let registrationResult: Void = {
        let urls = discoverFontURLs()
        for url in urls {
            var cfError: Unmanaged<CFError>?
            let succeeded = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &cfError)
            if !succeeded {
                if let error = cfError?.takeRetainedValue() {
                    let nsError = error as Error as NSError
                    // kCTFontManagerErrorAlreadyRegistered — not a real
                    // failure, just means a previous call (or another
                    // module) already registered this exact font.
                    let alreadyRegistered = nsError.domain == kCTFontManagerErrorDomain as String
                        && nsError.code == CTFontManagerError.alreadyRegistered.rawValue
                    if !alreadyRegistered {
                        #if DEBUG
                        print("FontRegistrar: failed to register \(url.lastPathComponent): \(nsError)")
                        #endif
                    }
                }
            }
        }
    }()

    /// Locates every bundled font file, tolerant of both possible resource
    /// bundle layouts: SwiftPM's `.process(...)` typically flattens
    /// resources into the bundle root, but some toolchains/bundle formats
    /// preserve the `Fonts` subdirectory. Try both and merge, de-duplicating
    /// by resolved path.
    private static func discoverFontURLs() -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        func add(_ urls: [URL]?) {
            guard let urls else { return }
            for url in urls {
                let path = url.standardizedFileURL.path
                if seen.insert(path).inserted {
                    result.append(url)
                }
            }
        }

        for ext in ["ttf", "otf"] {
            add(Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: nil))
            add(Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: "Fonts"))
            add(Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: "Resources/Fonts"))
        }

        return result
    }
}
