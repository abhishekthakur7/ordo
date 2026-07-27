import XCTest
import SwiftUI
@testable import OrdoThemes

/// Geometry-level tests for the Phase 1 sumi primitives.  These deliberately
/// assert the mockup's unit-space values, not a particular sampled polyline.
final class SumiInkTests: XCTestCase {

    // MARK: - Deterministic roughening

    func testInkFilterPresetsMatchMockupExactly() {
        XCTAssertEqual(SumiInkPreset.inkRough.scale, 2.4, accuracy: 0.000_001)
        XCTAssertEqual(SumiInkPreset.inkRough.frequencyX, 0.028, accuracy: 0.000_001)
        XCTAssertEqual(SumiInkPreset.inkRough.frequencyY, 0.04, accuracy: 0.000_001)
        XCTAssertEqual(SumiInkPreset.inkRough.seed, 7)

        XCTAssertEqual(SumiInkPreset.inkRough2.scale, 1.4, accuracy: 0.000_001)
        XCTAssertEqual(SumiInkPreset.inkRough2.frequencyX, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(SumiInkPreset.inkRough2.frequencyY, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(SumiInkPreset.inkRough2.seed, 3)
    }

    func testValueNoiseIsRepeatableBoundedAndSeedSensitive() {
        let coordinate = (x: 13.125, y: -8.875)
        let ink = SumiNoise(seed: 7)
        let sameInk = SumiNoise(seed: 7)
        let differentInk = SumiNoise(seed: 3)

        XCTAssertEqual(ink.value(x: coordinate.x, y: coordinate.y),
                       sameInk.value(x: coordinate.x, y: coordinate.y), accuracy: 0)
        XCTAssertEqual(ink.vector(x: coordinate.x, y: coordinate.y),
                       sameInk.vector(x: coordinate.x, y: coordinate.y))
        XCTAssertNotEqual(ink.value(x: coordinate.x, y: coordinate.y),
                          differentInk.value(x: coordinate.x, y: coordinate.y), accuracy: 0.000_000_001)

        for x in stride(from: -4.0, through: 4.0, by: 0.37) {
            for y in stride(from: -3.0, through: 3.0, by: 0.41) {
                let value = ink.value(x: x, y: y)
                XCTAssertTrue(value.isFinite)
                XCTAssertGreaterThanOrEqual(value, -1)
                XCTAssertLessThanOrEqual(value, 1)
            }
        }
    }

    func testRougheningIsDeterministicFiniteAndBounded() {
        var source = Path()
        source.addRoundedRect(in: CGRect(x: 12, y: 18, width: 96, height: 84), cornerSize: CGSize(width: 9, height: 9))

        let once = source.sumiRoughened(preset: .inkRough, resolution: CGSize(width: 120, height: 120))
        let again = source.sumiRoughened(preset: .inkRough, resolution: CGSize(width: 120, height: 120))
        let alternate = source.sumiRoughened(preset: .inkRough2, resolution: CGSize(width: 120, height: 120))

        XCTAssertEqual(elements(of: once), elements(of: again))
        XCTAssertNotEqual(elements(of: once), elements(of: alternate), "The two mockup filter presets must not collapse to one mark.")
        XCTAssertNotEqual(elements(of: source), elements(of: once), "A non-degenerate path should actually be perturbed.")
        XCTAssertTrue(isFinite(once))

        // The largest Phase 1 displacement is 2.4 units in the 120-unit box;
        // leave room for the smoothing control handles without accepting an
        // unbounded path runaway.
        let box = once.cgPath.boundingBoxOfPath
        XCTAssertGreaterThanOrEqual(box.minX, 2)
        XCTAssertLessThanOrEqual(box.maxX, 118)
        XCTAssertGreaterThanOrEqual(box.minY, 8)
        XCTAssertLessThanOrEqual(box.maxY, 112)
    }

    func testRougheningHandlesEmptyDegenerateAndInvalidResolutionSafely() {
        let empty = Path()
        XCTAssertTrue(empty.sumiRoughened(preset: .inkRough, resolution: .zero).isEmpty)

        var degenerate = Path()
        degenerate.move(to: CGPoint(x: 8, y: 8))
        degenerate.addLine(to: CGPoint(x: 8, y: 8))
        let roughened = degenerate.sumiRoughened(preset: .inkRough, resolution: CGSize(width: 120, height: 120))
        XCTAssertTrue(isFinite(roughened))
        XCTAssertFalse(elements(of: roughened).isEmpty)

        let unchanged = degenerate.sumiRoughened(preset: .inkRough, resolution: CGSize(width: CGFloat.infinity, height: 120))
        XCTAssertEqual(elements(of: unchanged), elements(of: degenerate))
    }

    // MARK: - Ensō, mark, and menu arcs

    func testEnsoNormalizedArcHasExactEndpointsAndGap() {
        let path = SumiInkGeometry.ensoArc(in: CGRect(x: 0, y: 0, width: 120, height: 120))
        let endpoints = endpoints(of: path)

        // M79,20 A42 42 0 1 1 57,17; resolved centre (62.5, 58.6),
        // start −66.9°, sweep +329.4°.
        assertPoint(endpoints.start, x: 78.93, y: 19.96, accuracy: 0.15)
        assertPoint(endpoints.end, x: 56.99, y: 16.97, accuracy: 0.15)

        let gap = hypot(endpoints.start.x - endpoints.end.x, endpoints.start.y - endpoints.end.y)
        XCTAssertGreaterThan(gap, 20)
        XCTAssertLessThan(gap, 23)
    }

    func testEnsoProgressClampsAndScalesFromUnitBox() {
        let rect = CGRect(x: 10, y: 20, width: 240, height: 240)
        let full = SumiInkGeometry.ensoArc(in: rect, progress: 1)
        XCTAssertEqual(elements(of: SumiInkGeometry.ensoArc(in: rect, progress: 2)), elements(of: full))
        XCTAssertTrue(SumiInkGeometry.ensoArc(in: rect, progress: .infinity).isEmpty)
        XCTAssertTrue(SumiInkGeometry.ensoArc(in: rect, progress: -.infinity).isEmpty)
        XCTAssertTrue(SumiInkGeometry.ensoArc(in: rect, progress: .nan).isEmpty)
        XCTAssertTrue(SumiInkGeometry.ensoArc(in: rect, progress: -0.01).isEmpty)

        let half = endpoints(of: SumiInkGeometry.ensoArc(in: rect, progress: 0.5))
        // Unit endpoint at −66.9 + (329.4 / 2) = 97.8 degrees, then 2× scale.
        assertPoint(half.start, x: 167.86, y: 59.92, accuracy: 0.3)
        assertPoint(half.end, x: 123.60, y: 220.42, accuracy: 0.3)
    }

    func testRoughenedEnsoIsFiniteAndContainedAtUnitAndScaledFrames() {
        for rect in [CGRect(x: 0, y: 0, width: 120, height: 120), CGRect(x: 10, y: 20, width: 264, height: 264)] {
            let path = EnsoShape(progress: 0.68).path(in: rect)
            XCTAssertTrue(isFinite(path))
            XCTAssertFalse(elements(of: path).isEmpty)

            let bounds = path.cgPath.boundingBoxOfPath
            let allowance = min(rect.width, rect.height) * 0.06
            XCTAssertGreaterThanOrEqual(bounds.minX, rect.minX - allowance)
            XCTAssertLessThanOrEqual(bounds.maxX, rect.maxX + allowance)
            XCTAssertGreaterThanOrEqual(bounds.minY, rect.minY - allowance)
            XCTAssertLessThanOrEqual(bounds.maxY, rect.maxY + allowance)
        }
    }

    func testMarkAndMenuArcsCarryMockupConstants() {
        let mark = endpoints(of: SumiInkGeometry.markRingArc(in: CGRect(x: 0, y: 0, width: 24, height: 24)))
        assertPoint(mark.start, x: 18.01, y: 6.50, accuracy: 0.12)
        assertPoint(mark.end, x: 11.00, y: 4.20, accuracy: 0.12)

        let menu = endpoints(of: SumiInkGeometry.menuGlyphArc(in: CGRect(x: 0, y: 0, width: 24, height: 24)))
        assertPoint(menu.start, x: 15.50, y: 5.20, accuracy: 0.12)
        // 318.9° source sweep, trimmed to 92% = 293.4° effective sweep.
        assertPoint(menu.end, x: 5.72, y: 6.61, accuracy: 0.15)

        let fill = SumiInkGeometry.markFill(in: CGRect(x: 0, y: 0, width: 24, height: 24)).cgPath.boundingBoxOfPath
        XCTAssertEqual(fill.minX, 7.6, accuracy: 0.001)
        XCTAssertEqual(fill.minY, 7.6, accuracy: 0.001)
        XCTAssertEqual(fill.width, 8.8, accuracy: 0.001)
        XCTAssertEqual(fill.height, 8.8, accuracy: 0.001)
    }

    // MARK: - Filled brush outlines

    func testBrushSourceBoxesAndPathsAreVerbatim() {
        let expected: [(BrushStrokeKind, Double, Double, String)] = [
            (.strike, 120, 12, "M2,6 C14,3.4 30,3 46,4 C66,5.1 84,3.4 100,4.6 C110,5.1 116,6 118,6 C116,6.5 110,7.6 100,7.9 C84,8.7 66,7 46,8 C30,8.8 14,8.5 2,6 Z"),
            (.divider, 340, 12, "M4,6 C50,3.2 90,3 150,4.4 C210,5.8 250,3 300,4.6 C318,5.2 332,6.2 336,6.4 C332,6.7 318,7.8 300,8 C250,8.6 210,6.2 150,7.6 C90,8.9 50,8.7 4,6 Z"),
            (.tabInk, 100, 9, "M3,4.5 C24,2.4 44,2.2 60,3.2 C76,4.2 88,3 96,4 C90,5.6 76,6 60,5.4 C44,4.8 24,6.6 3,4.5 Z"),
            (.hanko, 40, 40, "M6,5.5 C6,4 7.5,4 9,4 L31,4.2 C33,4.2 34.3,5 34.2,7 L34,31 C34,33.4 33,34.2 31,34.1 L8.5,34 C6.4,34 5.8,33 5.9,31 Z"),
        ]

        for (kind, width, height, svg) in expected {
            let source = BrushStrokeShape.pathData(for: kind)
            XCTAssertEqual(source.box.width, width, accuracy: 0.000_001)
            XCTAssertEqual(source.box.height, height, accuracy: 0.000_001)
            XCTAssertEqual(source.svgPath, svg)
        }
    }

    func testBrushOutlinesCloseAndStretchToTargetFrame() {
        let cases: [(BrushStrokeKind, CGRect, CGPoint, CGFloat)] = [
            (.strike, CGRect(x: 10, y: 20, width: 240, height: 24), CGPoint(x: 14, y: 32), 246),
            (.divider, CGRect(x: 10, y: 20, width: 680, height: 24), CGPoint(x: 18, y: 32), 682),
            (.tabInk, CGRect(x: 10, y: 20, width: 200, height: 18), CGPoint(x: 16, y: 29), 202),
            (.hanko, CGRect(x: 10, y: 20, width: 80, height: 80), CGPoint(x: 22, y: 31), 78.4),
        ]

        for (kind, rect, expectedStart, expectedMaxX) in cases {
            let path = BrushStrokeShape(kind).path(in: rect)
            let pathElements = elements(of: path)
            XCTAssertEqual(pathElements.first?.points.first, expectedStart, "\(kind) origin must scale from its source box")
            XCTAssertTrue(pathElements.contains { $0.type == .closeSubpath }, "\(kind) must remain a filled closed outline")
            XCTAssertTrue(isFinite(path))
            XCTAssertEqual(path.cgPath.boundingBoxOfPath.maxX, expectedMaxX, accuracy: 0.25, "\(kind) width must stretch with its frame")
        }
    }

    func testBrushPathsHandleEmptyFrames() {
        for kind in [BrushStrokeKind.strike, .divider, .tabInk, .hanko] {
            XCTAssertTrue(BrushStrokeShape(kind).path(in: .zero).isEmpty)
        }
    }

    // MARK: - Vertical glyph stack

    func testVerticalTextConstructsForJapaneseAndExtendedGraphemes() {
        let token = TypeToken(size: 24, weight: .semibold, trackingEm: 0.28)
        let text = "序の道👩🏽‍💻"
        let vertical = VerticalText(text, token: token)

        XCTAssertEqual(vertical.string, text)
        XCTAssertEqual(vertical.token, token)
        XCTAssertEqual(Array(vertical.string).count, 4, "The view must accept grapheme clusters, not only ASCII scalars.")
        _ = vertical.body
    }

    // MARK: - Path inspection

    private struct PathElement: Equatable {
        let type: CGPathElementType
        let points: [CGPoint]
    }

    private func elements(of path: Path) -> [PathElement] {
        var result: [PathElement] = []
        path.cgPath.applyWithBlock { pointer in
            let element = pointer.pointee
            let count: Int
            switch element.type {
            case .moveToPoint, .addLineToPoint: count = 1
            case .addQuadCurveToPoint: count = 2
            case .addCurveToPoint: count = 3
            case .closeSubpath: count = 0
            @unknown default: count = 0
            }
            result.append(PathElement(type: element.type, points: count == 0 ? [] : Array(UnsafeBufferPointer(start: element.points, count: count))))
        }
        return result
    }

    private func endpoints(of path: Path) -> (start: CGPoint, end: CGPoint) {
        let pathElements = elements(of: path)
        guard let start = pathElements.first(where: { $0.type == .moveToPoint })?.points.first else {
            XCTFail("expected a non-empty path")
            return (.zero, .zero)
        }
        guard let final = pathElements.reversed().first(where: { !$0.points.isEmpty })?.points.last else {
            XCTFail("expected an endpoint")
            return (.zero, .zero)
        }
        return (start, final)
    }

    private func assertPoint(_ point: CGPoint, x: CGFloat, y: CGFloat, accuracy: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(point.x, x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(point.y, y, accuracy: accuracy, file: file, line: line)
    }

    private func isFinite(_ path: Path) -> Bool {
        elements(of: path).flatMap(\.points).allSatisfy { $0.x.isFinite && $0.y.isFinite }
    }
}
