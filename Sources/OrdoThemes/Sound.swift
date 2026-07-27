import Foundation

// MARK: - Sound seam (contract C2)
//
// OrdoThemes defines the declarative recipes + seam (SoundEvent, SoundPlaying);
// OrdoSound renders them to PCM. OrdoUI/OrdoApp trigger sound only through
// `SoundPlaying` — they never touch AVFoundation.

/// The eight sound moments every theme provides a recipe for.
public enum SoundEvent: String, CaseIterable, Sendable, Hashable {
    case complete
    case uncheck
    case add
    case tabSwitch
    case panelOpen
    case panelClose
    case toggleOn
    case toggleOff
}

/// The trigger seam. Implemented by OrdoSound; called by OrdoUI/OrdoApp.
/// `isEnabled` is the global sound on/off flag (default on). When disabled,
/// `play` is a no-op. A missing/unrenderable recipe is a silent no-op, never an error.
public protocol SoundPlaying: AnyObject {
    /// Global on/off. Instant and global; setting it never plays a sound itself.
    var isEnabled: Bool { get set }
    /// Play the recipe for `event` (respecting `isEnabled` and voice stealing).
    func play(_ event: SoundEvent)
    /// Replace the declarative sound set used for future events. Implementations that
    /// cannot change sounds live may safely ignore this request.
    func updateSoundSet(_ soundSet: SoundSet)
}

public extension SoundPlaying {
    /// Compatibility default for lightweight players and existing conformers.
    func updateSoundSet(_ soundSet: SoundSet) {}
}

// MARK: - Declarative recipe model

/// Oscillator waveform. Rich enough for future themes (8-bit `square` blips, etc.).
public enum Waveform: String, Sendable, Hashable {
    case sine
    case triangle
    case square
    case sawtooth
}

/// A single tone: one oscillator with an optional exponential frequency glide and
/// an exponential attack/decay envelope. Mirrors the mockup's `tone()` helper.
public struct Oscillator: Sendable, Hashable {
    public var wave: Waveform
    /// Start offset from the event's t0, in seconds.
    public var startDelay: Double
    /// Starting frequency in Hz.
    public var frequency: Double
    /// Exponential glide target reached at `startDelay + duration`, or nil for none.
    public var glideTo: Double?
    /// Sounding duration in seconds (gain decays to ~0 by the end).
    public var duration: Double
    /// Peak linear gain reached at the end of `attack`.
    public var peakGain: Double
    /// Exponential attack time in seconds.
    public var attack: Double
    public init(
        wave: Waveform,
        startDelay: Double = 0,
        frequency: Double,
        glideTo: Double? = nil,
        duration: Double,
        peakGain: Double,
        attack: Double = 0.008
    ) {
        self.wave = wave
        self.startDelay = startDelay
        self.frequency = frequency
        self.glideTo = glideTo
        self.duration = duration
        self.peakGain = peakGain
        self.attack = attack
    }
}

/// A marimba-style composite: a triangle fundamental plus a sine partial, summed
/// and passed through a lowpass. Mirrors the mockup's `marimba()` helper.
public struct Marimba: Sendable, Hashable {
    public var startDelay: Double
    /// Fundamental frequency in Hz.
    public var frequency: Double
    /// Peak linear gain of the summed envelope.
    public var peakGain: Double
    /// Exponential attack time (0.006).
    public var attack: Double
    /// Exponential decay time to ~0 (0.42).
    public var decay: Double
    /// Oscillator stop time after start (0.46).
    public var stopTime: Double
    /// Sine partial frequency as a ratio of the fundamental (2.01).
    public var partialRatio: Double
    /// Gain of the sine partial before summing (0.28).
    public var partialGain: Double
    /// Lowpass cutoff as a ratio of the fundamental (4.2).
    public var lowpassRatio: Double

