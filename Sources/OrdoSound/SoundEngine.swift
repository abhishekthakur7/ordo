import Foundation
import AVFoundation
import os
@_exported import OrdoThemes

// MARK: - Null player

/// An always-silent ``SoundPlaying``. Used for previews/tests and as the fallback
/// when the real engine cannot be constructed. `play` is unconditionally a no-op.
public final class NullSoundPlayer: SoundPlaying, @unchecked Sendable {
    /// Stored so the property is well-behaved, but it changes nothing: this player
    /// never emits sound regardless of the flag.
    public var isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    public func play(_ event: SoundEvent) {}
}

// MARK: - Sound engine

/// The real ``SoundPlaying``: `AVAudioEngine` + a fixed 3-voice player pool; all eight event
/// buffers are synthesized once at init (deviation D1). `play` is O(1) with oldest-wins stealing
/// (§4.5), starts lazily, rebuilds on device change, and never throws (missing/failure → no-op).
public final class SoundEngine: SoundPlaying, @unchecked Sendable {

    private static let log = Logger(subsystem: "com.ordo.sound", category: "SoundEngine")

    /// Number of concurrent voices (spec: exactly 3).
    public static let voiceCount = 3

    private let engine = AVAudioEngine()
    private let players: [AVAudioPlayerNode]
    private let format: AVAudioFormat
    private let buffers: [SoundEvent: AVAudioPCMBuffer]
    private let pool: VoicePool
    private let masterGain: Float

    /// All engine graph operations are serialized here; keeps AVAudioEngine calls
    /// off arbitrary threads and makes `VoicePool` access race-free.
    private let queue = DispatchQueue(label: "com.ordo.sound.engine")

    private let stateLock = NSLock()
    private var _isEnabled: Bool

    // Touched only on `queue`.
    private var started = false
    private var configObserver: NSObjectProtocol?

    /// - Parameters:
    ///   - soundSet: the theme's declarative sound set (e.g. `MacOSTheme().soundSet`).
    ///   - sampleRate: render + graph rate (defaults to 44.1 kHz).
    ///   - enabled: initial global on/off (default on).
    ///   - masterGain: mixer output gain, leaving headroom for overlapping voices.
    public init(
        soundSet: SoundSet,
        sampleRate: Double = RecipeRenderer.defaultSampleRate,
        enabled: Bool = true,
        masterGain: Float = 0.85
    ) {
        self._isEnabled = enabled
        self.masterGain = masterGain
        self.pool = VoicePool(capacity: SoundEngine.voiceCount)

        let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            ?? AVAudioFormat(standardFormatWithSampleRate: RecipeRenderer.defaultSampleRate, channels: 1)!
        self.format = fmt

        // Pre-render every event that has a recipe into a PCM buffer, once.
        var built: [SoundEvent: AVAudioPCMBuffer] = [:]
        for event in soundSet.events {
            guard let recipe = soundSet[event] else { continue }
            let rendered = RecipeRenderer.render(recipe, sampleRate: fmt.sampleRate)
            guard let buffer = SoundEngine.makeBuffer(from: rendered, format: fmt) else { continue }
            built[event] = buffer
        }
        self.buffers = built

        // Build the graph (does NOT open the audio device — only start() does that).
        var nodes: [AVAudioPlayerNode] = []
        for _ in 0..<SoundEngine.voiceCount {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: fmt)
            nodes.append(node)
        }
        self.players = nodes
        engine.mainMixerNode.outputVolume = masterGain

        // Rebuild/restart cleanly when the output device changes.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    deinit {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        engine.stop()
    }

    // MARK: SoundPlaying

    public var isEnabled: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isEnabled }
        set { stateLock.lock(); _isEnabled = newValue; stateLock.unlock() }
    }

    public func play(_ event: SoundEvent) {
        stateLock.lock(); let on = _isEnabled; stateLock.unlock()
        guard on else { return }
        guard let buffer = buffers[event] else { return } // missing recipe → silent no-op

        queue.async { [weak self] in
            guard let self else { return }
            guard self.startIfNeeded() else { return }

            let lease = self.pool.acquire()
            let player = self.players[lease.index]
            if lease.stole { player.stop() }

            player.scheduleBuffer(buffer, at: nil, options: .interrupts,
                                  completionCallbackType: .dataPlayedBack) { [weak self] _ in
                self?.queue.async {
                    self?.pool.release(index: lease.index, generation: lease.generation)
                }
            }
            if !player.isPlaying { player.play() }
        }
    }

    // MARK: Engine lifecycle (all on `queue`)

    /// Start the engine lazily; returns false (silent no-op) if it can't start.
    private func startIfNeeded() -> Bool {
        if started { return true }
        do {
            engine.prepare()
            try engine.start()
            started = true
            return true
        } catch {
            SoundEngine.log.error("AVAudioEngine start failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func handleConfigurationChange() {
        queue.async { [weak self] in
            guard let self else { return }
            self.engine.stop()
            self.started = false
            // Drop any in-flight voices and free every pool slot for the new device.
            for node in self.players { node.stop() }
            self.pool.reset()
            // Re-establish connections (mixer output format may have changed) and
            // restart eagerly so the next play is immediate.
            for node in self.players {
                self.engine.connect(node, to: self.engine.mainMixerNode, format: self.format)
            }
            self.engine.mainMixerNode.outputVolume = self.masterGain
            _ = self.startIfNeeded()
        }
    }

    // MARK: Buffer construction

    private static func makeBuffer(from rendered: RenderedSound, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = rendered.frameCount
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let channels = buffer.floatChannelData else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        let dst = channels[0]
        rendered.samples.withUnsafeBufferPointer { src in
            if let base = src.baseAddress {
                dst.update(from: base, count: frames)
            }
        }
        return buffer
    }
}
