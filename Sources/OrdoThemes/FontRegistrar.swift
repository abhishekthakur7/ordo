// FontRegistrar.swift
// OrdoThemes — bundled font infrastructure for the "Arcade" theme.
//
// Bundles Press Start 2P (single static weight) and Space Grotesk (a variable
// font, default instance is Light/300 — there is no named SemiBold/600
// instance). Both are SIL Open Font License 1.1 (see Resources/Fonts/OFL.txt).

import AppKit
import CoreText

/// Registers Ordo's bundled Arcade-theme fonts with CoreText at runtime.
/// Safe to call from any thread, any number of times — registration happens
/// exactly once.
public enum FontRegistrar {

    /// CoreText/AppKit-resolved family name for Press Start 2P.
    public static let pressStart2PFamily = "Press Start 2P"

    /// CoreText/AppKit-resolved family name for Space Grotesk (variable font,
    /// default weight 300; no discrete 600/SemiBold instance).
    public static let spaceGroteskFamily = "Space Grotesk"

    /// Registers every bundled font exactly once, idempotently and thread-safely.
    public static func registerAll() {
        _ = registrationResult
    }

    /// Backing storage for the one-time registration (a `static let`
    /// initializer runs exactly once, atomically).
    private static let registrationResult: Void = {
        let urls = discoverFontURLs()
        for url in urls {
            var cfError: Unmanaged<CFError>?
            let succeeded = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &cfError)
            if !succeeded {
                if let error = cfError?.takeRetainedValue() {
                    let nsError = error as Error as NSError
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

    /// Locates every bundled font file, tolerant of both possible bundle
    /// layouts (flattened root or a `Fonts` subdirectory), de-duplicated by
    /// resolved path.
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
