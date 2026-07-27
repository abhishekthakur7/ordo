import SwiftUI

// MARK: - Deterministic sumi displacement

/// A small, seeded two-dimensional value-noise field.  It intentionally has no
/// mutable state: a given seed and coordinate always produce the same value.
public struct SumiNoise: Sendable, Hashable {
    public let seed: Int

    public init(seed: Int) {
        self.seed = seed
    }

    /// Returns smoothly interpolated value noise in `-1 ... 1`.
    public func value(x: Double, y: Double) -> Double {
        guard x.isFinite, y.isFinite else { return 0 }

        // Prevent an accidental pathological input from overflowing while
        // converting the lattice position to an integer.
        let safeX = min(max(x, -1_000_000), 1_000_000)
        let safeY = min(max(y, -1_000_000), 1_000_000)
        let x0 = Int(floor(safeX))
        let y0 = Int(floor(safeY))
        let tx = safeX - Double(x0)
        let ty = safeY - Double(y0)
        let sx = Self.smooth(tx)
        let sy = Self.smooth(ty)

        let a = Self.lerp(lattice(x0, y0), lattice(x0 + 1, y0), sx)
        let b = Self.lerp(lattice(x0, y0 + 1), lattice(x0 + 1, y0 + 1), sx)
        return Self.lerp(a, b, sy)
    }

    /// Convenience overload for geometry code that already works in points.
    public func value(at point: CGPoint) -> Double {
        value(x: Double(point.x), y: Double(point.y))
    }

    /// Two decorrelated samples, suitable for x/y displacement.
    public func vector(x: Double, y: Double) -> SIMD2<Double> {
        SIMD2(value(x: x, y: y), value(x: x + 47.19, y: y - 19.73))
    }

    private func lattice(_ x: Int, _ y: Int) -> Double {
        var h = UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15
        h ^= UInt64(bitPattern: Int64(y)) &* 0xBF58_476D_1CE4_E5B9
        h ^= UInt64(bitPattern: Int64(seed)) &* 0x94D0_49BB_1331_11EB
        h ^= h >> 30
        h &*= 0xBF58_476D_1CE4_E5B9
        h ^= h >> 27
        h &*= 0x94D0_49BB_1331_11EB
        h ^= h >> 31
        let unit = Double(h >> 11) * (1.0 / 9_007_199_254_740_992.0)
        return unit * 2 - 1
    }

