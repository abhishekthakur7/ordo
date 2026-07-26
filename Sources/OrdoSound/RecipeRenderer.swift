import Foundation
import OrdoThemes

// MARK: - Rendered output

/// A deterministically rendered mono PCM sound: Float32 samples at a known rate.
/// Pure DSP (no AVFoundation, I/O, or clocks) — the same recipe always renders the
/// identical sample array (deviation D1: synth at init, not assets).
public struct RenderedSound: Sendable, Hashable {
    /// Mono Float32 samples in [-1, 1].
    public let samples: [Float]
    /// Sample rate the samples were rendered at.
    public let sampleRate: Double

    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    /// Number of frames (mono → one sample per frame).
    public var frameCount: Int { samples.count }

    /// Peak absolute amplitude across the buffer (0 for silence).
    public var peak: Float {
        var m: Float = 0
        for s in samples { let a = abs(s); if a > m { m = a } }
        return m
    }

    /// True if no sample exceeds `threshold` in magnitude.
    public func isSilent(threshold: Float = 1e-5) -> Bool { peak <= threshold }
}

// MARK: - Renderer

/// Pure, engine-free synthesis of a ``SoundRecipe`` into a ``RenderedSound``. Faithful port of
/// the mockup's WebAudio recipes (`mockups/02-macos-glass.html`): exp attack/decay + glides, RBJ
/// biquad filters matching `BiquadFilterNode`, deterministic seeded-PRNG noise (reproducible).
public enum RecipeRenderer {

    /// Default render rate. 44.1 kHz matches the mockup's implied hardware rate.
    public static let defaultSampleRate: Double = 44_100

    /// Safety ceiling: rendered buffers are guaranteed to peak at or below this,
    /// leaving headroom for up to three overlapping voices at the mixer (3×~0.2 < 1).
    public static let safeCeiling: Float = 0.95

    /// Floor used for exponential envelopes (WebAudio ramps can't reach 0).
    private static let eps: Double = 0.0001

    /// Render every layer of `recipe` from a shared t0 into one mono buffer.
    /// Returns an empty buffer for an empty/zero-length recipe.
    public static func render(_ recipe: SoundRecipe, sampleRate: Double = defaultSampleRate) -> RenderedSound {
        let sr = sampleRate > 0 ? sampleRate : defaultSampleRate
        let total = recipe.duration
        let n = Int((total * sr).rounded(.up))
        guard n > 0 else { return RenderedSound(samples: [], sampleRate: sr) }

        var buf = [Double](repeating: 0, count: n)
        for component in recipe.components {
            switch component {
            case .oscillator(let o): renderOscillator(o, into: &buf, sampleRate: sr)
            case .marimba(let m): renderMarimba(m, into: &buf, sampleRate: sr)
            case .noise(let noise): renderNoise(noise, into: &buf, sampleRate: sr)
            }
        }

        // Normalize DOWN only (never amplify the intentionally gentle levels), then
        // hard-clamp for absolute safety.
        var peak = 0.0
        for v in buf { let a = abs(v); if a > peak { peak = a } }
        let ceil = Double(safeCeiling)
        let scale = peak > ceil ? ceil / peak : 1.0
        var samples = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let v = buf[i] * scale
            samples[i] = Float(min(ceil, max(-ceil, v)))
        }
        return RenderedSound(samples: samples, sampleRate: sr)
    }

    // MARK: Envelopes & curves

    /// WebAudio `exponentialRampToValueAtTime`: value at normalized fraction `f∈[0,1]`
    /// of an exponential ramp from `v0` to `v1` (both > 0).
    @inline(__always)
    private static func expRamp(_ v0: Double, _ v1: Double, _ f: Double) -> Double {
        let a = max(v0, eps)
        let b = max(v1, eps)
        let ff = min(1, max(0, f))
        return a * pow(b / a, ff)
    }

    /// Exponential attack→decay envelope. `ts` is seconds since the component's onset.
    /// Rises eps→peak across `[0, attack]`, falls peak→eps across `[attack, decayEnd]`,
    /// and is silent afterwards.
    @inline(__always)
    private static func envelope(ts: Double, attack: Double, decayEnd: Double, peak: Double) -> Double {
        if ts < 0 || ts > decayEnd { return 0 }
        var atk = attack
        if atk <= 0 { atk = 1e-6 }
        if atk >= decayEnd { atk = decayEnd * 0.5 }
        if ts <= atk {
            return expRamp(eps, peak, ts / atk)
        } else {
            return expRamp(peak, eps, (ts - atk) / (decayEnd - atk))
        }
    }

    // MARK: Waveforms (naive; frequencies are low so aliasing is negligible)

    @inline(__always)
    private static func wave(_ w: Waveform, phase: Double) -> Double {
        let p = phase - floor(phase)      // fractional phase in [0,1)
        switch w {
        case .sine:     return sin(2 * .pi * p)
        case .triangle: return 4 * abs(p - 0.5) - 1
        case .square:   return p < 0.5 ? 1 : -1
        case .sawtooth: return 2 * p - 1
        }
    }

    // MARK: Component renderers

    private static func renderOscillator(_ o: Oscillator, into buf: inout [Double], sampleRate sr: Double) {
        let start = Int((o.startDelay * sr).rounded())
        let durN = Int((o.duration * sr).rounded())
        guard durN > 0 else { return }
        var phase = 0.0
        for i in 0..<durN {
            let idx = start + i
            if idx < 0 { continue }
            if idx >= buf.count { break }
            let ts = Double(i) / sr
            let freq: Double
            if let glide = o.glideTo {
                freq = expRamp(o.frequency, glide, ts / o.duration)
            } else {
                freq = o.frequency
            }
            let env = envelope(ts: ts, attack: o.attack, decayEnd: o.duration, peak: o.peakGain)
            buf[idx] += env * wave(o.wave, phase: phase)
            phase += freq / sr
        }
    }

    private static func renderMarimba(_ m: Marimba, into buf: inout [Double], sampleRate sr: Double) {
        let start = Int((m.startDelay * sr).rounded())
        let durN = Int((m.stopTime * sr).rounded())
        guard durN > 0 else { return }

        var lp = Biquad()
        lp.setLowpass(freq: m.frequency * m.lowpassRatio, qDB: 1.0, sampleRate: sr) // WebAudio default Q (dB)

        var phase1 = 0.0
        var phase2 = 0.0
        let f1 = m.frequency
        let f2 = m.frequency * m.partialRatio
        for i in 0..<durN {
            let idx = start + i
            let ts = Double(i) / sr
            let env = envelope(ts: ts, attack: m.attack, decayEnd: m.decay, peak: m.peakGain)
            let pre = env * (wave(.triangle, phase: phase1) + m.partialGain * wave(.sine, phase: phase2))
            let out = lp.process(pre)
            if idx >= 0 && idx < buf.count { buf[idx] += out }
            phase1 += f1 / sr
            phase2 += f2 / sr
        }
    }

    private static func renderNoise(_ noise: NoiseSwoosh, into buf: inout [Double], sampleRate sr: Double) {
        let start = Int((noise.startDelay * sr).rounded())
        let nn = Int((noise.duration * sr).rounded())
        guard nn > 0 else { return }

        var rng = SplitMix64(seed: noise.seed)
        var bp = Biquad()
        let denom = Double(nn)
        for i in 0..<nn {
            let idx = start + i
            let frac = Double(i) / denom
            let center = expRamp(noise.bandpassStart, noise.bandpassEnd, frac)
            bp.setBandpass(freq: center, q: noise.q, sampleRate: sr)
            let taper = noise.amplitudeTaperLinear ? (1 - frac) : 1
            let white = (rng.nextUnit() * 2 - 1) * taper
            let filtered = bp.process(white)
            let ts = Double(i) / sr
            let env = envelope(ts: ts, attack: noise.attack, decayEnd: noise.duration, peak: noise.peakGain)
            if idx >= 0 && idx < buf.count { buf[idx] += env * filtered }
        }
    }
}

