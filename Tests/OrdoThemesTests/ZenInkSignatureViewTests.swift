import XCTest
import SwiftUI
import AppKit
@testable import OrdoThemes

/// Render/smoke coverage for the Zen Ink signature builders.  These tests use
/// `NSHostingView` deliberately: SwiftUI type-checking a view is not evidence
/// that its Canvas, custom fonts, or AppKit image work survives layout.
@MainActor
final class ZenInkSignatureViewTests: XCTestCase {

    private let theme = ZenInkTheme()

    // MARK: - Complete builder matrix

    func testSignatureBuildersConstructAndRenderInBothPalettes() {
        for scheme in [ColorScheme.light, .dark] {
            let views: [(String, AnyView, CGSize)] = [
                ("checkbox rest", theme.checkbox(done: false, hover: false, pressed: false), CGSize(width: 24, height: 24)),
                ("checkbox hover", theme.checkbox(done: false, hover: true, pressed: false), CGSize(width: 24, height: 24)),
                ("checkbox pressed", theme.checkbox(done: false, hover: true, pressed: true), CGSize(width: 24, height: 24)),
                ("checkbox done", theme.checkbox(done: true, hover: false, pressed: false), CGSize(width: 24, height: 24)),
                ("title open", theme.taskTitle("One quiet task", done: false), CGSize(width: 260, height: 36)),
                ("title done", theme.taskTitle("One quiet task", done: true), CGSize(width: 260, height: 36)),
                ("age zero", theme.ageMarker(days: 0, triage: false), CGSize(width: 54, height: 24)),
                ("age seven triage", theme.ageMarker(days: 7, triage: true), CGSize(width: 54, height: 24)),
                ("compact zero total", theme.progressCompact(done: 0, total: 0), CGSize(width: 38, height: 38)),
                ("compact empty", theme.progressCompact(done: 0, total: 9), CGSize(width: 38, height: 38)),
                ("compact complete", theme.progressCompact(done: 9, total: 9), CGSize(width: 38, height: 38)),
                ("compact clamped", theme.progressCompact(done: 12, total: 9), CGSize(width: 38, height: 38)),
                ("ring zero total", theme.progressRing(done: 0, total: 0), CGSize(width: 132, height: 132)),
                ("ring partial", theme.progressRing(done: 3, total: 9), CGSize(width: 132, height: 132)),
                ("ring complete", theme.progressRing(done: 9, total: 9), CGSize(width: 132, height: 132)),
                ("ring clamped", theme.progressRing(done: 12, total: 9), CGSize(width: 132, height: 132)),
                ("done header zero", theme.doneSectionHeader(count: 0), CGSize(width: 300, height: 28)),
                ("done header populated", theme.doneSectionHeader(count: 3), CGSize(width: 300, height: 28)),
                ("first run", theme.firstRunEmptyState(), CGSize(width: 300, height: 200)),
                ("all clear", theme.allClearedState(), CGSize(width: 340, height: 300)),
                ("all clear peekable", theme.allClearedState(onPeek: {}), CGSize(width: 340, height: 300)),
            ]

            for (name, view, size) in views {
                let image = render(view, size: size, scheme: scheme, reduceMotion: false)
                // The test process may use a 1× or 2× backing scale, but the
                // host must retain the requested point-space aspect ratio.
                XCTAssertGreaterThan(image.pixelsWide, 0, "\(name), \(scheme): empty raster width")
                XCTAssertGreaterThan(image.pixelsHigh, 0, "\(name), \(scheme): empty raster height")
                XCTAssertEqual(Double(image.pixelsWide) / Double(image.pixelsHigh),
                               Double(size.width / size.height), accuracy: 0.001,
                               "\(name), \(scheme): wrong raster aspect")
            }

            // These are visible signatures, rather than transparent layout-only
            // views. A non-empty bitmap catches a regression to the Phase-2 text
            // placeholders or a failed Canvas/AppKit render without snapshotting.
            XCTAssertGreaterThan(alphaPixelCount(render(theme.checkbox(done: true, hover: false, pressed: false), size: CGSize(width: 24, height: 24), scheme: scheme, reduceMotion: false)), 0)
            XCTAssertGreaterThan(alphaPixelCount(render(theme.progressCompact(done: 3, total: 9), size: CGSize(width: 38, height: 38), scheme: scheme, reduceMotion: false)), 0)
            XCTAssertGreaterThan(alphaPixelCount(render(theme.progressRing(done: 3, total: 9), size: CGSize(width: 132, height: 132), scheme: scheme, reduceMotion: false)), 0)
            XCTAssertGreaterThan(alphaPixelCount(render(theme.firstRunEmptyState(), size: CGSize(width: 300, height: 200), scheme: scheme, reduceMotion: false)), 0)
            XCTAssertGreaterThan(alphaPixelCount(render(theme.allClearedState(onPeek: {}), size: CGSize(width: 340, height: 300), scheme: scheme, reduceMotion: false)), 0)
        }
    }

