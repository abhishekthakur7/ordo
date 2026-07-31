import XCTest
@testable import OrdoCore

final class CodableTests: XCTestCase {

    func testJSONValuePreservesIntVsDouble() throws {
        let data = Data("""
        {"i":5,"d":5.5,"b":true,"s":"x","n":null,"a":[1,2],"o":{"k":1}}
        """.utf8)
        let v = try JSONDecoder().decode([String: JSONValue].self, from: data)
        XCTAssertEqual(v["i"], .int(5))
        XCTAssertEqual(v["d"], .double(5.5))
        XCTAssertEqual(v["b"], .bool(true))
        XCTAssertEqual(v["s"], .string("x"))
        XCTAssertEqual(v["n"], .null)
        XCTAssertEqual(v["a"], .array([.int(1), .int(2)]))
        XCTAssertEqual(v["o"], .object(["k": .int(1)]))

        // Round-trips without turning 5 into 5.0.
        let out = try JSONEncoder().decodeReencode(v)
        XCTAssertEqual(out["i"], .int(5))
        XCTAssertEqual(out["d"], .double(5.5))
    }

    func testHistoryRecordRoundTrip() throws {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601

        let task = OrdoTask(title: "archived", list: .today, done: true,
                            createdAt: ISO8601DateFormatter().date(from: "2026-07-26T12:00:00Z")!,
                            addedToTodayOn: T.day(2026, 7, 26),
                            completedAt: ISO8601DateFormatter().date(from: "2026-07-26T15:00:00Z")!,
                            order: 1)
        let rec = HistoryRecord.task(ArchivedTask(task: task, archivedDay: T.day(2026, 7, 26)))
        let back = try d.decode(HistoryRecord.self, from: try e.encode(rec))
        XCTAssertEqual(back, rec)

        let sumRec = HistoryRecord.summary(
            DaySummary(day: T.day(2026, 7, 26), completed: 2, stillOpen: 1, fullyCleared: false))
        let backSum = try d.decode(HistoryRecord.self, from: try e.encode(sumRec))
        XCTAssertEqual(backSum, sumRec)
    }

    func testDoneDefaultsFalseWhenAbsent() throws {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        let json = Data("""
        {"id":"\(UUID().uuidString)","title":"t","list":"today",
         "createdAt":"2026-07-26T12:00:00Z","order":1}
        """.utf8)
        let task = try d.decode(OrdoTask.self, from: json)
        XCTAssertFalse(task.done)
        XCTAssertFalse(task.pinned)
        XCTAssertNil(task.completedAt)
        XCTAssertNil(task.origin)
    }
}

private extension JSONEncoder {
    func decodeReencode(_ v: [String: JSONValue]) throws -> [String: JSONValue] {
        let data = try encode(v)
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    }
}
