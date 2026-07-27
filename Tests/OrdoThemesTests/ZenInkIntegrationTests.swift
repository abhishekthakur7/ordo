import AppKit
import SwiftUI
import XCTest
import OrdoCore
@testable import OrdoThemes

/// Phase-6 integration coverage for the registry-facing Zen seam.  The data
/// and signature primitives have dedicated contract tests; these assertions
/// exercise the public structural hooks as Settings/shared views consume them.
@MainActor
final class ZenInkIntegrationTests: XCTestCase {

    func testRegistryExposesExactlyTheShippedSelectableThemes() {
        let registry = ThemeRegistry.shared

        XCTAssertEqual(registry.defaultTheme.id, .macOS)
        XCTAssertEqual(registry.all.map(\.id), [.macOS, .arcade, .zenInk])
        XCTAssertEqual(Set(registry.all.map(\.id)).count, registry.all.count)

        for expected in registry.all {
            guard let selected = registry.theme(id: expected.id) else {
                return XCTFail("registered theme \(expected.id) was not selectable")
            }
            XCTAssertEqual(selected.id, expected.id)
            XCTAssertEqual(selected.displayName, expected.displayName)
        }

        XCTAssertNil(registry.theme(id: .swiss), "reserved themes must not appear selectable")
        XCTAssertEqual(registry.theme(idOrDefault: .swiss).id, .macOS)
    }

    func testZenStructuralBuildersRenderThroughThePublicThemeContract() {
        guard let zen = ThemeRegistry.shared.theme(id: .zenInk) as? ZenInkTheme else {
            return XCTFail("Zen Ink must be available from the shipping registry")
        }

        XCTAssertEqual(zen.composerPlaceholder(isToday: true), "書く… write the next thing")
        XCTAssertEqual(zen.composerPlaceholder(isToday: false), "書く… write the next thing")
        let openRowAccessory = tryUnwrap(
            zen.rowTrailingAccessory(done: false, age: 10, triage: true, index: 2),
            "Zen open row accessory"
        )
        let completedRowAccessory = tryUnwrap(
            zen.rowTrailingAccessory(done: true, age: 10, triage: true, index: 2),
            "Zen completed row accessory"
        )
        XCTAssertEqual(fittingSize(openRowAccessory), CGSize(width: 27, height: 27))
        XCTAssertEqual(fittingSize(completedRowAccessory), CGSize(width: 27, height: 27))

        for scheme in [ColorScheme.light, .dark] {
            for reduceMotion in [false, true] {
                let views: [(String, AnyView, CGSize)] = [
                    ("header leading", tryUnwrap(zen.headerLeading(score: 999), "Zen header leading"), CGSize(width: 220, height: 46)),
                    ("brush divider", tryUnwrap(zen.headerAccessory(), "Zen header accessory"), CGSize(width: 320, height: 12)),
                    ("compact header progress", tryUnwrap(zen.headerTrailingAccessory(done: 2, total: 5, expanded: false), "Zen compact header accessory"), CGSize(width: 38, height: 38)),
                    ("tabs", tryUnwrap(zen.tabBarContent(tab: .today, remaining: { list in list == .today ? 3 : 8 }, onSelect: { _ in }), "Zen tab bar"), CGSize(width: 320, height: 54)),
                    ("completed-row seal", completedRowAccessory, CGSize(width: 27, height: 27)),
                    ("rail", tryUnwrap(zen.railContent(done: 2, total: 5, remaining: 3, score: 999, best: 999, streak: 9), "Zen rail"), CGSize(width: 194, height: 500)),
                ]

                for (name, view, size) in views {
                    let bitmap = render(view, size: size, scheme: scheme, reduceMotion: reduceMotion)
                    XCTAssertGreaterThan(bitmap.pixelsWide, 0, "\(name) failed to lay out")
                    XCTAssertGreaterThan(bitmap.pixelsHigh, 0, "\(name) failed to lay out")
                    XCTAssertGreaterThan(alphaPixelCount(bitmap), 0, "\(name) rendered no visible content")
                }

                // The expanded accessory is intentionally collapsed to zero
                // width/opacity, but must still construct safely at the call site.
                _ = render(
                    tryUnwrap(zen.headerTrailingAccessory(done: 2, total: 5, expanded: true), "Zen expanded header accessory"),
                    size: CGSize(width: 38, height: 38),
                    scheme: scheme,
                    reduceMotion: reduceMotion
                )
            }
        }
    }

    func testAccessibilityPaletteAdjustmentsComposeWithoutChangingPaperIdentity() {
        let theme = ZenInkTheme()

        for appearance in [ResolvedAppearance.light, .dark] {
            let adjusted = theme.palette(
                for: appearance,
                accessibility: AccessibilityOptions(reduceTransparency: true, increaseContrast: true)
            )
            guard case let .paper(paper) = adjusted.surface else {
                return XCTFail("Zen Ink must remain a paper surface under accessibility adjustments")
            }

            XCTAssertEqual(paper.grain.opacity, 0, accuracy: 0.0001)
            XCTAssertEqual(paper.borderWidth, 1.5, accuracy: 0.0001)
            XCTAssertEqual(adjusted.hairlineWidth, 1.5, accuracy: 0.0001)
            XCTAssertEqual(adjusted.inkFaint, adjusted.ink3)
        }
    }

    private func tryUnwrap(_ view: AnyView?, _ name: String) -> AnyView {
        guard let view else {
            XCTFail("\(name) unexpectedly returned nil")
            return AnyView(EmptyView())
        }
        return view
    }

    private func render(_ view: AnyView, size: CGSize, scheme: ColorScheme, reduceMotion: Bool) -> NSBitmapImageRep {
        let root = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            .transaction { $0.disablesAnimations = reduceMotion }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            XCTFail("NSHostingView did not create a bitmap image representation")
            return NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: max(1, Int(size.width)), pixelsHigh: max(1, Int(size.height)),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }

    private func fittingSize(_ view: AnyView) -> CGSize {
        let hosting = NSHostingView(rootView: view)
        hosting.layoutSubtreeIfNeeded()
        return hosting.fittingSize
    }

    private func alphaPixelCount(_ bitmap: NSBitmapImageRep) -> Int {
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 {
                count += 1
            }
        }
        return count
    }
}
