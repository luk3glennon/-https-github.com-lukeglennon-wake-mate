import XCTest
@testable import WakeMate

final class WakeTimeTests: XCTestCase {
    func test_decode_parsesPostgresTimeString() throws {
        let json = "\"07:05:00\"".data(using: .utf8)!
        let wakeTime = try JSONDecoder().decode(WakeTime.self, from: json)
        XCTAssertEqual(wakeTime, WakeTime(hour: 7, minute: 5))
    }

    func test_encode_producesZeroPaddedHHmmss() throws {
        let data = try JSONEncoder().encode(WakeTime(hour: 6, minute: 5))
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"06:05:00\"")
    }

    func test_lessThan_ordersByHourThenMinute() {
        XCTAssertLessThan(WakeTime(hour: 6, minute: 59), WakeTime(hour: 7, minute: 0))
        XCTAssertLessThan(WakeTime(hour: 7, minute: 0), WakeTime(hour: 7, minute: 1))
    }
}
