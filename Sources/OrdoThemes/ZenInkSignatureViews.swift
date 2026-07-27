import SwiftUI
import AppKit

// MARK: - Environment → palette bridge

/// Kept private to this file so each theme can resolve its own live palette
/// without broadening the primitive-only `Theme` signature-view contract.
private struct Themed<Content: View>: View {
    let theme: ZenInkTheme
    @ViewBuilder let content: (Palette, Bool) -> Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content(
            theme.palette(
                for: ResolvedAppearance(scheme),
                accessibility: AccessibilityOptions(
                    reduceTransparency: reduceTransparency,
                    increaseContrast: contrast == .increased
                )
            ),
            reduceMotion
        )
    }
}

/// A two-channel keyframe value for the hanko's authored scale/rotation stamp.
private struct StampValue: VectorArithmetic, Animatable {
    var scale: Double
    var rotation: Double

    static let zero = StampValue(scale: 0, rotation: 0)

    static func + (lhs: StampValue, rhs: StampValue) -> StampValue {
        StampValue(scale: lhs.scale + rhs.scale, rotation: lhs.rotation + rhs.rotation)
    }

    static func - (lhs: StampValue, rhs: StampValue) -> StampValue {
        StampValue(scale: lhs.scale - rhs.scale, rotation: lhs.rotation - rhs.rotation)
    }

    mutating func scale(by rhs: Double) {
        scale *= rhs
        rotation *= rhs
    }

    var magnitudeSquared: Double { scale * scale + rotation * rotation }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(scale, rotation) }
        set {
            scale = newValue.first
            rotation = newValue.second
        }
    }
}

private struct RoughBrushStroke: Shape {
    let kind: BrushStrokeKind

    func path(in rect: CGRect) -> Path {
        BrushStrokeShape(kind).sumiPath(in: rect)
    }
}

// MARK: - Task mark

struct OrdoZenMark: View {
    let theme: ZenInkTheme
    let done: Bool
    let hover: Bool
    let pressed: Bool

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            let sequence = theme.motion.checkboxSequence
            ZStack {
                SumiMarkRingShape()
                    .stroke(
                        done ? palette.inkFaint : (hover ? palette.ink2 : palette.checkRing),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                    )
                    .opacity(done ? 0.5 : 0.7)
                    .animation(reduceMotion ? nil : .easeOut(duration: sequence.ringFadeDuration), value: done)
                    .animation(theme.motion.hoverFade.animation(reduceMotion: reduceMotion), value: hover)

                KeyframeAnimator(initialValue: 1.0, trigger: done) { scale in
                    SumiMarkFillShape()
                        .fill(palette.ink)
                        .scaleEffect(done ? scale : 0.2)
                        .opacity(done ? 0.9 : 0)
                } keyframes: { _ in
                    if reduceMotion {
                        LinearKeyframe(1.0, duration: 0.001)
                    } else {
                        LinearKeyframe(0.2, duration: 0.001)
                        // Zero velocities prevent the 1 ms setup keyframe from overshooting.
                        CubicKeyframe(
                            1.0,
                            duration: sequence.fillDuration,
                            startVelocity: 0,
                            endVelocity: 0
                        )
                    }
                }
            }
            .frame(width: theme.metrics.checkboxSize, height: theme.metrics.checkboxSize)
            .scaleEffect(pressed ? 0.92 : (hover ? 1.035 : 1))
            .animation(theme.motion.pressEcho.animation(reduceMotion: reduceMotion), value: pressed)
            .animation(theme.motion.hoverFade.animation(reduceMotion: reduceMotion), value: hover)
            .accessibilityAddTraits(done ? [.isSelected] : [])
        }
    }
}

// MARK: - Task title

