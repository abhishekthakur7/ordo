import SwiftUI
import AppKit

// MARK: - Environment → palette bridge

/// Reads the live appearance + accessibility environment and hands the resolved
/// palette (and Reduce-Motion flag) to its content. Keeps every signature view's
/// parameters primitives-only while still honoring System/Light/Dark and a11y.
private struct Themed<Content: View>: View {
    let theme: MacOSTheme
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

// MARK: - Shapes

/// The checkmark path in the mockup's 22×22 space: `M6 11.4 L9.1 14.5 L16 7.4`.
struct CheckTickShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 22
        var p = Path()
        p.move(to: CGPoint(x: 6 * s, y: 11.4 * s))
        p.addLine(to: CGPoint(x: 9.1 * s, y: 14.5 * s))
        p.addLine(to: CGPoint(x: 16 * s, y: 7.4 * s))
        return p
    }
}

// MARK: - Checkbox (the hero)

struct OrdoCheckbox: View {
    let theme: MacOSTheme
    let done: Bool
    let hover: Bool
    let pressed: Bool

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            let seq = theme.motion.checkboxSequence
            let size = theme.metrics.checkboxSize

            ZStack {
                // Ring — dissolves as the fill takes over.
                Circle()
                    .strokeBorder(hover ? palette.accent : palette.checkRing, lineWidth: 1.6)
                    .opacity(done ? 0 : 1)
                    .animation(.easeOut(duration: seq.ringFadeDuration), value: done)
                    // Mockup: .cb-ring box-shadow transitions at 200ms on hover.
                    .animation(.easeInOut(duration: 0.2), value: hover)

                // Fill — springy overshoot 0.1 → 1.16 → 0.94 → 1.
                KeyframeAnimator(initialValue: 1.0, trigger: done) { scale in
                    Circle()
                        .fill(palette.accent)
                        .scaleEffect(done ? scale : 0.1)
                        .opacity(done ? 1 : 0)
                        .animation(.easeOut(duration: reduceMotion ? 0.12 : seq.fillFadeDuration), value: done)
                } keyframes: { _ in
                    if reduceMotion {
                        LinearKeyframe(1.0, duration: seq.fillDuration)
                    } else {
                        LinearKeyframe(0.10, duration: 0.001)
                        CubicKeyframe(1.16, duration: seq.fillDuration * 0.55)
                        CubicKeyframe(0.94, duration: seq.fillDuration * (0.78 - 0.55))
                        CubicKeyframe(1.00, duration: seq.fillDuration * (1 - 0.78))
                    }
                }

                // Tick — draws in after 40 ms.
                CheckTickShape()
                    .trim(from: 0, to: done ? 1 : 0)
                    .stroke(palette.accentInk,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .animation(theme.motion.tickDraw.animation(reduceMotion: reduceMotion), value: done)
            }
            .frame(width: size, height: size)
            .scaleEffect(pressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: pressed)
            .accessibilityAddTraits(done ? [.isSelected] : [])
        }
    }
}

// MARK: - Task title (strikethrough draw + color fade)

struct OrdoTaskTitle: View {
    let theme: MacOSTheme
    let text: String
    let done: Bool

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            Text(text)
                .typeToken(theme.typeScale.taskTitle)
                .foregroundStyle(done ? palette.ink3 : palette.ink)
                .animation(theme.motion.titleColorFade.animation(reduceMotion: reduceMotion), value: done)
                .fixedSize(horizontal: false, vertical: true)
                // Fill the title column so the rule spans its full width, not just the
                // glyph run (mockup .t-title is flex:1; its ::after is width:100%).
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(palette.ink3)
                            .frame(width: geo.size.width, height: 1.4)
                            // Draw across the full column from the leading edge (scaleX,
                            // 340ms ease-out); Reduce-Motion shows it without the draw.
                            .scaleEffect(x: reduceMotion ? 1 : (done ? 1 : 0), anchor: .leading)
                            .opacity(done ? 1 : 0)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .allowsHitTesting(false)
                    .animation(theme.motion.strikethrough.animation(reduceMotion: reduceMotion), value: done)
                }
        }
    }
}

// MARK: - Age marker

struct OrdoAgeMarker: View {
    let theme: MacOSTheme
    let days: Int
    let triage: Bool

