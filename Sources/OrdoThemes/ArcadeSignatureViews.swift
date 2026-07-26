import SwiftUI
import AppKit

// MARK: - Environment → palette bridge

/// Resolves the live palette (and Reduce-Motion flag) from the environment and
/// hands them to `content`, mirroring `MacOSSignatureViews.Themed`.
private struct Themed<Content: View>: View {
    let theme: ArcadeTheme
    @ViewBuilder let content: (Palette, Bool) -> Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let palette = theme.palette(
            for: ResolvedAppearance(scheme),
            accessibility: AccessibilityOptions(
                reduceTransparency: reduceTransparency,
                increaseContrast: contrast == .increased
            )
        )
        content(palette, reduceMotion)
    }
}

// MARK: - Shared pixel shapes

/// The 8-rect diagonal staircase shared by the checkbox tick and the
/// menu-bar/panel-header glyph. 10×10 grid, one unit cell each.
struct ArcadeCheckStaircase: Shape {
    static let cells: [(CGFloat, CGFloat)] = [
        (1, 4), (2, 5), (3, 6), (4, 5), (5, 4), (6, 3), (7, 2), (8, 1),
    ]

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 10
        var p = Path()
        for (x, y) in Self.cells {
            p.addRect(CGRect(x: rect.minX + x * s, y: rect.minY + y * s, width: s, height: s))
        }
        return p
    }
}

/// The 5-rect diamond "O" blob used as the onboarding brand mark, distinct
/// from the checkbox/menu-bar staircase glyph. 10×10 grid.
struct ArcadeBrandBlob: View {
    let color: Color

    static let cells: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (3, 1, 4, 1), (2, 2, 6, 1), (1, 3, 8, 4), (2, 7, 6, 1), (3, 8, 4, 1),
    ]

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 10
            var p = Path()
            for (x, y, w, h) in Self.cells {
                p.addRect(CGRect(x: x * s, y: y * s, width: w * s, height: h * s))
            }
            ctx.fill(p, with: .color(color))
        }
    }
}

/// The victory trophy: coin-colored body with a single blinking glint pixel
/// (opacity animated by the caller, see `OrdoArcadeVictory`).
struct ArcadeTrophyMark: View {
    let coin: Color
    let glint: Color
    let glintOpacity: Double

    static let bodyCells: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (4, 1, 8, 1), (3, 2, 10, 1),
        (3, 3, 2, 3), (11, 3, 2, 3),
        (1, 3, 2, 1), (13, 3, 2, 1),
        (1, 4, 1, 2), (14, 4, 1, 2),
        (5, 3, 6, 4),
        (4, 6, 8, 1), (5, 7, 6, 1),
        (7, 8, 2, 2),
        (5, 10, 6, 1), (4, 11, 8, 2),
    ]
    static let glintCell: (CGFloat, CGFloat, CGFloat, CGFloat) = (6, 4, 1, 1)

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16
            var body = Path()
            for (x, y, w, h) in Self.bodyCells {
                body.addRect(CGRect(x: x * s, y: y * s, width: w * s, height: h * s))
            }
            ctx.fill(body, with: .color(coin))

            let (gx, gy, gw, gh) = Self.glintCell
            let glintRect = CGRect(x: gx * s, y: gy * s, width: gw * s, height: gh * s)
            ctx.fill(Path(glintRect), with: .color(glint.opacity(glintOpacity)))
        }
    }
}

/// The rail mascot critter. Not part of the `Theme` protocol; used directly by
/// the structural rail content. Bobs gently up and down when `bobbing` is true.
public struct ArcadeMascotMark: View {
    public let accent: Color
    public let accentDim: Color
    public let screen: Color
    public let bobbing: Bool

    public init(accent: Color, accentDim: Color, screen: Color, bobbing: Bool = false) {
        self.accent = accent
        self.accentDim = accentDim
        self.screen = screen
        self.bobbing = bobbing
    }

    @State private var bob = false