struct OrdoZenTaskTitle: View {
    let theme: ZenInkTheme
    let text: String
    let done: Bool

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            Text(text)
                .typeToken(theme.typeScale.taskTitle)
                .foregroundStyle(done ? palette.inkFaint : palette.ink)
                // A title-color fade has no useful reduced-motion form: settle
                // both ink color and strike state together when motion is off.
                .animation(reduceMotion ? nil : theme.motion.titleColorFade.standard, value: done)
                .fixedSize(horizontal: false, vertical: true)
                // Apply the flexible frame after the overlay so strike bounds match text.
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        BrushStrokeShape(.strike)
                            .fill(palette.ink3.opacity(0.85))
                            .frame(width: geometry.size.width + 6, height: 11)
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: done ? geometry.size.width + 6 : 0)
                            }
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.52)
                            // Reduce Motion must present the finished mask immediately;
                            // a 200 ms reduced token still reads as a directional draw.
                            .animation(reduceMotion ? nil : theme.motion.strikethrough.standard, value: done)
                    }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Age marker

struct OrdoZenAgeMarker: View {
    let theme: ZenInkTheme
    let days: Int
    let triage: Bool

    var body: some View {
        Themed(theme: theme) { palette, _ in
            if days > 0 {
                HStack(spacing: 3) {
                    Text("\(days)日")
                    if triage { Text("要") }
                }
                .typeToken(theme.typeScale.ageMarker)
                .foregroundStyle(triage ? palette.accent : palette.inkFaint)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(triage
                    ? "carried over \(days) days, needs triage"
                    : "carried over \(days) days")
            }
        }
    }
}

/// The mockup swaps the remaining-count glyph rather than morphing the digits:
/// old text exits upward, the value changes at 200 ms, then the new text fades
/// in. This stays deliberately local so a count change never restarts the ring.
struct ZenRemainingCount: View {
    let theme: ZenInkTheme
    let palette: Palette
    let remaining: Int
    let reduceMotion: Bool
    let typeToken: TypeToken

    @State private var displayed: Int
    @State private var opacityVisible = true
    @State private var offsetVisible = true

    init(
        theme: ZenInkTheme,
        palette: Palette,
        remaining: Int,
        reduceMotion: Bool,
        typeToken: TypeToken
    ) {
        self.theme = theme
        self.palette = palette
        self.remaining = remaining
        self.reduceMotion = reduceMotion
        self.typeToken = typeToken
        _displayed = State(initialValue: remaining)
    }

    var body: some View {
        Text("\(displayed)")
            .typeToken(typeToken)
            .foregroundStyle(palette.ink)
            .opacity(opacityVisible ? 1 : 0)
            .offset(y: offsetVisible ? 0 : -5)
            // Mockup `.count-num`: opacity settles in 220 ms, while the small
            // upward displacement continues for 260 ms.
            .animation(reduceMotion ? nil : .easeOut(duration: 0.220), value: opacityVisible)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.260), value: offsetVisible)
            .onChange(of: remaining) { _, target in
                guard !reduceMotion else {
                    displayed = target
                    opacityVisible = true
                    offsetVisible = true
                    return
                }
                opacityVisible = false
                offsetVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.200) {
                    // A later live task update owns the next swap instead of
                    // resurrecting a stale count midway through it.
                    guard remaining == target else { return }
                    displayed = target
                    opacityVisible = true
                    offsetVisible = true
                }
            }
    }
}

// MARK: - Ensō progress

struct OrdoZenEnso: View {
    let theme: ZenInkTheme
    let done: Int
    let total: Int
    let compact: Bool
    let showsCount: Bool
    let showsTrack: Bool

    init(
        theme: ZenInkTheme,
        done: Int,
        total: Int,
        compact: Bool,
        showsCount: Bool = true,
        showsTrack: Bool = true
    ) {
        self.theme = theme
        self.done = done
        self.total = total
        self.compact = compact
        self.showsCount = showsCount
        self.showsTrack = showsTrack
    }