    private static func smooth(_ t: Double) -> Double {
        // Quintic smoothstep: first and second derivatives are continuous at
        // lattice boundaries, avoiding visible grid seams in the ink edge.
        t * t * t * (t * (t * 6 - 15) + 10)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

/// The two SVG displacement filters transcribed from the Zen Ink mockup.
public struct SumiInkPreset: Sendable, Hashable {
    public let scale: Double
    public let frequencyX: Double
    public let frequencyY: Double
    public let seed: Int

    public init(scale: Double, frequencyX: Double, frequencyY: Double, seed: Int) {
        self.scale = scale
        self.frequencyX = frequencyX
        self.frequencyY = frequencyY
        self.seed = seed
    }

    /// `ink-rough`: ensō track and progress path.
    public static let inkRough = SumiInkPreset(scale: 2.4, frequencyX: 0.028, frequencyY: 0.04, seed: 7)
    /// `ink-rough-2`: rings, seals, divider, tab ink, and menu glyph.
    public static let inkRough2 = SumiInkPreset(scale: 1.4, frequencyX: 0.05, frequencyY: 0.05, seed: 3)
}

private struct SumiContour {
    var points: [CGPoint]
    var isClosed = false
}

public extension Path {
    /// Re-emits this path as gently smoothed, deterministically displaced
    /// polylines. `resolution` is the displayed path box; coordinates are
    /// normalized to it so the same mark keeps its character at every size.
    func sumiRoughened(preset: SumiInkPreset, resolution: CGSize) -> Path {
        guard resolution.width.isFinite, resolution.height.isFinite,
              resolution.width > 0, resolution.height > 0 else { return self }

        let sampleSpacing = max(0.75, min(resolution.width, resolution.height) / 160)
        let contours = sumiContours(sampleSpacing: sampleSpacing)
        guard !contours.isEmpty else { return self }

        let amplitude = CGFloat(preset.scale * min(resolution.width, resolution.height) / 120)
        guard amplitude.isFinite, amplitude > 0 else { return self }
        let noise = SumiNoise(seed: preset.seed)
        var result = Path()

        for contour in contours {
            let source = normalizedContourPoints(contour)
            guard source.count >= 2 else {
                if let point = source.first {
                    result.move(to: point)
                    if contour.isClosed { result.closeSubpath() }
                }
                continue
            }

            let displaced = source.map { point -> CGPoint in
                let nx = Double(point.x / resolution.width) * 120 * preset.frequencyX
                let ny = Double(point.y / resolution.height) * 120 * preset.frequencyY
                let v = noise.vector(x: nx, y: ny)
                return CGPoint(
                    x: point.x + CGFloat(v.x) * amplitude,
                    y: point.y + CGFloat(v.y) * amplitude
                )
            }
            appendSmoothed(displaced, closed: contour.isClosed, to: &result)
        }
        return result
    }

    private func sumiContours(sampleSpacing: CGFloat) -> [SumiContour] {
        var contours: [SumiContour] = []
        var current: SumiContour?

        func finishCurrent() {
            if let current, !current.points.isEmpty { contours.append(current) }
            current = nil
        }

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                finishCurrent()
                current = SumiContour(points: [element.points[0]])
            case .addLineToPoint:
                guard var contour = current else { return }
                Self.appendLine(from: contour.points.last!, to: element.points[0], spacing: sampleSpacing, into: &contour.points)
                current = contour
            case .addQuadCurveToPoint:
                guard var contour = current else { return }
                Self.appendQuad(from: contour.points.last!, control: element.points[0], to: element.points[1], spacing: sampleSpacing, into: &contour.points)
                current = contour
            case .addCurveToPoint:
                guard var contour = current else { return }
                Self.appendCubic(from: contour.points.last!, control1: element.points[0], control2: element.points[1], to: element.points[2], spacing: sampleSpacing, into: &contour.points)
                current = contour
            case .closeSubpath:
                guard var contour = current else { return }
                contour.isClosed = true
                if let first = contour.points.first, let last = contour.points.last,
                   Self.distance(first, last) > 0.001 {
                    Self.appendLine(from: last, to: first, spacing: sampleSpacing, into: &contour.points)
                }
                current = contour
            @unknown default:
                break
            }
        }
        finishCurrent()
        return contours
    }

    private func normalizedContourPoints(_ contour: SumiContour) -> [CGPoint] {
        guard contour.isClosed, contour.points.count > 1,
              let first = contour.points.first, let last = contour.points.last,
              Self.distance(first, last) <= 0.001 else { return contour.points }
        return Array(contour.points.dropLast())
    }

    private static func appendLine(from start: CGPoint, to end: CGPoint, spacing: CGFloat, into points: inout [CGPoint]) {
        let steps = boundedSteps(distance(start, end), spacing: spacing)
        guard steps > 0 else { return }
        for i in 1...steps {
            points.append(interpolate(start, end, CGFloat(i) / CGFloat(steps)))
        }
    }

