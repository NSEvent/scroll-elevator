import AppKit
import ApplicationServices

/// Posts jump-to-top / jump-to-bottom keyboard commands (Cmd-Up / Cmd-Down)
/// to the captured scroll target.
enum JumpDispatcher {
    private static let upArrowKeyCode: CGKeyCode = 126  // kVK_UpArrow
    private static let downArrowKeyCode: CGKeyCode = 125  // kVK_DownArrow

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func promptForAccessibilityIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func jump(_ direction: JumpDirection, target: ScrollTarget) {
        guard promptForAccessibilityIfNeeded() else { return }

        let keyCode = direction == .top ? upArrowKeyCode : downArrowKeyCode
        let app = target.runningApplication

        // Cmd-Up/Down lands in the target app's key window, so the app must be
        // active for the common case to work. The overlay panel is non-activating,
        // so frontmost is usually still the target; activate only when it isn't.
        if let app, !app.isActive {
            app.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                post(keyCode: keyCode, to: target.pid)
            }
        } else {
            post(keyCode: keyCode, to: target.pid)
        }
    }

    private static func post(keyCode: CGKeyCode, to pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    }
}