    private var clampedDone: Int { min(max(done, 0), max(total, 0)) }
    private var remaining: Int { max(0, total - clampedDone) }
    private var fraction: Double { total > 0 ? Double(clampedDone) / Double(total) : 0 }

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            // The rail SVG is a 120-unit ensō rendered in a 132-point box.
            let diameter = compact ? theme.metrics.compactRingDiameter : 132.0
            let stroke = compact ? theme.metrics.compactRingStrokeWidth : theme.metrics.ringStrokeWidth
            ZStack {
                if showsTrack {
                    EnsoShape()
                        .stroke(palette.fieldLine, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                }
                EnsoShape(progress: fraction)
                    .stroke(palette.ink, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    // Unlike a color fade, a reduced ring animation still visibly
                    // sweeps around the ensō. Settle it in place for Reduce Motion.
                    .animation(reduceMotion ? nil : theme.motion.ring.standard, value: fraction)

                if !compact && showsCount {
                    VStack(spacing: 3) {
                        ZenRemainingCount(
                            theme: theme,
                            palette: palette,
                            remaining: remaining,
                            reduceMotion: reduceMotion,
                            typeToken: theme.typeScale.ringNumber
                        )
                        Text("REMAINING")
                            .typeToken(theme.typeScale.ringSub)
                            .foregroundStyle(palette.inkFaint)
                    }
                }
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(remaining) remaining, \(clampedDone) of \(max(total, 0)) complete")
        }
    }
}

// MARK: - Done header and empty states

struct OrdoZenDoneHeader: View {
    let theme: ZenInkTheme
    let count: Int

