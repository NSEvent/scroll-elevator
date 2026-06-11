import AppKit
import ApplicationServices

/// Routes jump-to-top / jump-to-bottom commands to the captured scroll target:
/// Accessibility scrollbar first (in .auto), per-app key ladder as fallback.
enum JumpDispatcher {
    private struct KeyChord {
        let keyCode: CGKeyCode
        let flags: CGEventFlags
    }

    // Virtual key codes (HIToolbox/Events.h)
    private static let keyUpArrow: CGKeyCode = 126
    private static let keyDownArrow: CGKeyCode = 125
    private static let keyHome: CGKeyCode = 115
    private static let keyEnd: CGKeyCode = 119

    /// Bundle IDs whose document model makes Cmd-arrows wrong.
    private static let homeEndApps: Set<String> = [
        "com.apple.finder",  // Cmd-Up navigates to the enclosing folder!
    ]
    private static let cmdHomeEndApps: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "io.alacritty",
        "com.mitchellh.ghostty",
    ]

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func promptForAccessibilityIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func jump(_ direction: JumpDirection, target: ScrollTarget, rule: JumpRule) {
        guard promptForAccessibilityIfNeeded() else { return }

        switch rule {
        case .ignore:
            return
        case .auto:
            // Scrollbar control: exact scroll view under the pointer, no
            // keystrokes, no focus steal, works on background windows.
            if AXScrollJumper.jump(direction, atCocoaPoint: target.capturePoint) {
                return
            }
            post(chord: defaultChord(for: target.bundleIdentifier, direction: direction), to: target)
        case .cmdArrows:
            post(chord: KeyChord(keyCode: direction == .top ? keyUpArrow : keyDownArrow, flags: .maskCommand), to: target)
        case .homeEnd:
            post(chord: KeyChord(keyCode: direction == .top ? keyHome : keyEnd, flags: .maskSecondaryFn), to: target)
        case .cmdHomeEnd:
            post(chord: KeyChord(keyCode: direction == .top ? keyHome : keyEnd, flags: [.maskCommand, .maskSecondaryFn]), to: target)
        }
    }

    /// Marks our synthetic page-scroll events so the scroll monitor ignores them.
    static let syntheticScrollUserData: Int64 = 0x53_45_4C_56  // "SELV"

    /// One page up/down (long-press action), as a synthetic scroll-wheel event
    /// routed to the view under the pointer. Keystrokes (PageUp/PageDown) are
    /// app-roulette — terminals snap scrollback to the prompt on any key, chat
    /// apps rebind paging — but a wheel event pages anything scrollable.
    /// Caller must make the overlay panel ignore mouse events around the post,
    /// or the wheel event routes to the overlay itself.
    static func page(_ direction: JumpDirection, target: ScrollTarget) {
        guard promptForAccessibilityIfNeeded() else { return }

        let pageHeight = AXScrollJumper.scrollAreaHeight(atCocoaPoint: target.capturePoint) ?? 700
        let magnitude = Int32((pageHeight * 0.85).rounded())
        // Positive wheel delta scrolls toward the top (same sign convention as
        // scrollingDeltaY).
        let delta = direction == .top ? magnitude : -magnitude

        let source = CGEventSource(stateID: .combinedSessionState)
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: syntheticScrollUserData)
        if let primary = NSScreen.screens.first {
            event.location = CGPoint(
                x: target.capturePoint.x,
                y: primary.frame.maxY - target.capturePoint.y
            )
        }
        event.post(tap: .cghidEventTap)
    }

    private static func defaultChord(for bundleIdentifier: String?, direction: JumpDirection) -> KeyChord {
        if let bundleIdentifier {
            if homeEndApps.contains(bundleIdentifier) {
                return KeyChord(keyCode: direction == .top ? keyHome : keyEnd, flags: .maskSecondaryFn)
            }
            if cmdHomeEndApps.contains(bundleIdentifier) {
                return KeyChord(keyCode: direction == .top ? keyHome : keyEnd, flags: [.maskCommand, .maskSecondaryFn])
            }
        }
        return KeyChord(keyCode: direction == .top ? keyUpArrow : keyDownArrow, flags: .maskCommand)
    }

    private static func post(chord: KeyChord, to target: ScrollTarget) {
        let app = target.runningApplication

        // Key commands land in the target's key window, so the app must be
        // active for the common case to work. The overlay panel is non-activating,
        // so frontmost is usually still the target; activate only when it isn't.
        if let app, !app.isActive {
            app.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                post(chord: chord, toPid: target.pid)
            }
        } else {
            post(chord: chord, toPid: target.pid)
        }
    }

    private static func post(chord: KeyChord, toPid pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: false)
        else { return }
        keyDown.flags = chord.flags
        keyUp.flags = chord.flags
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    }
}
