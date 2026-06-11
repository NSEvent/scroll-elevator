import XCTest
@testable import ScrollElevator

final class ScrollBurstMachineTests: XCTestCase {
    private var machine = ScrollBurstMachine()

    override func setUp() {
        super.setUp()
        machine = ScrollBurstMachine()
    }

    private func scroll(
        _ delta: CGFloat,
        gestureEnded: Bool = false,
        momentumEnded: Bool = false,
        threshold: CGFloat = 10,
        gateOpen: Bool = true
    ) -> ScrollBurstMachine.Output {
        machine.scrollEvent(
            absDeltaY: delta,
            gestureEnded: gestureEnded,
            momentumEnded: momentumEnded,
            threshold: threshold,
            gateOpen: gateOpen
        )
    }

    func testShowsMidGestureWhenThresholdCrossed() {
        XCTAssertEqual(scroll(4).display, .none)
        XCTAssertEqual(scroll(4).display, .none)
        XCTAssertEqual(scroll(4).display, .show)  // 12 >= 10
    }

    func testExtendsAfterQualifying() {
        _ = scroll(20)
        XCTAssertEqual(scroll(5).display, .extend)
        XCTAssertEqual(scroll(5).display, .extend)
    }

    func testZeroThresholdStillRequiresNonzeroDelta() {
        // Touch events at gesture start carry no delta; they must not show.
        XCTAssertEqual(scroll(0, threshold: 0).display, .none)
        XCTAssertEqual(scroll(2, threshold: 0).display, .show)
    }

    func testGestureEndEndsBurstAndResetsState() {
        _ = scroll(20)
        let output = scroll(0, gestureEnded: true)
        XCTAssertTrue(output.burstEnded)
        XCTAssertFalse(machine.burstActive)
        XCTAssertEqual(machine.accumulated, 0)
        // Next event is a fresh burst.
        XCTAssertEqual(scroll(4).display, .none)
    }

    func testMomentumEndEndsBurst() {
        _ = scroll(20)
        XCTAssertTrue(scroll(3, momentumEnded: true).burstEnded)
    }

    func testQualifiedShowReportedOnEndingEventToo() {
        // A single large flick can qualify on the same event that ends the touch.
        let output = scroll(50, gestureEnded: true)
        XCTAssertEqual(output.display, .show)
        XCTAssertTrue(output.burstEnded)
    }

    func testClosedGateAccumulatesButNeverShows() {
        XCTAssertEqual(scroll(50, gateOpen: false).display, .none)
        XCTAssertEqual(scroll(50, gateOpen: false).display, .none)
        // Gate opens mid-burst (e.g. modifier pressed): accumulated total counts.
        XCTAssertEqual(scroll(1, gateOpen: true).display, .show)
    }

    func testQuietTimeoutResetsForFreshBurst() {
        _ = scroll(20)
        machine.quietTimeout()
        XCTAssertFalse(machine.burstActive)
        XCTAssertEqual(scroll(4).display, .none)  // re-accumulates from zero
    }
}