    private static func appendQuad(from start: CGPoint, control: CGPoint, to end: CGPoint, spacing: CGFloat, into points: inout [CGPoint]) {
        let length = distance(start, control) + distance(control, end)
        let steps = boundedSteps(length, spacing: spacing)
        guard steps > 0 else { return }
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a = interpolate(start, control, t)
            let b = interpolate(control, end, t)
            points.append(interpolate(a, b, t))
        }
    }

    private static func appendCubic(from start: CGPoint, control1: CGPoint, control2: CGPoint, to end: CGPoint, spacing: CGFloat, into points: inout [CGPoint]) {
        let length = distance(start, control1) + distance(control1, control2) + distance(control2, end)
        let steps = boundedSteps(length, spacing: spacing)
        guard steps > 0 else { return }
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a = interpolate(start, control1, t)
            let b = interpolate(control1, control2, t)
            let c = interpolate(control2, end, t)
            points.append(interpolate(interpolate(a, b, t), interpolate(b, c, t), t))
        }
    }

    private static func boundedSteps(_ length: CGFloat, spacing: CGFloat) -> Int {
        guard length.isFinite, spacing.isFinite, spacing > 0 else { return 0 }
        return min(96, max(1, Int(ceil(length / spacing))))
    }

    private static func interpolate(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    private func appendSmoothed(_ points: [CGPoint], closed: Bool, to path: inout Path) {
        let count = points.count
        guard count >= 2 else { return }
        path.move(to: points[0])

        let segmentCount = closed ? count : count - 1
        for i in 0..<segmentCount {
            let p0 = points[closed ? (i - 1 + count) % count : max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[(i + 1) % count]
            let p3 = points[closed ? (i + 2) % count : min(count - 1, i + 2)]
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        if closed { path.closeSubpath() }
    }
}

// MARK: - Shared unit geometry

public struct SumiUnitBox: Sendable, Hashable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Strongly typed SVG source data for the four filled brush marks.
public struct BrushPathData: Sendable, Hashable {
    public let box: SumiUnitBox
    public let svgPath: String

    public init(box: SumiUnitBox, svgPath: String) {
        self.box = box
        self.svgPath = svgPath
    }
}

public enum BrushStrokeKind: Sendable, Hashable {
    case strike
    case divider
    case tabInk
    case hanko
}

/// The tapered filled brush strokes, exactly authored in their mockup unit boxes.
public struct BrushStrokeShape: Shape {
    public let kind: BrushStrokeKind

    public init(_ kind: BrushStrokeKind) {
        self.kind = kind
    }

    public static func pathData(for kind: BrushStrokeKind) -> BrushPathData {
        switch kind {
        case .strike:
            return BrushPathData(box: SumiUnitBox(width: 120, height: 12), svgPath: "M2,6 C14,3.4 30,3 46,4 C66,5.1 84,3.4 100,4.6 C110,5.1 116,6 118,6 C116,6.5 110,7.6 100,7.9 C84,8.7 66,7 46,8 C30,8.8 14,8.5 2,6 Z")
        case .divider:
            return BrushPathData(box: SumiUnitBox(width: 340, height: 12), svgPath: "M4,6 C50,3.2 90,3 150,4.4 C210,5.8 250,3 300,4.6 C318,5.2 332,6.2 336,6.4 C332,6.7 318,7.8 300,8 C250,8.6 210,6.2 150,7.6 C90,8.9 50,8.7 4,6 Z")
        case .tabInk:
            return BrushPathData(box: SumiUnitBox(width: 100, height: 9), svgPath: "M3,4.5 C24,2.4 44,2.2 60,3.2 C76,4.2 88,3 96,4 C90,5.6 76,6 60,5.4 C44,4.8 24,6.6 3,4.5 Z")
        case .hanko:
            return BrushPathData(box: SumiUnitBox(width: 40, height: 40), svgPath: "M6,5.5 C6,4 7.5,4 9,4 L31,4.2 C33,4.2 34.3,5 34.2,7 L34,31 C34,33.4 33,34.2 31,34.1 L8.5,34 C6.4,34 5.8,33 5.9,31 Z")
        }
    }

    public func path(in rect: CGRect) -> Path {
        let data = Self.pathData(for: kind)
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else { return Path() }
        let transform = CGAffineTransform(
            a: rect.width / data.box.width, b: 0,
            c: 0, d: rect.height / data.box.height,
            tx: rect.minX, ty: rect.minY
        )
        var path = Path()
        path.addPath(Self.unitPath(for: kind), transform: transform)
        return path
    }

    /// The shape with the mockup's applicable ink displacement already applied.
    /// Strike remains unfiltered because its source mask has no SVG filter.
    public func sumiPath(in rect: CGRect) -> Path {
        let path = path(in: rect)
        switch kind {
        case .strike:
            return path
        case .divider, .tabInk, .hanko:
            return path.sumiRoughened(preset: .inkRough2, resolution: rect.size)
        }
    }

    private static func unitPath(for kind: BrushStrokeKind) -> Path {
        var p = Path()
        switch kind {
        case .strike:
            p.move(to: CGPoint(x: 2, y: 6))
            p.addCurve(to: CGPoint(x: 46, y: 4), control1: CGPoint(x: 14, y: 3.4), control2: CGPoint(x: 30, y: 3))
            p.addCurve(to: CGPoint(x: 100, y: 4.6), control1: CGPoint(x: 66, y: 5.1), control2: CGPoint(x: 84, y: 3.4))
            p.addCurve(to: CGPoint(x: 118, y: 6), control1: CGPoint(x: 110, y: 5.1), control2: CGPoint(x: 116, y: 6))
            p.addCurve(to: CGPoint(x: 100, y: 7.9), control1: CGPoint(x: 116, y: 6.5), control2: CGPoint(x: 110, y: 7.6))
            p.addCurve(to: CGPoint(x: 46, y: 8), control1: CGPoint(x: 84, y: 8.7), control2: CGPoint(x: 66, y: 7))
            p.addCurve(to: CGPoint(x: 2, y: 6), control1: CGPoint(x: 30, y: 8.8), control2: CGPoint(x: 14, y: 8.5))
        case .divider:
            p.move(to: CGPoint(x: 4, y: 6))
            p.addCurve(to: CGPoint(x: 150, y: 4.4), control1: CGPoint(x: 50, y: 3.2), control2: CGPoint(x: 90, y: 3))
            p.addCurve(to: CGPoint(x: 300, y: 4.6), control1: CGPoint(x: 210, y: 5.8), control2: CGPoint(x: 250, y: 3))
            p.addCurve(to: CGPoint(x: 336, y: 6.4), control1: CGPoint(x: 318, y: 5.2), control2: CGPoint(x: 332, y: 6.2))
            p.addCurve(to: CGPoint(x: 300, y: 8), control1: CGPoint(x: 332, y: 6.7), control2: CGPoint(x: 318, y: 7.8))
            p.addCurve(to: CGPoint(x: 150, y: 7.6), control1: CGPoint(x: 250, y: 8.6), control2: CGPoint(x: 210, y: 6.2))
            p.addCurve(to: CGPoint(x: 4, y: 6), control1: CGPoint(x: 90, y: 8.9), control2: CGPoint(x: 50, y: 8.7))
        case .tabInk:
            p.move(to: CGPoint(x: 3, y: 4.5))
            p.addCurve(to: CGPoint(x: 60, y: 3.2), control1: CGPoint(x: 24, y: 2.4), control2: CGPoint(x: 44, y: 2.2))
            p.addCurve(to: CGPoint(x: 96, y: 4), control1: CGPoint(x: 76, y: 4.2), control2: CGPoint(x: 88, y: 3))
            p.addCurve(to: CGPoint(x: 60, y: 5.4), control1: CGPoint(x: 90, y: 5.6), control2: CGPoint(x: 76, y: 6))
            p.addCurve(to: CGPoint(x: 3, y: 4.5), control1: CGPoint(x: 44, y: 4.8), control2: CGPoint(x: 24, y: 6.6))
        case .hanko:
            p.move(to: CGPoint(x: 6, y: 5.5))
            p.addCurve(to: CGPoint(x: 9, y: 4), control1: CGPoint(x: 6, y: 4), control2: CGPoint(x: 7.5, y: 4))
            p.addLine(to: CGPoint(x: 31, y: 4.2))
            p.addCurve(to: CGPoint(x: 34.2, y: 7), control1: CGPoint(x: 33, y: 4.2), control2: CGPoint(x: 34.3, y: 5))
            p.addLine(to: CGPoint(x: 34, y: 31))
            p.addCurve(to: CGPoint(x: 31, y: 34.1), control1: CGPoint(x: 34, y: 33.4), control2: CGPoint(x: 33, y: 34.2))
            p.addLine(to: CGPoint(x: 8.5, y: 34))
            p.addCurve(to: CGPoint(x: 5.9, y: 31), control1: CGPoint(x: 6.4, y: 34), control2: CGPoint(x: 5.8, y: 33))
            p.closeSubpath()
        }
        p.closeSubpath()
        return p
    }
}

/// Exact arcs shared by the progress ring, task mark, and menu-bar glyph.
public enum SumiInkGeometry {
    public static func ensoArc(in rect: CGRect, progress: Double = 1) -> Path {
        scaledArc(in: rect, unitSize: 120, center: CGPoint(x: 62.5, y: 58.6), radius: 42,
                  startDegrees: -66.9, sweepDegrees: 329.4, progress: progress)
    }

    public static func markRingArc(in rect: CGRect) -> Path {
        scaledArc(in: rect, unitSize: 24, center: CGPoint(x: 12.08, y: 12.73), radius: 8.6,
                  startDegrees: -46.4, sweepDegrees: 309.2, progress: 1)
    }

    /// The mockup's 92%-trimmed menu mark (293.4° effective sweep).
    public static func menuGlyphArc(in rect: CGRect) -> Path {
        scaledArc(in: rect, unitSize: 24, center: CGPoint(x: 11.68, y: 13.35), radius: 9,
                  startDegrees: -64.9, sweepDegrees: 293.4, progress: 1)
    }

    public static func markFill(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let sx = rect.width / 24
        let sy = rect.height / 24
        return Path(ellipseIn: CGRect(x: rect.minX + 7.6 * sx, y: rect.minY + 7.6 * sy, width: 8.8 * sx, height: 8.8 * sy))
    }

    private static func scaledArc(in rect: CGRect, unitSize: CGFloat, center: CGPoint, radius: CGFloat, startDegrees: Double, sweepDegrees: Double, progress: Double) -> Path {
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else { return Path() }
        let p = min(1, max(0, progress.isFinite ? progress : 0))
        guard p > 0 else { return Path() }
        let sx = rect.width / unitSize
        let sy = rect.height / unitSize
        // Zen's source boxes are square. For a non-square caller, an affine
        // circle becomes the expected stretched ellipse, consistent with SVG.
        var unit = Path()
        unit.addArc(center: center, radius: radius,
                    startAngle: .degrees(startDegrees), endAngle: .degrees(startDegrees + sweepDegrees * p),
                    clockwise: false)
        var result = Path()
        result.addPath(unit, transform: CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: rect.minX, ty: rect.minY))
        return result
    }
}

/// The Zen ensō's progress arc.  Draw this for the ink layer; callers can use
/// `EnsoShape(progress: 1)` for the full track layer.
public struct EnsoShape: Shape {
    public var progress: Double

    public init(progress: Double = 1) {
        self.progress = progress
    }

    public func path(in rect: CGRect) -> Path {
        SumiInkGeometry.ensoArc(in: rect, progress: progress)
            .sumiRoughened(preset: .inkRough, resolution: rect.size)
    }
}

public struct SumiMarkRingShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        SumiInkGeometry.markRingArc(in: rect)
            .sumiRoughened(preset: .inkRough2, resolution: rect.size)
    }
}