    static let bodyCells: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (3, 4, 10, 7), (2, 5, 1, 5), (13, 5, 1, 5), (5, 2, 1, 2), (10, 2, 1, 2),
    ]
    static let faceCells: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (5, 6, 2, 2), (9, 6, 2, 2), (6, 9, 4, 1),
    ]
    static let feetCells: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (3, 12, 3, 1), (10, 12, 3, 1),
    ]

    public var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16
            func rects(_ cells: [(CGFloat, CGFloat, CGFloat, CGFloat)]) -> Path {
                var p = Path()
                for (x, y, w, h) in cells {
                    p.addRect(CGRect(x: x * s, y: y * s, width: w * s, height: h * s))
                }
                return p
            }
            ctx.fill(rects(Self.bodyCells), with: .color(accent))
            ctx.fill(rects(Self.faceCells), with: .color(screen))
            ctx.fill(rects(Self.feetCells), with: .color(accentDim))
        }
        .offset(y: bob ? -1.5 : 0)
        .onAppear {
            guard bobbing else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
    }
}

// MARK: - Checkbox (the hero)

struct OrdoArcadeCheckbox: View {
    let theme: ArcadeTheme
    let done: Bool
    let hover: Bool
    let pressed: Bool

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            let size = theme.metrics.checkboxSize
            let borderWidth = theme.metrics.borderWidth

            let borderColor = done ? palette.accent : (hover ? palette.accent : palette.checkRing)
            let fillColor = done ? palette.accent : palette.segmentBackground
            let glowColor = done ? palette.glow : .clear

            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fillColor)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)

                KeyframeAnimator(initialValue: done ? 1.0 : 0.0, trigger: done) { reveal in
                    ArcadeCheckStaircase()
                        .fill(palette.accentInk, style: FillStyle(antialiased: false))
                        .frame(width: 14, height: 14)
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle().frame(width: max(0, geo.size.width * reveal))
                            }
                        }
                } keyframes: { _ in
                    if reduceMotion {
                        LinearKeyframe(done ? 1.0 : 0.0, duration: 0.001)
                    } else {
                        let steps = theme.motion.tickDraw.curve.stepCount ?? 4
                        let interval = theme.motion.tickDraw.duration / Double(steps)
                        let start: Double = done ? 0 : 1
                        let end: Double = done ? 1 : 0
                        let delta = end - start
                        LinearKeyframe(start, duration: 0.0001)
                        LinearKeyframe(start, duration: interval)
                        LinearKeyframe(start + delta * 0.25, duration: 0.0001)
                        LinearKeyframe(start + delta * 0.25, duration: interval)
                        LinearKeyframe(start + delta * 0.5, duration: 0.0001)
                        LinearKeyframe(start + delta * 0.5, duration: interval)
                        LinearKeyframe(start + delta * 0.75, duration: 0.0001)
                        LinearKeyframe(start + delta * 0.75, duration: interval)
                        LinearKeyframe(end, duration: 0.0001)
                    }
                }
            }
            .frame(width: size, height: size)
            .shadow(color: glowColor, radius: 6)
            .shadow(color: glowColor, radius: 1)
            .scaleEffect(pressed ? 0.92 : 1)
            .animation(theme.motion.checkboxFill.animation(reduceMotion: reduceMotion), value: done)
            .animation(theme.motion.pressEcho.animation(reduceMotion: reduceMotion), value: pressed)
            .accessibilityAddTraits(done ? [.isSelected] : [])
        }
    }
}

// MARK: - Task title (Space Grotesk + animated scaleX strike)

struct OrdoArcadeTaskTitle: View {
    let theme: ArcadeTheme
    let text: String
    let done: Bool

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            Text(text)
                .typeToken(theme.typeScale.taskTitle)
                .foregroundStyle(done ? palette.ink2 : palette.ink)
                .animation(theme.motion.titleColorFade.animation(reduceMotion: reduceMotion), value: done)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(palette.ink2)
                            .frame(width: geo.size.width, height: 2)
                            .scaleEffect(x: reduceMotion ? 1 : (done ? 1 : 0), anchor: .leading)
                            .opacity(done ? 1 : 0)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.52)
                    }
                    .allowsHitTesting(false)
                    .animation(theme.motion.strikethrough.animation(reduceMotion: reduceMotion), value: done)
                }
        }
    }
}

