import XCTest
@testable import OrdoSound
// OrdoThemes types (SoundRecipe, MacOSTheme, ...) are re-exported by OrdoSound.

final class RecipeRendererTests: XCTestCase {

    private let sr = RecipeRenderer.defaultSampleRate

    // MARK: Determinism

    func testRenderIsDeterministic() {
        let recipe = MacOSTheme().soundSet[.complete]!
        let a = RecipeRenderer.render(recipe, sampleRate: sr)
        let b = RecipeRenderer.render(recipe, sampleRate: sr)
        XCTAssertEqual(a.samples, b.samples, "same recipe must render bit-identical buffers")
        XCTAssertEqual(a.sampleRate, b.sampleRate)
    }

    func testNoiseRenderIsDeterministic() {
        // Noise uses a seeded PRNG — must reproduce exactly.
        let recipe = MacOSTheme().soundSet[.panelOpen]!
        let a = RecipeRenderer.render(recipe, sampleRate: sr)
        let b = RecipeRenderer.render(recipe, sampleRate: sr)
        XCTAssertEqual(a.samples, b.samples)
        XCTAssertFalse(a.isSilent())
    }

    // MARK: Sample-count / duration correctness

    func testSampleCountMatchesRecipeDuration() {
        for event in MacOSTheme().soundSet.events {
            let recipe = MacOSTheme().soundSet[event]!
            let rendered = RecipeRenderer.render(recipe, sampleRate: sr)
            let expected = Int((recipe.duration * sr).rounded(.up))
            XCTAssertEqual(rendered.frameCount, expected, "\(event) frame count")
        }
    }

    func testEmptyRecipeRendersEmpty() {
        let rendered = RecipeRenderer.render(SoundRecipe([]), sampleRate: sr)
        XCTAssertEqual(rendered.frameCount, 0)
        XCTAssertTrue(rendered.isSilent())
    }

    // MARK: Amplitude safety — every real MacOS recipe

    func testEveryRecipePeakWithinSafeBounds() {
        let set = MacOSTheme().soundSet
        for event in set.events {
            let rendered = RecipeRenderer.render(set[event]!, sampleRate: sr)
            let peak = rendered.peak
            XCTAssertGreaterThan(peak, 0, "\(event) must be audible")
            XCTAssertLessThan(peak, 1.0, "\(event) must not clip")
            XCTAssertLessThanOrEqual(peak, RecipeRenderer.safeCeiling, "\(event) must stay under safe ceiling")
        }
    }

    func testThreeOverlappingVoicesStayBelowClipping() {
        // Worst realistic case: sum the three loudest recipes sample-for-sample.
        let set = MacOSTheme().soundSet
        let rendered = set.events
            .map { RecipeRenderer.render(set[$0]!, sampleRate: sr) }
            .sorted { $0.peak > $1.peak }
            .prefix(3)
        var sumPeak: Float = 0
        let maxLen = rendered.map(\.frameCount).max() ?? 0
        for i in 0..<maxLen {
            var s: Float = 0
            for r in rendered where i < r.frameCount { s += r.samples[i] }
            sumPeak = max(sumPeak, abs(s))
        }
        // Mixer applies masterGain 0.85 on top; even raw the summed peak must be < 1.
        XCTAssertLessThan(sumPeak, 1.0, "three overlapping voices must not clip the mixer")
    }

    // MARK: Marimba spectral sanity

    func testMarimbaIsNonSilentAndDecaysToNearZeroTail() {
        let recipe = SoundRecipe([.marimba(Marimba(frequency: 523.25, peakGain: 0.11))])
        let rendered = RecipeRenderer.render(recipe, sampleRate: sr)
        XCTAssertFalse(rendered.isSilent(), "marimba must produce sound")

        // Energy in the first 10% must dominate the last 5% (percussive decay).
        let n = rendered.frameCount
        let head = energy(rendered.samples, 0, n / 10)
        let tail = energy(rendered.samples, n - n / 20, n)
        XCTAssertGreaterThan(head, tail * 10, "marimba should decay: head energy >> tail energy")

        // The very end should be essentially silent.
        let lastFew = Array(rendered.samples.suffix(64))
        let tailPeak = lastFew.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(tailPeak, 0.02, "marimba tail should settle to near-zero")
    }

    // MARK: Swoosh

    func testSwooshIsNonSilentAndTapers() {
        let recipe = SoundRecipe([.noise(NoiseSwoosh.rising(duration: 0.16, peakGain: 0.03))])
        let rendered = RecipeRenderer.render(recipe, sampleRate: sr)
        XCTAssertFalse(rendered.isSilent(), "swoosh must produce sound")

        // Linear amplitude taper (1 - i/n) plus the decay envelope means late-buffer
        // energy is far below early-buffer energy.
        let n = rendered.frameCount
        let early = energy(rendered.samples, n / 10, n / 3)   // past the 0.03s attack
        let late = energy(rendered.samples, n - n / 10, n)
        XCTAssertGreaterThan(early, late * 2, "swoosh should taper toward the tail")
    }

    func testDifferentSwooshDirectionsDiffer() {
        let rising = RecipeRenderer.render(
            SoundRecipe([.noise(NoiseSwoosh.rising(duration: 0.16, peakGain: 0.03))]), sampleRate: sr)
        let falling = RecipeRenderer.render(
            SoundRecipe([.noise(NoiseSwoosh.falling(duration: 0.16, peakGain: 0.03))]), sampleRate: sr)
        XCTAssertNotEqual(rising.samples, falling.samples)
    }

    // MARK: Oscillator glide

    func testGlidingToneRendersAndDecays() {
        let recipe = SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 440, glideTo: 262, duration: 0.16, peakGain: 0.05))
        ])
        let rendered = RecipeRenderer.render(recipe, sampleRate: sr)
        XCTAssertFalse(rendered.isSilent())
        XCTAssertEqual(rendered.peak, 0.05, accuracy: 0.02, "peak near recipe peakGain")
        let tailPeak = rendered.samples.suffix(64).map { abs($0) }.max() ?? 0
        XCTAssertLessThan(tailPeak, 0.02)
    }

    // MARK: helpers

    private func energy(_ s: [Float], _ lo: Int, _ hi: Int) -> Double {
        var e = 0.0
        let a = max(0, lo), b = min(s.count, hi)
        guard a < b else { return 0 }
        for i in a..<b { e += Double(s[i]) * Double(s[i]) }
        return e
    }
}
