import XCTest
@testable import OrdoSound

/// Engine construction + the SoundPlaying contract that can be exercised without
/// asserting on real audio hardware output. Hardware I/O (device start, actual
/// playback) is intentionally not asserted here — it is unreliable in CI — but
/// constructing the engine and driving `play`/`isEnabled` must be safe and never throw.
final class SoundEngineTests: XCTestCase {

    // MARK: NullSoundPlayer

    func testNullPlayerIsAlwaysSilentNoOp() {
        let player = NullSoundPlayer()
        XCTAssertFalse(player.isEnabled)
        // Toggling and playing must be harmless no-ops.
        player.isEnabled = true
        for event in SoundEvent.allCases { player.play(event) }
        // Nothing to assert beyond "does not crash"; it emits no sound by construction.
    }

    func testNullPlayerConformsToSoundPlaying() {
        let player: any SoundPlaying = NullSoundPlayer()
        player.play(.complete)
        player.updateSoundSet(MacOSTheme().soundSet)
        player.isEnabled = false
        XCTAssertFalse(player.isEnabled)
    }

    // MARK: SoundEngine construction

    func testEngineConstructsFromMacOSSoundSet() {
        // Renders all eight buffers at init; must not throw or hold a device.
        let engine = SoundEngine(soundSet: MacOSTheme().soundSet)
        XCTAssertTrue(engine.isEnabled, "default enabled")
    }

    func testEngineConstructsWithEmptySoundSet() {
        let engine = SoundEngine(soundSet: SoundSet([:]))
        // Playing an event with no recipe is a silent no-op, never a crash.
        engine.play(.complete)
        XCTAssertNotNil(engine)
    }

    func testIsEnabledToggleIsInstantAndDefaults() {
        let engine = SoundEngine(soundSet: MacOSTheme().soundSet, enabled: false)
        XCTAssertFalse(engine.isEnabled)
        engine.isEnabled = true
        XCTAssertTrue(engine.isEnabled)
        engine.isEnabled = false
        XCTAssertFalse(engine.isEnabled)
    }

    func testDisabledEnginePlayIsNoOp() {
        let engine = SoundEngine(soundSet: MacOSTheme().soundSet, enabled: false)
        // Should not attempt to start the engine or crash.
        for event in SoundEvent.allCases { engine.play(event) }
        XCTAssertFalse(engine.isEnabled)
    }

    func testEngineExposesThreeVoices() {
        XCTAssertEqual(SoundEngine.voiceCount, 3)
    }

    func testEngineUsableThroughProtocol() {
        let player: any SoundPlaying = SoundEngine(soundSet: MacOSTheme().soundSet, enabled: false)
        player.play(.tabSwitch)
        player.updateSoundSet(ArcadeTheme().soundSet)
        player.isEnabled = true
        XCTAssertTrue(player.isEnabled)
    }

    // MARK: Variants and live updates

    func testSixRecipeVariantsRoundRobinInDeclarationOrder() {
        let recipes = (0..<6).map { index in
            SoundRecipe([
                .oscillator(Oscillator(
                    wave: .sine,
                    frequency: 220 + Double(index) * 20,
                    duration: 0.02,
                    peakGain: 0.02
                ))
            ])
        }
        let engine = SoundEngine(soundSet: SoundSet(variants: [.add: recipes]), enabled: false)

        XCTAssertEqual(engine.variantCount(for: .add), 6)
        XCTAssertEqual((0..<8).compactMap { _ in engine.selectNextVariantForTesting(.add) },
                       [0, 1, 2, 3, 4, 5, 0, 1])
    }

    func testLiveSoundSetUpdateReplacesVariantsAndResetsRoundRobin() {
        let first = SoundRecipe([
            .oscillator(Oscillator(wave: .sine, frequency: 220, duration: 0.02, peakGain: 0.02))
        ])
        let replacement = SoundRecipe([
            .oscillator(Oscillator(wave: .triangle, frequency: 440, duration: 0.02, peakGain: 0.02))
        ])
        let engine = SoundEngine(soundSet: SoundSet(variants: [.add: [first, first]]), enabled: false)

        XCTAssertEqual(engine.selectNextVariantForTesting(.add), 0)
        engine.updateSoundSet(SoundSet(variants: [.complete: [replacement]]))
        // `variantCount` synchronizes with the engine queue, so this observes the update.
        XCTAssertEqual(engine.variantCount(for: .add), 0)
        XCTAssertEqual(engine.variantCount(for: .complete), 1)
        XCTAssertEqual(engine.selectNextVariantForTesting(.complete), 0)
    }
}