    public init(
        startDelay: Double = 0,
        frequency: Double,
        peakGain: Double,
        attack: Double = 0.006,
        decay: Double = 0.42,
        stopTime: Double = 0.46,
        partialRatio: Double = 2.01,
        partialGain: Double = 0.28,
        lowpassRatio: Double = 4.2
    ) {
        self.startDelay = startDelay
        self.frequency = frequency
        self.peakGain = peakGain
        self.attack = attack
        self.decay = decay
        self.stopTime = stopTime
        self.partialRatio = partialRatio
        self.partialGain = partialGain
        self.lowpassRatio = lowpassRatio
    }
}

/// A filtered noise swoosh: white noise, linearly tapered across the buffer, through
/// a bandpass whose center frequency sweeps. Mirrors the mockup's `noiseSwoosh()`.
public struct NoiseSwoosh: Sendable, Hashable {
    public var startDelay: Double
    public var duration: Double
    /// Peak linear gain reached at the end of `attack`.
    public var peakGain: Double
    /// Bandpass center at the start (Hz).
    public var bandpassStart: Double
    /// Bandpass center at the end (Hz), reached by exponential ramp.
    public var bandpassEnd: Double
    /// Bandpass Q (0.8).
    public var q: Double
    /// Exponential attack time (0.03).
    public var attack: Double
    /// Whether the buffer amplitude tapers linearly from 1→0 across its length.
    public var amplitudeTaperLinear: Bool

    public init(
        startDelay: Double = 0,
        duration: Double,
        peakGain: Double,
        bandpassStart: Double,
        bandpassEnd: Double,
        q: Double = 0.8,
        attack: Double = 0.03,
        amplitudeTaperLinear: Bool = true
    ) {
        self.startDelay = startDelay
        self.duration = duration
        self.peakGain = peakGain
        self.bandpassStart = bandpassStart
        self.bandpassEnd = bandpassEnd
        self.q = q
        self.attack = attack
        self.amplitudeTaperLinear = amplitudeTaperLinear
    }

    /// Convenience for the mockup's rising (400→1400) / falling (1200→420) sweeps.
    public static func rising(startDelay: Double = 0, duration: Double, peakGain: Double) -> NoiseSwoosh {
        NoiseSwoosh(startDelay: startDelay, duration: duration, peakGain: peakGain,
                    bandpassStart: 400, bandpassEnd: 1400)
    }
    public static func falling(startDelay: Double = 0, duration: Double, peakGain: Double) -> NoiseSwoosh {
        NoiseSwoosh(startDelay: startDelay, duration: duration, peakGain: peakGain,
                    bandpassStart: 1200, bandpassEnd: 420)
    }
}

/// A koto-style pluck: three inharmonic partials through a swept lowpass, with a
/// short high-passed noise pick. Defaults transcribe Zen Ink's `pluck()` helper.
public struct Pluck: Sendable, Hashable {
    /// Start offset from the event's t0, in seconds.
    public var startDelay: Double
    /// Fundamental frequency in Hz.
    public var frequency: Double
    /// Peak gain of the triangle fundamental.
    public var peakGain: Double
    /// Fundamental decay time to near silence.
    public var duration: Double
    /// Exponential attack time in seconds.
    public var attack: Double
    /// Frequency ratio of the second sine partial (2.003).
    public var secondPartialRatio: Double
    /// Gain of the second sine partial relative to the fundamental (0.32).
    public var secondPartialGain: Double
    /// Frequency ratio of the third sine partial (3.01).
    public var thirdPartialRatio: Double
    /// Gain of the third sine partial relative to the fundamental (0.12).
    public var thirdPartialGain: Double
    /// Extra decay reduction per partial-frequency multiple (0.15).
    public var partialDecayPerMultiplier: Double
    /// Lowpass cutoff at onset, in Hz.
    public var lowpassStart: Double
    /// Lowpass cutoff after `lowpassSweepDuration`, in Hz.
    public var lowpassEnd: Double
    /// Duration of the lowpass cutoff sweep, in seconds.
    public var lowpassSweepDuration: Double
    /// Noise-pick highpass cutoff, in Hz.
    public var pickHighpass: Double
    /// Noise-pick peak gain.
    public var pickGain: Double
    /// Noise-pick duration, in seconds.
    public var pickDuration: Double
    /// Noise-pick attack time, in seconds.
    public var pickAttack: Double

