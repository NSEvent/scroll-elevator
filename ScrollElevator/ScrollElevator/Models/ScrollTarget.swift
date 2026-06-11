import AppKit

/// The app/window context captured when a scroll burst starts, so a later
/// button click can route the jump back to what was actually being scrolled.
struct ScrollTarget {
    let pid: pid_t
    let bundleIdentifier: String?
    let appName: String
    /// Cursor position at burst start, in Cocoa global coordinates (bottom-left origin).
    let anchor: NSPoint

    var runningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: pid)
    }
}

enum JumpDirection {
    case top
    case bottom
}