    func testZenFixedSignatureMetricsMatchTheMockupGeometry() {
        XCTAssertEqual(theme.metrics.checkboxSize, 24, accuracy: 0.001)
        XCTAssertEqual(theme.metrics.compactRingDiameter, 38, accuracy: 0.001)
        XCTAssertEqual(theme.metrics.compactRingStrokeWidth, 2.22, accuracy: 0.001)
        XCTAssertEqual(theme.metrics.ringRadius, 46.2, accuracy: 0.001)
        XCTAssertEqual(theme.metrics.ringStrokeWidth, 6.05, accuracy: 0.001)

        // The public geometry underpinning both ring renderers preserves the
        // intentionally open ensō, rather than silently falling back to a circle.
        let arc = SumiInkGeometry.ensoArc(in: CGRect(x: 0, y: 0, width: 120, height: 120))
        let bounds = arc.cgPath.boundingBoxOfPath
        XCTAssertGreaterThan(bounds.width, 80)
        XCTAssertGreaterThan(bounds.height, 80)
    }

    func testConcreteSignatureViewsKeepTheirSpecifiedSizes() {
        XCTAssertEqual(fittingSize(AnyView(OrdoZenMark(theme: theme, done: false, hover: false, pressed: false))).width,
                       24, accuracy: 0.01)
        XCTAssertEqual(fittingSize(AnyView(OrdoZenMark(theme: theme, done: false, hover: false, pressed: false))).height,
                       24, accuracy: 0.01)
        XCTAssertEqual(fittingSize(AnyView(OrdoZenEnso(theme: theme, done: 2, total: 5, compact: true))).width,
                       38, accuracy: 0.01, "compact ensō is specified as a 38pt header element")
        XCTAssertEqual(fittingSize(AnyView(OrdoZenEnso(theme: theme, done: 2, total: 5, compact: true))).height,
                       38, accuracy: 0.01)
        XCTAssertEqual(fittingSize(AnyView(OrdoZenEnso(theme: theme, done: 2, total: 5, compact: false))).width,
                       132, accuracy: 0.01, "rail/all-clear ensō is specified as 132pt")
        let openHanko = fittingSize(AnyView(OrdoZenHanko(theme: theme, done: false)))
        let doneHanko = fittingSize(AnyView(OrdoZenHanko(theme: theme, done: true)))
        XCTAssertEqual(openHanko.width, 27, accuracy: 0.01)
        XCTAssertEqual(openHanko.height, 27, accuracy: 0.01)
        XCTAssertEqual(doneHanko.width, openHanko.width, accuracy: 0.01,
                       "the permanently-mounted seal slot must not change width")
        XCTAssertEqual(doneHanko.height, openHanko.height, accuracy: 0.01,
                       "the permanently-mounted seal slot must not change height")
    }

    func testInitiallyDoneHankoIsVisibleAndAlreadySettled() {
        // After one appearance cycle, initially completed hanko must remain settled.
        let canvas = CGSize(width: 80, height: 80)
        let immediate = render(
            AnyView(OrdoZenHanko(theme: theme, done: true)),
            size: canvas,
            scheme: .light,
            reduceMotion: false
        )
        let image = render(
            AnyView(OrdoZenHanko(theme: theme, done: true)),
            size: canvas,
            scheme: .light,
            reduceMotion: false,
            afterAppearanceFor: 0.025
        )
        guard let initialBounds = alphaBounds(in: immediate), let bounds = alphaBounds(in: image) else {
            return XCTFail("an initially completed hanko must be visible")
        }
        XCTAssertGreaterThan(alphaPixelCount(image), 0)
        XCTAssertEqual(bounds, initialBounds,
                       "an initial done state should stay settled instead of replaying a stamp keyframe")
    }

    // MARK: - Completion geometry

    func testShortDoneTitleStrikeUsesTextBoundsRatherThanWideHost() {
        let host = CGSize(width: 360, height: 44)
        let image = render(theme.taskTitle("Brief task", done: true), size: host, scheme: .light, reduceMotion: true)

        guard let bounds = alphaBounds(in: image) else {
            return XCTFail("a completed title should render text and its strike")
        }
        XCTAssertGreaterThan(alphaPixelCount(image), 0)
        XCTAssertLessThan(bounds.width, host.width * 0.55,
                          "a short title's strike must not span the flexible row column")
    }