// MARK: - Age marker

struct OrdoArcadeAgeMarker: View {
    let theme: ArcadeTheme
    let days: Int
    let triage: Bool

    var body: some View {
        Themed(theme: theme) { palette, _ in
            if days <= 0 {
                EmptyView()
            } else if triage {
                Text("\(days)D")
                    .typeToken(theme.typeScale.ageMarker)
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(palette.accentSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(palette.accent, lineWidth: 1)
                    )
                    .accessibilityLabel("carried over \(days) days, needs triage")
            } else {
                Text("\(days)D")
                    .typeToken(theme.typeScale.ageMarker)
                    .foregroundStyle(palette.ink3)
                    .accessibilityLabel("carried over \(days) days")
            }
        }
    }
}

// MARK: - Progress (compact segmented meter / expanded pixel ring)
//
// Arcade's real progress element is the header segbar; these exist for full
// `Theme` protocol conformance and any secondary call sites.

struct OrdoArcadeRing: View {
    let theme: ArcadeTheme
    let done: Int
    let total: Int
    let compact: Bool

    private var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    private var pct: Int { total > 0 ? Int((fraction * 100).rounded()) : 0 }

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            if compact {
                compactMeter(palette: palette, reduceMotion: reduceMotion)
            } else {
                expandedMeter(palette: palette, reduceMotion: reduceMotion)
            }
        }
    }

    /// A tiny segmented meter, one blocky segment per task (capped for layout),
    /// echoing the header segbar's own look.
    @ViewBuilder
    private func compactMeter(palette: Palette, reduceMotion: Bool) -> some View {
        let segCount = max(1, min(total, 10))
        let filled = total > 0 ? Int((Double(segCount) * fraction).rounded()) : 0
        HStack(spacing: 2) {
            ForEach(0..<segCount, id: \.self) { i in
                let isFilled = i < filled
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(isFilled ? palette.accent : palette.segmentBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .stroke(palette.checkRing, lineWidth: 1)
                    )
                    .shadow(color: isFilled ? palette.glow : .clear, radius: 2)
            }
        }
        .frame(height: 8)
        .animation(theme.motion.ring.animation(reduceMotion: reduceMotion), value: filled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pct) percent done, \(done) of \(total)")
    }

    /// A chunky pixel ring (butt caps, no rounded lineCap) with a pixel-font
    /// percentage — the rail/expanded equivalent of the compact meter above.
    @ViewBuilder
    private func expandedMeter(palette: Palette, reduceMotion: Bool) -> some View {
        let diameter = theme.metrics.ringRadius * 2
        let stroke = theme.metrics.ringStrokeWidth
        ZStack {
            Circle().stroke(palette.segmentBackground, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .animation(theme.motion.ring.animation(reduceMotion: reduceMotion), value: fraction)
                .shadow(color: palette.glow, radius: 6)
                .shadow(color: palette.glow, radius: 1)
            VStack(spacing: 2) {
                Text("\(pct)%")
                    .typeToken(theme.typeScale.ringNumber)
                    .foregroundStyle(palette.accent)
                Text("DONE TODAY")
                    .typeToken(theme.typeScale.ringSub)
                    .foregroundStyle(palette.ink3)
            }
        }
        .frame(width: diameter, height: diameter)
        .padding(stroke / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pct) percent done, \(done) of \(total)")
    }
}

// MARK: - Done-section header
//
// Unused in practice — Arcade dims done tasks in place with no reflow or
// separate section — but implemented for full `Theme` protocol conformance.

struct OrdoArcadeDoneHeader: View {
    let theme: ArcadeTheme
    let count: Int

