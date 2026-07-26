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
        player.isEnabled = true
        XCTAssertTrue(player.isEnabled)
    }
}
