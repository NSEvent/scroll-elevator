import Foundation

/// Pure state machine for scroll-burst detection. The monitor feeds it scroll
/// events; it decides when the overlay should show, stay alive, or the burst
/// should end. No AppKit, no timers — fully unit-testable.
struct ScrollBurstMachine {
    enum Display: Equatable {
        case none
        case show
        case extend
    }

    struct Output: Equatable {
        var display: Display = .none
        var burstEnded = false
    }

    /// True from the first scroll event until the burst ends or times out.
    private(set) var burstActive = false
    private(set) var qualified = false
    private(set) var accumulated: CGFloat = 0

    /// - Parameters:
    ///   - gateOpen: false when the burst can never show (no target, ignored
    ///     app, required modifier not held). Accumulation still happens so the
    ///     gate can open mid-burst.
    mutating func scrollEvent(
        absDeltaY: CGFloat,
        gestureEnded: Bool,
        momentumEnded: Bool,
        threshold: CGFloat,
        gateOpen: Bool
    ) -> Output {
        burstActive = true
        accumulated += absDeltaY

        var output = Output()
        if gateOpen {
            // The max(_, 1) keeps a zero threshold from firing on the
            // delta-less touch events at gesture start.
            if !qualified, accumulated >= max(threshold, 1) {
                qualified = true
                output.display = .show
            } else if qualified {
                output.display = .extend
            }
        }

        if gestureEnded || momentumEnded {
            output.burstEnded = true
            reset()
        }
        return output
    }

    /// Quiet-period timeout for phase-less wheel mice.
    mutating func quietTimeout() {
        reset()
    }

    mutating func reset() {
        burstActive = false
        qualified = false
        accumulated = 0
    }
}
