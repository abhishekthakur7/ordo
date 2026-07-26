// OrdoUI — a silent SoundPlaying (contract C2). Lets previews and unit tests run
// without an audio engine; the real renderer lives in OrdoSound.

import OrdoThemes

/// A `SoundPlaying` that never makes a sound. Respects `isEnabled` as plain state.
public final class SilentSoundPlayer: SoundPlaying {
    public var isEnabled: Bool
    public init(isEnabled: Bool = true) { self.isEnabled = isEnabled }
    public func play(_ event: SoundEvent) {}
}
