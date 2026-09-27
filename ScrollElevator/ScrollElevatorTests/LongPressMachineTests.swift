import XCTest
@testable import ScrollElevator

final class LongPressMachineTests: XCTestCase {
    func testStationaryHoldFires() {
        var machine = LongPressMachine()
        machine.mouseDown(at: CGPoint(x: 100, y: 100))
        XCTAssertTrue(machine.holdElapsed())
        XCTAssertFalse(machine.isArmed)
    }

    func testSmallJitterStillFires() {
        var machine = LongPressMachine()
        machine.mouseDown(at: CGPoint(x: 100, y: 100))
        XCTAssertFalse(machine.mouseDragged(to: CGPoint(x: 103, y: 104)))
        XCTAssertTrue(machine.holdElapsed())
    }

    func testDragBeyondToleranceCancels() {
        var machine = LongPressMachine()
        machine.mouseDown(at: CGPoint(x: 100, y: 100))
        XCTAssertTrue(machine.mouseDragged(to: CGPoint(x: 110, y: 100)))
        XCTAssertFalse(machine.holdElapsed())
    }

    func testReleaseBeforeDelayCancels() {
        var machine = LongPressMachine()
        machine.mouseDown(at: CGPoint(x: 100, y: 100))
        machine.mouseUp()
        XCTAssertFalse(machine.holdElapsed())
    }

    func testFiresOnlyOncePerPress() {
        var machine = LongPressMachine()
        machine.mouseDown(at: .zero)
        XCTAssertTrue(machine.holdElapsed())
        XCTAssertFalse(machine.holdElapsed())
    }
}
