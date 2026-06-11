import AppKit

/// Resolves the window under the cursor (scroll-follows-mouse means the scrolled
/// window is not necessarily the frontmost one).
enum TargetResolver {
    static func resolve(atCocoaPoint point: NSPoint) -> ScrollTarget? {
        let ownPID = ProcessInfo.processInfo.processIdentifier

        if let pid = windowOwnerPID(atCocoaPoint: point), pid != ownPID {
            let app = NSRunningApplication(processIdentifier: pid)
            return ScrollTarget(
                pid: pid,
                bundleIdentifier: app?.bundleIdentifier,
                appName: app?.localizedName ?? "Unknown"
            )
        }

        // Fallback: frontmost app.
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ownPID else { return nil }
        return ScrollTarget(
            pid: front.processIdentifier,
            bundleIdentifier: front.bundleIdentifier,
            appName: front.localizedName ?? "Unknown"
        )
    }

    /// CGWindowList bounds use top-left-origin global coordinates; Cocoa uses
    /// bottom-left. Convert against the primary screen, then walk the on-screen
    /// window list front-to-back for the first normal-layer hit.
    private static func windowOwnerPID(atCocoaPoint point: NSPoint) -> pid_t? {
        guard let primary = NSScreen.screens.first else { return nil }
        let cgPoint = CGPoint(x: point.x, y: primary.frame.maxY - point.y)

        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for entry in info {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            if bounds.contains(cgPoint) {
                return pid
            }
        }
        return nil
    }
}
