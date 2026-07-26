import XCTest
@testable import OrdoSound

final class VoicePoolTests: XCTestCase {

    func testAcquiresFreeVoicesInOrderWithoutStealing() {
        let pool = VoicePool(capacity: 3)
        let a = pool.acquire()
        let b = pool.acquire()
        let c = pool.acquire()
        XCTAssertEqual([a.index, b.index, c.index], [0, 1, 2])
        XCTAssertFalse(a.stole)
        XCTAssertFalse(b.stole)
        XCTAssertFalse(c.stole)
        XCTAssertEqual(pool.activeCount, 3)
    }

    func testFourthPlayStealsOldestVoice() {
        let pool = VoicePool(capacity: 3)
        let first = pool.acquire()   // index 0, oldest
        _ = pool.acquire()           // index 1
        _ = pool.acquire()           // index 2
        let fourth = pool.acquire()  // must steal the oldest (index 0)
        XCTAssertTrue(fourth.stole)
        XCTAssertEqual(fourth.index, first.index)
        XCTAssertEqual(pool.activeCount, 3, "capacity never exceeded")
    }

    func testStealingContinuesInAgeOrder() {
        let pool = VoicePool(capacity: 3)
        _ = pool.acquire() // 0
        _ = pool.acquire() // 1
        _ = pool.acquire() // 2
        let s1 = pool.acquire() // steals 0 (oldest)
        let s2 = pool.acquire() // now 1 is oldest
        let s3 = pool.acquire() // now 2 is oldest
        XCTAssertEqual([s1.index, s2.index, s3.index], [0, 1, 2])
    }

    func testReleaseFreesVoiceSoNextAcquireReusesItWithoutStealing() {
        let pool = VoicePool(capacity: 3)
        let a = pool.acquire()
        _ = pool.acquire()
        _ = pool.acquire()
        pool.release(index: a.index, generation: a.generation)
        XCTAssertEqual(pool.activeCount, 2)
        let reused = pool.acquire()
        XCTAssertFalse(reused.stole, "a freed slot is reused without stealing")
        XCTAssertEqual(reused.index, a.index)
    }

    func testStaleReleaseIsIgnoredAfterVoiceStolen() {
        let pool = VoicePool(capacity: 3)
        let a = pool.acquire() // index 0, generation g0
        _ = pool.acquire()
        _ = pool.acquire()
        let stealer = pool.acquire() // steals index 0, new generation
        XCTAssertEqual(stealer.index, a.index)

        // The original voice's completion fires late — must NOT free the new occupant.
        pool.release(index: a.index, generation: a.generation)
        XCTAssertEqual(pool.activeCount, 3, "stale release must be a no-op")

        // The current occupant's release does free it.
        pool.release(index: stealer.index, generation: stealer.generation)
        XCTAssertEqual(pool.activeCount, 2)
    }

    func testResetFreesEverythingAndInvalidatesPriorGenerations() {
        let pool = VoicePool(capacity: 3)
        let a = pool.acquire()
        _ = pool.acquire()
        pool.reset()
        XCTAssertEqual(pool.activeCount, 0)
        // A release with a pre-reset generation must not resurrect anything.
        pool.release(index: a.index, generation: a.generation)
        XCTAssertEqual(pool.activeCount, 0)
    }

    func testSingleVoicePoolAlwaysSteals() {
        let pool = VoicePool(capacity: 1)
        let a = pool.acquire()
        XCTAssertFalse(a.stole)
        let b = pool.acquire()
        XCTAssertTrue(b.stole)
        XCTAssertEqual(b.index, 0)
    }
}
