import Foundation

/// Fixed-size voice allocator with oldest-wins stealing (ARCHITECTURE §4.5: max ~3
/// overlapping voices, oldest stolen). Pure, hardware-free logic (unit-testable without
/// AVAudioEngine); every method assumes single-threaded (serialized) access.
final class VoicePool {

    /// The result of acquiring a voice.
    struct Lease: Equatable {
        /// Index of the voice (0..<capacity) to schedule the buffer on.
        let index: Int
        /// Generation stamp — pass back to `release` so a stale completion handler
        /// (from a voice that was since stolen and reused) can't free the new occupant.
        let generation: Int
        /// True if this voice was stolen from an in-flight sound (not a free slot).
        let stole: Bool
    }

    /// Number of concurrent voices (exactly 3 per the spec).
    let capacity: Int

    /// Acquisition sequence per slot; `nil` = free. Lower = older.
    private var acquiredAt: [Int?]
    /// Per-slot generation, bumped on every acquire.
    private var generation: [Int]
    /// Monotonic acquire counter (age ordering).
    private var nextSeq = 0

    init(capacity: Int) {
        precondition(capacity > 0, "voice pool needs at least one voice")
        self.capacity = capacity
        self.acquiredAt = Array(repeating: nil, count: capacity)
        self.generation = Array(repeating: 0, count: capacity)
    }

    /// Reserve a voice: a free slot if one exists, otherwise steal the oldest-playing
    /// one (ties broken by lowest index). O(capacity) with capacity == 3 → O(1).
    func acquire() -> Lease {
        nextSeq += 1

        if let free = acquiredAt.firstIndex(where: { $0 == nil }) {
            generation[free] += 1
            acquiredAt[free] = nextSeq
            return Lease(index: free, generation: generation[free], stole: false)
        }

        // All busy → steal the oldest (smallest acquiredAt).
        var oldest = 0
        var oldestSeq = acquiredAt[0] ?? Int.max
        for i in 1..<capacity {
            let s = acquiredAt[i] ?? Int.max
            if s < oldestSeq { oldestSeq = s; oldest = i }
        }
        generation[oldest] += 1
        acquiredAt[oldest] = nextSeq
        return Lease(index: oldest, generation: generation[oldest], stole: true)
    }

    /// Release a voice when its sound finishes. No-op if the slot has since been
    /// reused (generation mismatch) — this makes stale completion callbacks safe.
    func release(index: Int, generation gen: Int) {
        guard index >= 0, index < capacity else { return }
        guard generation[index] == gen else { return }
        acquiredAt[index] = nil
    }

    /// Number of voices currently marked playing (test/introspection aid).
    var activeCount: Int {
        acquiredAt.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
    }

    /// Free every slot (bumping generations so any stale completion is ignored).
    /// Used when the audio graph is rebuilt after an output-device change.
    func reset() {
        for i in 0..<capacity {
            generation[i] += 1
            acquiredAt[i] = nil
        }
    }
}
