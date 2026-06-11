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