    var body: some View {
        Themed(theme: theme) { palette, _ in
            if days <= 0 {
                EmptyView()
            } else {
                Text("\(days)d")
                    .typeToken(theme.typeScale.ageMarker)
                    .monospacedDigit()
                    .foregroundStyle(triage ? palette.accent : palette.ink3)
                    .padding(.horizontal, triage ? 6 : 0)
                    .padding(.vertical, triage ? 2 : 0)
                    .background {
                        if triage { Capsule().fill(palette.accentSoft) }
                    }
                    .accessibilityLabel(triage
                        ? "carried over \(days) days, needs triage"
                        : "carried over \(days) days")
            }
        }
    }
}

// MARK: - Progress (ring)

struct OrdoRing: View {
    let theme: MacOSTheme
    let done: Int
    let total: Int
    let compact: Bool

    private var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    private var pct: Int { total > 0 ? Int((Double(done) / Double(total) * 100).rounded()) : 0 }

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            let diameter = compact ? theme.metrics.compactRingDiameter : theme.metrics.ringRadius * 2
            let stroke = compact ? theme.metrics.compactRingStrokeWidth : theme.metrics.ringStrokeWidth

            ZStack {
                Circle().stroke(palette.inkFaint, lineWidth: stroke)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(palette.accent,
                            style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(theme.motion.ring.animation(reduceMotion: reduceMotion), value: fraction)

                if !compact {
                    VStack(spacing: 1) {
                        Text("\(pct)%")
                            .typeToken(theme.typeScale.ringNumber)
                            .foregroundStyle(palette.ink)
                        Text("done today")
                            .typeToken(theme.typeScale.ringSub)
                            .foregroundStyle(palette.ink3)
                    }
                }
            }
            .frame(width: diameter, height: diameter)
            .padding(stroke / 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pct) percent done, \(done) of \(total)")
        }
    }
}

// MARK: - Done-section header

struct OrdoDoneHeader: View {
    let theme: MacOSTheme
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

struct OrdoFirstRun: View {
    let theme: MacOSTheme

    var body: some View {
        Themed(theme: theme) { palette, _ in
            VStack(spacing: 0) {
                OrdoMark(color: palette.accent)
                    .frame(width: 44, height: 44)
                    .opacity(0.9)
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

// MARK: - All-cleared state (pulsing sun)

struct OrdoAllClear: View {
    let theme: MacOSTheme
    @State private var pulse = false

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            VStack(spacing: 0) {
                SunMark(accent: palette.accent)
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulse ? 1.06 : 1.0)
                    .padding(.bottom, 14)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                Text(theme.allClearTitle)
                    .typeToken(theme.typeScale.emptyTitle)
                    .foregroundStyle(palette.ink)
                Text(theme.allClearMessage)
                    .typeToken(theme.typeScale.emptyBody)
                    .foregroundStyle(palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
                    .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 26, leading: 24, bottom: 20, trailing: 24))
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

/// The all-clear sun (mockup 48-unit geometry): accent core, eight rays, white check.
struct SunMark: View {
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 48
            func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            ctx.fill(Path(ellipseIn: CGRect(x: 15 * s, y: 15 * s, width: 18 * s, height: 18 * s)),
                     with: .color(accent))

            var rays = Path()
            func ray(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
                rays.move(to: P(a, b)); rays.addLine(to: P(c, d))
            }
            ray(24, 6, 24, 10); ray(24, 38, 24, 42)
            ray(6, 24, 10, 24); ray(38, 24, 42, 24)
            ray(11, 11, 13.8, 13.8); ray(34.2, 34.2, 37, 37)
            ray(37, 11, 34.2, 13.8); ray(13.8, 34.2, 11, 37)
            ctx.stroke(rays, with: .color(accent),
                       style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))

            var chk = Path()
            chk.move(to: P(20, 24)); chk.addLine(to: P(22.8, 26.8)); chk.addLine(to: P(28.5, 21))
            ctx.stroke(chk, with: .color(.white),
                       style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round, lineJoin: .round))
        }
    }
}

/// The Ordo "ordered list" mark (mockup 24-unit glyph geometry), used in the first-run
/// state. Same geometry as the menu-bar glyph.
struct OrdoMark: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 24
            ctx.fill(Path(ellipseIn: CGRect(x: (5 - 1.6) * s, y: (6.5 - 1.6) * s, width: 3.2 * s, height: 3.2 * s)),
                     with: .color(color))
            ctx.fill(Path(roundedRect: CGRect(x: 9.5 * s, y: 5.4 * s, width: 9.5 * s, height: 2.2 * s),
                          cornerRadius: 1.1 * s), with: .color(color))
            ctx.fill(Path(ellipseIn: CGRect(x: (5 - 1.6) * s, y: (12 - 1.6) * s, width: 3.2 * s, height: 3.2 * s)),
                     with: .color(color))
            ctx.fill(Path(roundedRect: CGRect(x: 9.5 * s, y: 10.9 * s, width: 9.5 * s, height: 2.2 * s),
                          cornerRadius: 1.1 * s), with: .color(color))
            var chk = Path()
            chk.move(to: CGPoint(x: 3.6 * s, y: 17.4 * s))
            chk.addLine(to: CGPoint(x: 4.7 * s, y: 18.6 * s))
            chk.addLine(to: CGPoint(x: 6.7 * s, y: 16.2 * s))
            ctx.stroke(chk, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round, lineJoin: .round))
            ctx.fill(Path(roundedRect: CGRect(x: 9.5 * s, y: 16.4 * s, width: 6.5 * s, height: 2.2 * s),
                          cornerRadius: 1.1 * s), with: .color(color))
        }
    }
}