    var body: some View {
        Themed(theme: theme) { palette, _ in
            HStack(spacing: 8) {
                Text("\(theme.doneSectionLabel) · \(count)")
                    .typeToken(theme.typeScale.doneHeader)
                    .foregroundStyle(palette.inkFaint)
                Rectangle().fill(palette.divider).frame(height: palette.hairlineWidth)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

struct OrdoZenFirstRun: View {
    let theme: ZenInkTheme

    var body: some View {
        Themed(theme: theme) { palette, _ in
            VStack(spacing: 0) {
                OrdoZenEnso(theme: theme, done: 0, total: 0, compact: false, showsCount: false)
                    .padding(.bottom, 22)
                Text(theme.firstRunTitle)
                    .typeToken(theme.typeScale.emptyTitle)
                    .foregroundStyle(palette.ink)
                Text(theme.firstRunMessage)
                    .typeToken(theme.typeScale.emptyBody)
                    .foregroundStyle(palette.ink2)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

struct OrdoZenAllClear: View {
    let theme: ZenInkTheme
    let onPeek: () -> Void

    var body: some View {
        Themed(theme: theme) { palette, _ in
            VStack(spacing: 0) {
                // The mock hides the track to preserve the ensō's deliberate opening.
                OrdoZenEnso(
                    theme: theme,
                    done: 1,
                    total: 1,
                    compact: false,
                    showsCount: false,
                    showsTrack: false
                )
                    .padding(.bottom, 22)
                Text(theme.allClearTitle)
                    .typeToken(theme.typeScale.emptyTitle)
                    .foregroundStyle(palette.ink)
                Text(theme.allClearMessage)
                    .typeToken(theme.typeScale.emptyBody)
                    .foregroundStyle(palette.ink2)
                    .padding(.top, 10)
                Button("そっと戻る · look back", action: onPeek)
                    .typeToken(ZenInkTheme.backLinkType)
                    .foregroundStyle(palette.inkFaint)
                    .buttonStyle(.plain)
                    .padding(.top, 26)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Look back at completed tasks")
                    .accessibilityAddTraits(.isButton)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Hanko

/// Public for the Phase 5 row-trailing hook. The source path remains in its
/// native 40-unit box and is rendered at the mockup's 27-point row size.
public struct OrdoZenHanko: View {
    public let theme: ZenInkTheme
    public let done: Bool
    /// Initial completion is settled; only a live open → done transition stamps.
    @State private var stampTrigger = 0
    @State private var hasAppeared = false

    public init(theme: ZenInkTheme, done: Bool = true) {
        self.theme = theme
        self.done = done
    }

    public var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            KeyframeAnimator(initialValue: StampValue(scale: 1, rotation: -5), trigger: stampTrigger) { value in
                ZStack {
                    RoughBrushStroke(kind: .hanko)
                        .fill(palette.accent)
                    Text("済")
                        .typeToken(ZenInkTheme.sealCharType)
                        .foregroundStyle(palette.accentInk)
                        .position(x: 20, y: 27.5)
                }
                .frame(width: 40, height: 40)
                // The authored path is a 40-unit SVG, while the task-row seal is
                // 27 pt. Scale its settled geometry before applying stamp overshoot.
                .scaleEffect((done ? value.scale : 1.62) * (27.0 / 40.0))
                .rotationEffect(.degrees(done ? value.rotation : -15))
                .opacity(done ? 1 : 0)
            } keyframes: { _ in
                if reduceMotion {
                    LinearKeyframe(StampValue(scale: 1, rotation: -5), duration: 0.001)
                } else {
                    LinearKeyframe(StampValue(scale: 1.62, rotation: -15), duration: 0.001)
                    // Zero velocities prevent the 1 ms setup keyframe from overshooting.
                    CubicKeyframe(
                        StampValue(scale: 0.88, rotation: -2),
                        duration: 0.209,
                        startVelocity: .zero,
                        endVelocity: .zero
                    )
                    CubicKeyframe(
                        StampValue(scale: 1.07, rotation: -6),
                        duration: 0.0924,
                        startVelocity: .zero,
                        endVelocity: .zero
                    )
                    CubicKeyframe(
                        StampValue(scale: 1, rotation: -5),
                        duration: 0.1176,
                        startVelocity: .zero,
                        endVelocity: .zero
                    )
                }
            }
            .frame(width: 27, height: 27)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.220), value: done)
            .accessibilityHidden(true)
        }
        .onAppear {
            hasAppeared = true
        }
        .onChange(of: done) { previous, current in
            // Initial appearance is settled; only live false → true transitions stamp.
            guard hasAppeared, !previous, current else { return }
            stampTrigger &+= 1
        }
    }
}

// MARK: - Theme conformance

extension ZenInkTheme {
    public func checkbox(done: Bool, hover: Bool, pressed: Bool) -> AnyView {
        AnyView(OrdoZenMark(theme: self, done: done, hover: hover, pressed: pressed))
    }

    public func taskTitle(_ text: String, done: Bool) -> AnyView {
        AnyView(OrdoZenTaskTitle(theme: self, text: text, done: done))
    }

    public func ageMarker(days: Int, triage: Bool) -> AnyView {
        AnyView(OrdoZenAgeMarker(theme: self, days: days, triage: triage))
    }

    public func progressCompact(done: Int, total: Int) -> AnyView {
        AnyView(OrdoZenEnso(theme: self, done: done, total: total, compact: true))
    }

    public func progressRing(done: Int, total: Int) -> AnyView {
        AnyView(OrdoZenEnso(theme: self, done: done, total: total, compact: false))
    }

    public func doneSectionHeader(count: Int) -> AnyView {
        AnyView(OrdoZenDoneHeader(theme: self, count: count))
    }

    public func firstRunEmptyState() -> AnyView {
        AnyView(OrdoZenFirstRun(theme: self))
    }

    public func allClearedState() -> AnyView {
        AnyView(OrdoZenAllClear(theme: self, onPeek: {}))
    }

    public func allClearedState(onPeek: @escaping () -> Void) -> AnyView {
        AnyView(OrdoZenAllClear(theme: self, onPeek: onPeek))
    }

    public func menuBarGlyphImage(pointSize: CGFloat) -> NSImage {
        let canvas = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: canvas, flipped: true) { rect in
            let glyphSize = min(17, min(rect.width, rect.height))
            let glyphRect = CGRect(
                x: rect.midX - glyphSize / 2,
                y: rect.midY - glyphSize / 2,
                width: glyphSize,
                height: glyphSize
            )
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setShouldAntialias(true)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(2.1 * glyphSize / 24)
            context.setLineCap(.round)
            context.addPath(SumiMenuGlyphShape().path(in: glyphRect).cgPath)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}
