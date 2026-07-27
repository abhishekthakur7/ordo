import SwiftUI

/// The three signature easing curves from the mockup, plus linear. Values are the
/// exact `cubic-bezier` control points.
public enum MotionCurve: Sendable, Hashable {
    /// `cubic-bezier(0.23, 1, 0.32, 1)` — the workhorse "settle" curve.
    case easeOut
    /// `cubic-bezier(0.32, 0.72, 0, 1)` — drawer/morph curve (expand, thumb, FLIP, ring).
    case easeDrawer
    /// `cubic-bezier(0.77, 0, 0.175, 1)` — symmetric in/out.
    case easeIO
    /// Linear timing.
    case linear
    /// A stepped/quantized curve holding at `n` discrete positions (used by the
    /// pixel checkbox tick and the SFX knob). Not a cubic bezier — use
    /// `stepCount` with a `KeyframeAnimator` for the true discrete hold.
    case steps(Int)

    /// The cubic-bezier control points, or nil for linear/steps (neither is a bezier).
    public var controlPoints: (Double, Double, Double, Double)? {
        switch self {
        case .easeOut: return (0.23, 1, 0.32, 1)
        case .easeDrawer: return (0.32, 0.72, 0, 1)
        case .easeIO: return (0.77, 0, 0.175, 1)
        case .linear: return nil
        case .steps: return nil
        }
    }

    /// The number of discrete steps for `.steps(n)`, else nil. Drive a
    /// `KeyframeAnimator` with this many holds for true quantized motion.
    public var stepCount: Int? {
        if case .steps(let n) = self { return n }
        return nil
    }

    /// A SwiftUI `Animation` for this curve at the given duration. For
    /// `.steps(n)` this returns a smooth `.linear` fallback, not a true
    /// stepped motion — use `stepCount` with a `KeyframeAnimator` for that.
    public func animation(duration: Double) -> Animation {
        if let p = controlPoints {
            return .timingCurve(p.0, p.1, p.2, p.3, duration: duration)
        }
        return .linear(duration: duration)
    }
}

/// A single animated moment: duration, curve and optional delay, with a
/// Reduce-Motion variant baked in. Reduced motion replaces throws/springs/travel
/// with a short in-place fade (ARCHITECTURE §4.6).
public struct MotionToken: Sendable, Hashable {
    public var duration: Double
    public var curve: MotionCurve
    public var delay: Double

    public init(_ duration: Double, _ curve: MotionCurve, delay: Double = 0) {
        self.duration = duration
        self.curve = curve
        self.delay = delay
    }

    /// The full-motion animation.
    public var standard: Animation {
        curve.animation(duration: duration).delay(delay)
    }

    /// Duration used by the reduced (fade) variant — capped so long throws become brief.
    public var reducedDuration: Double { min(duration, 0.2) }

    /// The Reduce-Motion animation: a plain in-place ease-out fade, no delay, no overshoot.
    public var reduced: Animation {
        .easeOut(duration: reducedDuration)
    }

    /// Pick the right animation for the current accessibility state.
    public func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : standard
    }
}

/// The checkbox completion choreography (the hero moment). Timings are exact from
/// the mockup's WAAPI keyframes and `setTimeout`s.
public struct CheckboxSequence: Sendable, Hashable {
    /// One scale keyframe: target `scale` reached at `fraction` of `fillDuration`.
    public struct FillKeyframe: Sendable, Hashable {
        public var scale: Double
        public var fraction: Double
        public init(scale: Double, fraction: Double) {
            self.scale = scale
            self.fraction = fraction
        }
    }

    /// Fill grow-and-settle duration (380 ms).
    public var fillDuration: Double
    /// Overshoot keyframes: 0.1 → 1.16 (0.55) → 0.94 (0.78) → 1.0.
    public var fillKeyframes: [FillKeyframe]
    /// Tick stroke draw duration (260 ms).
    public var tickDrawDuration: Double
    /// Tick draw start delay after the fill begins (40 ms).
    public var tickDrawDelay: Double
    /// Fill opacity fade duration (200 ms).
    public var fillFadeDuration: Double
    /// Ring dissolve duration when completing (200 ms).
    public var ringFadeDuration: Double
    /// Delay before the completed row reflows into the done section (470 ms).
    public var completeReflowDelay: Double
    /// Delay before an unchecked row reflows back (230 ms).
    public var uncheckReflowDelay: Double

    public init(
        fillDuration: Double,
        fillKeyframes: [FillKeyframe],
        tickDrawDuration: Double,
        tickDrawDelay: Double,
        fillFadeDuration: Double,
        ringFadeDuration: Double,
        completeReflowDelay: Double,
        uncheckReflowDelay: Double
    ) {
        self.fillDuration = fillDuration
        self.fillKeyframes = fillKeyframes
        self.tickDrawDuration = tickDrawDuration
        self.tickDrawDelay = tickDrawDelay
        self.fillFadeDuration = fillFadeDuration
        self.ringFadeDuration = ringFadeDuration
        self.completeReflowDelay = completeReflowDelay
        self.uncheckReflowDelay = uncheckReflowDelay
    }
}