public struct SumiMarkFillShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path { SumiInkGeometry.markFill(in: rect) }
}

public struct SumiMenuGlyphShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        SumiInkGeometry.menuGlyphArc(in: rect)
            .sumiRoughened(preset: .inkRough2, resolution: rect.size)
    }
}

/// The 24-unit composer plus glyph.
public struct SumiPlusShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let sx = rect.width / 24
        let sy = rect.height / 24
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 12 * sx, y: rect.minY + 5 * sy))
        p.addLine(to: CGPoint(x: rect.minX + 12 * sx, y: rect.minY + 19 * sy))
        p.move(to: CGPoint(x: rect.minX + 5 * sx, y: rect.minY + 12 * sy))
        p.addLine(to: CGPoint(x: rect.minX + 19 * sx, y: rect.minY + 12 * sy))
        return p
    }
}

// MARK: - Vertical text

/// A vertical glyph stack for Zen's Japanese rails and header sublabel.
public struct VerticalText: View {
    public let string: String
    public let token: TypeToken

    public init(_ string: String, token: TypeToken) {
        self.string = string
        self.token = token
    }

    public var body: some View {
        VStack(spacing: token.trackingPoints) {
            ForEach(Array(string.enumerated()), id: \.offset) { _, glyph in
                Text(String(glyph))
                    .typeToken(token)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(string)
    }
}

#if DEBUG
#Preview("Sumi Ink primitives") {
    VStack(spacing: 24) {
        ZStack {
            EnsoShape().stroke(.primary.opacity(0.15), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
            EnsoShape(progress: 0.68).stroke(.primary, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        }
        .frame(width: 120, height: 120)

        BrushStrokeShape(.divider).fill(.primary.opacity(0.66)).frame(width: 340, height: 12)
        HStack(spacing: 16) {
            SumiMarkRingShape().stroke(.secondary, style: StrokeStyle(lineWidth: 1.8, lineCap: .round)).frame(width: 24, height: 24)
            SumiMenuGlyphShape().stroke(.primary, style: StrokeStyle(lineWidth: 2.1, lineCap: .round)).frame(width: 24, height: 24)
            BrushStrokeShape(.hanko).fill(.red).frame(width: 40, height: 40)
        }
    }
    .padding()
}

#Preview("Vertical Zen text") {
    VerticalText("序の道", token: TypeToken(size: 24, weight: .semibold, trackingEm: 0.28))
        .padding()
}
#endif