    var body: some View {
        Themed(theme: theme) { palette, _ in
            HStack(spacing: 8) {
                Text("\(theme.doneSectionLabel) · \(count)")
                    .typeToken(theme.typeScale.doneHeader)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.ink3)
                Rectangle()
                    .fill(palette.divider)
                    .frame(height: palette.hairlineWidth)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - First-run empty state

struct OrdoArcadeFirstRun: View {
    let theme: ArcadeTheme

    var body: some View {
        Themed(theme: theme) { palette, _ in
            VStack(spacing: 0) {
                ArcadeBrandBlob(color: palette.accent)
                    .frame(width: 32, height: 32)
                    .shadow(color: palette.glow, radius: 6)
                    .shadow(color: palette.glow, radius: 1)
                    .padding(.bottom, 14)
                Text(theme.firstRunTitle)
                    .typeToken(theme.typeScale.emptyTitle)
                    .foregroundStyle(palette.ink)
                Text(theme.firstRunMessage)
                    .typeToken(theme.typeScale.emptyBody)
                    .foregroundStyle(palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
                    .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 26, leading: 24, bottom: 20, trailing: 24))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Victory ("STAGE CLEAR") — the all-cleared celebration screen

struct OrdoArcadeVictory: View {
    let theme: ArcadeTheme
    @State private var blink = false

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            VStack(spacing: 16) {
                ArcadeTrophyMark(coin: palette.coin, glint: palette.fieldBackground, glintOpacity: blink ? 0.25 : 1)
                    .frame(width: 66, height: 66)
                    .shadow(color: palette.coinGlow, radius: 6)
                    .shadow(color: palette.coinGlow, radius: 1)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                            blink = true
                        }
                    }
                Text(theme.allClearTitle)
                    .typeToken(ArcadeTheme.victoryTitleType)
                    .foregroundStyle(palette.coin)
                    .shadow(color: palette.coinGlow, radius: 6)
                Text(theme.allClearMessage)
                    .typeToken(theme.typeScale.emptyBody)
                    .foregroundStyle(palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 230)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.fieldBackground)
            )
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Theme conformance: view builders + menu-bar glyph

extension ArcadeTheme {
    public func checkbox(done: Bool, hover: Bool, pressed: Bool) -> AnyView {
        AnyView(OrdoArcadeCheckbox(theme: self, done: done, hover: hover, pressed: pressed))
    }

    public func taskTitle(_ text: String, done: Bool) -> AnyView {
        AnyView(OrdoArcadeTaskTitle(theme: self, text: text, done: done))
    }

    public func ageMarker(days: Int, triage: Bool) -> AnyView {
        AnyView(OrdoArcadeAgeMarker(theme: self, days: days, triage: triage))
    }

    public func progressCompact(done: Int, total: Int) -> AnyView {
        AnyView(OrdoArcadeRing(theme: self, done: done, total: total, compact: true))
    }

    public func progressRing(done: Int, total: Int) -> AnyView {
        AnyView(OrdoArcadeRing(theme: self, done: done, total: total, compact: false))
    }

    public func doneSectionHeader(count: Int) -> AnyView {
        AnyView(OrdoArcadeDoneHeader(theme: self, count: count))
    }

    public func firstRunEmptyState() -> AnyView {
        AnyView(OrdoArcadeFirstRun(theme: self))
    }

    public func allClearedState() -> AnyView {
        AnyView(OrdoArcadeVictory(theme: self))
    }

    /// The menu-bar/panel-header toggle icon — the same staircase geometry as
    /// `ArcadeCheckStaircase`, drawn with antialiasing off for crisp pixel edges.
    public func menuBarGlyphImage(pointSize: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { _ in
            let s = pointSize / 10
            let context = NSGraphicsContext.current
            let wasAntialiased = context?.shouldAntialias ?? true
            context?.shouldAntialias = false
            NSColor.black.set()
            for (x, y) in ArcadeCheckStaircase.cells {
                NSBezierPath(rect: NSRect(x: x * s, y: y * s, width: s, height: s)).fill()
            }
            context?.shouldAntialias = wasAntialiased
            return true
        }
        image.isTemplate = true
        return image
    }
}