    func testConstrainedMultilineTitleWrapsAndRendersWithinHost() {
        let host = CGSize(width: 132, height: 96)
        let image = render(
            theme.taskTitle("Review the visual parity notes before the next quiet release", done: true),
            size: host,
            scheme: .light,
            reduceMotion: true
        )

        guard let bounds = alphaBounds(in: image) else {
            return XCTFail("a constrained multiline title should still render")
        }
        XCTAssertGreaterThan(bounds.height, 36, "title should wrap to multiple lines under the host constraint")
        XCTAssertLessThanOrEqual(bounds.maxX, CGFloat(image.pixelsWide))
        XCTAssertLessThanOrEqual(bounds.maxY, CGFloat(image.pixelsHigh))
    }

    // MARK: - Motion accessibility

    func testReduceMotionPathsRenderAtTheSameSettledSizes() {
        let builders: [(String, AnyView, CGSize)] = [
            ("checkbox", theme.checkbox(done: true, hover: false, pressed: false), CGSize(width: 24, height: 24)),
            ("done title", theme.taskTitle("Settled title", done: true), CGSize(width: 260, height: 36)),
            ("hanko", AnyView(OrdoZenHanko(theme: theme, done: true)), CGSize(width: 27, height: 27)),
            ("compact ring", theme.progressCompact(done: 3, total: 9), CGSize(width: 38, height: 38)),
            ("full ring", theme.progressRing(done: 3, total: 9), CGSize(width: 132, height: 132)),
            ("all clear", theme.allClearedState(onPeek: {}), CGSize(width: 340, height: 300)),
        ]

        for (name, view, size) in builders {
            let standard = render(view, size: size, scheme: .light, reduceMotion: false)
            let reduced = render(view, size: size, scheme: .light, reduceMotion: true)
            XCTAssertEqual(standard.pixelsWide, reduced.pixelsWide, "\(name) width changed with Reduce Motion")
            XCTAssertEqual(standard.pixelsHigh, reduced.pixelsHigh, "\(name) height changed with Reduce Motion")
            XCTAssertGreaterThan(alphaPixelCount(reduced), 0, "\(name) disappeared with Reduce Motion")
        }
    }

    // MARK: - Menu glyph

    func testMenuGlyphIsTemplateSizedNonemptyAndOpenRatherThanPlaceholder() {
        for pointSize: CGFloat in [17, 24] {
            let glyph = theme.menuBarGlyphImage(pointSize: pointSize)
            XCTAssertTrue(glyph.isTemplate)
            XCTAssertEqual(glyph.size.width, pointSize, accuracy: 0.001)
            XCTAssertEqual(glyph.size.height, pointSize, accuracy: 0.001)

            guard let bitmap = bitmap(of: glyph) else {
                return XCTFail("menu glyph at \(pointSize)pt could not produce a bitmap")
            }
            let coverage = alphaBounds(in: bitmap)
            XCTAssertNotNil(coverage, "menu glyph must not be a blank NSImage placeholder")
            guard let coverage else { continue }
            XCTAssertGreaterThan(coverage.width, pointSize * 0.45)
            XCTAssertGreaterThan(coverage.height, pointSize * 0.45)
            XCTAssertLessThan(alphaPixelCount(bitmap), bitmap.pixelsWide * bitmap.pixelsHigh / 2,
                              "menu glyph should remain a light open brush arc, not a filled placeholder")
        }
    }

    // MARK: - Rendering helpers

    private func render(
        _ view: AnyView,
        size: CGSize,
        scheme: ColorScheme,
        reduceMotion: Bool,
        afterAppearanceFor delay: TimeInterval = 0
    ) -> NSBitmapImageRep {
        let root = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            // A transaction is the host-level equivalent available to a test;
            // the system Reduce Motion environment is read-only to clients.
            .transaction { $0.disablesAnimations = reduceMotion }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        if delay > 0 {
            RunLoop.main.run(until: Date().addingTimeInterval(delay))
            hosting.layoutSubtreeIfNeeded()
        }

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            XCTFail("NSHostingView did not create a bitmap image representation")
            return NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: max(1, Int(size.width)), pixelsHigh: max(1, Int(size.height)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }

    private func bitmap(of image: NSImage) -> NSBitmapImageRep? {
        image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
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

    private func alphaBounds(in bitmap: NSBitmapImageRep) -> CGRect? {
        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = -1
        var maxY = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 {
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