// MARK: - Theme conformance: view builders + menu-bar glyph

extension MacOSTheme {
    public func checkbox(done: Bool, hover: Bool, pressed: Bool) -> AnyView {
        AnyView(OrdoCheckbox(theme: self, done: done, hover: hover, pressed: pressed))
    }

    public func taskTitle(_ text: String, done: Bool) -> AnyView {
        AnyView(OrdoTaskTitle(theme: self, text: text, done: done))
    }

    public func ageMarker(days: Int, triage: Bool) -> AnyView {
        AnyView(OrdoAgeMarker(theme: self, days: days, triage: triage))
    }

    public func progressCompact(done: Int, total: Int) -> AnyView {
        AnyView(OrdoRing(theme: self, done: done, total: total, compact: true))
    }

    public func progressRing(done: Int, total: Int) -> AnyView {
        AnyView(OrdoRing(theme: self, done: done, total: total, compact: false))
    }

    public func doneSectionHeader(count: Int) -> AnyView {
        AnyView(OrdoDoneHeader(theme: self, count: count))
    }

    public func firstRunEmptyState() -> AnyView {
        AnyView(OrdoFirstRun(theme: self))
    }

    public func allClearedState() -> AnyView {
        AnyView(OrdoAllClear(theme: self))
    }

    public func menuBarGlyphImage(pointSize: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { _ in
            let s = pointSize / 24
            NSColor.black.set()

            NSBezierPath(ovalIn: NSRect(x: (5 - 1.6) * s, y: (6.5 - 1.6) * s, width: 3.2 * s, height: 3.2 * s)).fill()
            NSBezierPath(roundedRect: NSRect(x: 9.5 * s, y: 5.4 * s, width: 9.5 * s, height: 2.2 * s),
                         xRadius: 1.1 * s, yRadius: 1.1 * s).fill()
            NSBezierPath(ovalIn: NSRect(x: (5 - 1.6) * s, y: (12 - 1.6) * s, width: 3.2 * s, height: 3.2 * s)).fill()
            NSBezierPath(roundedRect: NSRect(x: 9.5 * s, y: 10.9 * s, width: 9.5 * s, height: 2.2 * s),
                         xRadius: 1.1 * s, yRadius: 1.1 * s).fill()

            let check = NSBezierPath()
            check.move(to: NSPoint(x: 3.6 * s, y: 17.4 * s))
            check.line(to: NSPoint(x: 4.7 * s, y: 18.6 * s))
            check.line(to: NSPoint(x: 6.7 * s, y: 16.2 * s))
            check.lineWidth = 1.7 * s
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()

            NSBezierPath(roundedRect: NSRect(x: 9.5 * s, y: 16.4 * s, width: 6.5 * s, height: 2.2 * s),
                         xRadius: 1.1 * s, yRadius: 1.1 * s).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