/// Row entrance transform: new rows fade in from `translateY`, `scale`, and
/// an optional blur. The blur defaults to zero so existing themes retain their
/// current transition exactly.
public struct RowEntranceTransform: Sendable, Hashable {
    public var translateY: Double  // -8 px
    public var scale: Double       // 0.96
    public var duration: Double    // 360 ms
    public var blur: Double        // 0 = no blur

    public init(translateY: Double, scale: Double, duration: Double, blur: Double = 0) {
        self.translateY = translateY
        self.scale = scale
        self.duration = duration
        self.blur = blur
    }
}

/// Every animated moment in the theme, each a `MotionToken` with a Reduce-Motion
/// variant, plus the raw curves and the checkbox/row keyframe specs.
public struct Motion: Sendable, Hashable {
    // Raw curves for anything bespoke.
    public var easeOut: MotionCurve
    public var easeDrawer: MotionCurve
    public var easeIO: MotionCurve

    // Named moments (durations from the mockup).
    public var panelEnter: MotionToken          // 340ms ease-out
    public var panelExit: MotionToken           // 220ms ease-out
    /// Entrance blur in points for opaque surfaces. The default preserves the
    /// existing unblurred macOS and Arcade panel animation.
    public var panelEnterBlur: Double
    /// Exit blur in points for opaque surfaces. Disabled under Reduce Motion.
    public var panelExitBlur: Double
    public var expandMorph: MotionToken         // 520ms ease-drawer
    public var tabThumb: MotionToken            // 460ms ease-drawer
    public var appearanceThumb: MotionToken     // 420ms ease-drawer (footer .seg-thumb2)
    public var soundKnob: MotionToken           // 320ms ease-drawer (footer .sw .knob)
    public var checkboxFill: MotionToken        // 380ms ease-out
    public var tickDraw: MotionToken            // 260ms ease-out, delay 40ms
    public var strikethrough: MotionToken       // 340ms ease-out
    public var titleColorFade: MotionToken      // 300ms ease-out
    public var rowEntrance: MotionToken         // 360ms ease-out
    public var flipMove: MotionToken            // 440ms ease-drawer
    public var ring: MotionToken                // 700ms ease-drawer
    public var appearanceCrossfade: MotionToken // 600ms ease-out
    public var hoverFade: MotionToken           // 160ms ease-out (row hover background)
    public var pressEcho: MotionToken           // 130ms ease-out (active/press transforms)
    public var counterFade: MotionToken         // 200ms ease-out (field / character counter)

    // Keyframe specs.
    public var checkboxSequence: CheckboxSequence
    public var rowEntranceTransform: RowEntranceTransform

    public init(
        easeOut: MotionCurve, easeDrawer: MotionCurve, easeIO: MotionCurve,
        panelEnter: MotionToken, panelExit: MotionToken, expandMorph: MotionToken,
        tabThumb: MotionToken, appearanceThumb: MotionToken, soundKnob: MotionToken,
        checkboxFill: MotionToken, tickDraw: MotionToken,
        strikethrough: MotionToken, titleColorFade: MotionToken, rowEntrance: MotionToken,
        flipMove: MotionToken, ring: MotionToken, appearanceCrossfade: MotionToken,
        hoverFade: MotionToken, pressEcho: MotionToken, counterFade: MotionToken,
        checkboxSequence: CheckboxSequence, rowEntranceTransform: RowEntranceTransform,
        panelEnterBlur: Double = 0, panelExitBlur: Double = 0
    ) {
        self.easeOut = easeOut
        self.easeDrawer = easeDrawer
        self.easeIO = easeIO
        self.panelEnter = panelEnter
        self.panelExit = panelExit
        self.panelEnterBlur = panelEnterBlur
        self.panelExitBlur = panelExitBlur
        self.expandMorph = expandMorph
        self.tabThumb = tabThumb
        self.appearanceThumb = appearanceThumb
        self.soundKnob = soundKnob
        self.checkboxFill = checkboxFill
        self.tickDraw = tickDraw
        self.strikethrough = strikethrough
        self.titleColorFade = titleColorFade
        self.rowEntrance = rowEntrance
        self.flipMove = flipMove
        self.ring = ring
        self.appearanceCrossfade = appearanceCrossfade
        self.hoverFade = hoverFade
        self.pressEcho = pressEcho
        self.counterFade = counterFade
        self.checkboxSequence = checkboxSequence
        self.rowEntranceTransform = rowEntranceTransform
    }

    /// Panel blur is never animated when Reduce Motion is enabled. Consumers
    /// should use this accessor rather than reading the raw token at render time.
    public func panelBlur(entering: Bool, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        return entering ? panelEnterBlur : panelExitBlur
    }
}
