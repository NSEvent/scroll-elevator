import Foundation

/// Pure state machine for press-and-hold detection. The monitor feeds it left
/// mouse down/drag/up events and fires `holdElapsed()` from a timer; it decides
/// whether the press still counts as a stationary hold. No AppKit, no timers —
/// fully unit-testable.
struct LongPressMachine {
    /// How far the pointer may drift during the hold before it counts as a
    /// drag (text selection, window move) and the press is abandoned.
    static let movementTolerance: CGFloat = 6

    /// Where the current press began, while it is still a candidate hold.
    private(set) var pressOrigin: CGPoint?

    var isArmed: Bool { pressOrigin != nil }

    mutating func mouseDown(at point: CGPoint) {
        pressOrigin = point
    }

    /// Returns true if this drag cancelled a pending hold.
    @discardableResult
    mutating func mouseDragged(to point: CGPoint) -> Bool {
        guard let origin = pressOrigin else { return false }
        if hypot(point.x - origin.x, point.y - origin.y) > Self.movementTolerance {
            pressOrigin = nil
            return true
        }
        return false
    }

    mutating func mouseUp() {
        pressOrigin = nil
    }

    /// Called when the hold delay elapses. Returns true (and disarms) if the
    /// press is still down and stationary — i.e. the overlay should show.
    mutating func holdElapsed() -> Bool {
        guard isArmed else { return false }
        pressOrigin = nil
        return true
    }
}