// MARK: - RBJ biquad (matches WebAudio BiquadFilterNode coefficient math)

/// Transposed Direct-Form II biquad. Coefficients follow the Audio-EQ-Cookbook /
/// WebAudio spec so filtered output matches the mockup's `BiquadFilterNode`.
struct Biquad {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var z1 = 0.0, z2 = 0.0

    @inline(__always)
    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    /// Lowpass. WebAudio interprets Q in **decibels** for low/high-pass.
    mutating func setLowpass(freq: Double, qDB: Double, sampleRate sr: Double) {
        let w0 = 2 * Double.pi * clampFreq(freq, sr) / sr
        let cw = cos(w0), sw = sin(w0)
        let alpha = sw / (2 * pow(10, qDB / 20))
        let a0 = 1 + alpha
        b0 = ((1 - cw) / 2) / a0
        b1 = (1 - cw) / a0
        b2 = ((1 - cw) / 2) / a0
        a1 = (-2 * cw) / a0
        a2 = (1 - alpha) / a0
    }

    /// Bandpass (constant 0 dB peak gain). WebAudio uses **linear** Q for bandpass.
    mutating func setBandpass(freq: Double, q: Double, sampleRate sr: Double) {
        let w0 = 2 * Double.pi * clampFreq(freq, sr) / sr
        let cw = cos(w0), sw = sin(w0)
        let qq = max(q, 1e-4)
        let alpha = sw / (2 * qq)
        let a0 = 1 + alpha
        b0 = alpha / a0
        b1 = 0
        b2 = -alpha / a0
        a1 = (-2 * cw) / a0
        a2 = (1 - alpha) / a0
    }

    @inline(__always)
    private func clampFreq(_ f: Double, _ sr: Double) -> Double {
        min(max(f, 10), sr * 0.45)
    }
}

// MARK: - Deterministic PRNG

/// SplitMix64 — small, fast, deterministic. Seeded from recipe parameters so a
/// given noise component always renders the identical sample sequence.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    @inline(__always)
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [0, 1).
    @inline(__always)
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

private extension NoiseSwoosh {
    /// Stable seed derived from the swoosh's parameters (identical recipe → identical noise).
    var seed: UInt64 {
        var h: UInt64 = 0xD1CE4E5B9F4A7C15
        for value in [bandpassStart, bandpassEnd, duration, peakGain, q, startDelay] {
            h ^= value.bitPattern
            h = h &* 0x100000001B3
        }
        return h == 0 ? 0x9E3779B97F4A7C15 : h
    }
}
