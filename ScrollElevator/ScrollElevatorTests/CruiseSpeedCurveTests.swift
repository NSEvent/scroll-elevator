import XCTest
@testable import ScrollElevator

final class CruiseSpeedCurveTests: XCTestCase {
    func testDefaultMultiplierPreservesLegacyCurve() {
        XCTAssertEqual(
            CruiseSpeedCurve.pointsPerSecond(elapsed: 0, multiplier: 1),
            500
        )
        XCTAssertEqual(
            CruiseSpeedCurve.pointsPerSecond(elapsed: 1, multiplier: 1),
            1_200
        )
        XCTAssertEqual(
            CruiseSpeedCurve.pointsPerSecond(elapsed: 10, multiplier: 1),
            2_500
        )
    }

    func testMultiplierScalesWholeCurve() {
        XCTAssertEqual(
            CruiseSpeedCurve.pointsPerSecond(elapsed: 0, multiplier: 0.25),
            125
        )
        XCTAssertEqual(
            CruiseSpeedCurve.pointsPerSecond(elapsed: 1, multiplier: 0.5),
            600
        )
        XCTAssertEqual(
            CruiseSpeedCurve.pointsPerSecond(elapsed: 10, multiplier: 2),
            5_000
        )
    }

    func testMultiplierClampsToSupportedRange() {
        XCTAssertEqual(CruiseSpeedCurve.clampedMultiplier(0), 0.25)
        XCTAssertEqual(CruiseSpeedCurve.clampedMultiplier(3), 2)
        XCTAssertEqual(CruiseSpeedCurve.clampedMultiplier(.nan), 1)
    }

    func testTickConversionMatchesSixtyHertzInjection() {
        XCTAssertEqual(
            CruiseSpeedCurve.pixelsPerTick(elapsed: 0, multiplier: 1),
            8
        )
        XCTAssertEqual(
            CruiseSpeedCurve.pixelsPerTick(elapsed: 10, multiplier: 2),
            83
        )
        XCTAssertEqual(
            CruiseSpeedCurve.pixelsPerTick(elapsed: 0, multiplier: 1, tickRate: 0),
            0
        )
    }
}