    public init(
        startDelay: Double = 0,
        frequency: Double,
        peakGain: Double,
        duration: Double,
        attack: Double = 0.005,
        secondPartialRatio: Double = 2.003,
        secondPartialGain: Double = 0.32,
        thirdPartialRatio: Double = 3.01,
        thirdPartialGain: Double = 0.12,
        partialDecayPerMultiplier: Double = 0.15,
        lowpassStart: Double = 4_200,
        lowpassEnd: Double = 900,
        lowpassSweepDuration: Double = 0.45,
        pickHighpass: Double = 2_000,
        pickGain: Double = 0.06,
        pickDuration: Double = 0.05,
        pickAttack: Double = 0.002
    ) {
        self.startDelay = startDelay
        self.frequency = frequency
        self.peakGain = peakGain
        self.duration = duration
        self.attack = attack
        self.secondPartialRatio = secondPartialRatio
        self.secondPartialGain = secondPartialGain
        self.thirdPartialRatio = thirdPartialRatio
        self.thirdPartialGain = thirdPartialGain
        self.partialDecayPerMultiplier = partialDecayPerMultiplier
        self.lowpassStart = lowpassStart
        self.lowpassEnd = lowpassEnd
        self.lowpassSweepDuration = lowpassSweepDuration
        self.pickHighpass = pickHighpass
        self.pickGain = pickGain
        self.pickDuration = pickDuration
        self.pickAttack = pickAttack
    }
}

/// One layer of a recipe.
public enum SoundComponent: Sendable, Hashable {
    case oscillator(Oscillator)
    case marimba(Marimba)
    case noise(NoiseSwoosh)
    case pluck(Pluck)

    /// Longest time this component occupies, for buffer sizing.
    public var tailTime: Double {
        switch self {
        case .oscillator(let o): return o.startDelay + o.duration + 0.02
        case .marimba(let m): return m.startDelay + m.stopTime
        case .noise(let n): return n.startDelay + n.duration + 0.02
        case .pluck(let p): return p.startDelay + max(p.duration, p.pickDuration) + 0.02
        }
    }
}

/// A full sound: a set of layers rendered together from a shared t0.
public struct SoundRecipe: Sendable, Hashable {
    public var components: [SoundComponent]

    public init(_ components: [SoundComponent]) {
        self.components = components
    }

    /// Total buffer length needed to render every layer's tail.
    public var duration: Double {
        components.map(\.tailTime).max() ?? 0
    }
}

/// A theme's complete mapping of events → recipes.
public struct SoundSet: Sendable, Hashable {
    private var recipeVariants: [SoundEvent: [SoundRecipe]]

    /// Compatibility initializer for themes with one recipe per event.
    public init(_ recipes: [SoundEvent: SoundRecipe]) {
        self.recipeVariants = recipes.mapValues { [$0] }
    }

    /// Initializes a set with optional per-event variants. The sound engine cycles
    /// variants in declaration order; callers that need one sound can keep using
    /// the unlabeled initializer above.
    public init(variants: [SoundEvent: [SoundRecipe]]) {
        self.recipeVariants = variants.filter { !$0.value.isEmpty }
    }

    /// The first variant, preserving the historic single-recipe API.
    public func recipe(for event: SoundEvent) -> SoundRecipe? {
        recipeVariants[event]?.first
    }

    public subscript(_ event: SoundEvent) -> SoundRecipe? {
        recipe(for: event)
    }

    /// All recipes available for an event, in deterministic round-robin order.
    public func variants(for event: SoundEvent) -> [SoundRecipe] {
        recipeVariants[event] ?? []
    }

    /// Events that have a recipe.
    public var events: [SoundEvent] {
        SoundEvent.allCases.filter { !(recipeVariants[$0]?.isEmpty ?? true) }
    }
}
