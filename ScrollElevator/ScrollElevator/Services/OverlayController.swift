import AppKit
import SwiftUI

/// Owns the non-activating overlay panel: placement around the cursor anchor,
/// fade in/out, the hide timeout, and all dismissal triggers.
final class OverlayController {
    private let settings: SettingsService

    private var panel: NSPanel?
    private var target: ScrollTarget?
    private var anchor: NSPoint = .zero
    private var isHovering = false
    private var hideTimer: Timer?
    private var lastHideAt: Date = .distantPast

    // Dismissal monitors, installed only while the overlay is visible.
    private var dismissMonitors: [Any] = []
    private var workspaceObserver: NSObjectProtocol?

    /// Minimum quiet time after a hide before the overlay may reappear.
    private let cooldown: TimeInterval = 0.75
    /// A new burst anchored at least this far away repositions a visible overlay.
    private let repositionDistance: CGFloat = 40

    private let buttonDiameter: CGFloat = 38
    private let panelPadding: CGFloat = 12

    /// The overlay lives inside a tall, narrow corridor around the anchor:
    /// tight left/right (a bit wider than the buttons), roomier up/down
    /// (a bit past the buttons). Pointer travel beyond it hides the overlay.
    /// The grace margin keeps an overshoot near a button edge from dismissing.
    private let dismissGraceMargin: CGFloat = 10
    private var horizontalDismissTolerance: CGFloat {
        buttonDiameter / 2 + 12 + dismissGraceMargin
    }
    private var verticalDismissTolerance: CGFloat {
        CGFloat(settings.placementDistance) + buttonDiameter / 2 + 24 + dismissGraceMargin
    }

    init(settings: SettingsService) {
        self.settings = settings
    }

    func show(for newTarget: ScrollTarget, at anchorPoint: NSPoint) {
        if let panel, panel.isVisible {
            // Already up: adopt the new target, keep the anchor stable unless the
            // user has clearly moved, and just extend the timeout (no re-animation).
            target = newTarget
            if hypot(anchorPoint.x - anchor.x, anchorPoint.y - anchor.y) > repositionDistance {
                anchor = anchorPoint
                panel.setFrameOrigin(panelOrigin(for: anchor, panelSize: panel.frame.size))
            }
            restartHideTimer()
            return
        }

        guard Date().timeIntervalSince(lastHideAt) >= cooldown else { return }

        target = newTarget
        anchor = anchorPoint

        let panel = makePanel()
        self.panel = panel
        panel.setFrameOrigin(panelOrigin(for: anchor, panelSize: panel.frame.size))
        // No entrance animation — the fade-in read as a flash. The buttons are
        // translucent at rest, so an instant appearance is already gentle.
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        installDismissMonitors()
        restartHideTimer()
    }

    /// Keep a visible overlay alive while scrolling continues, without the
    /// target/anchor bookkeeping of a full show().
    func extend() {
        guard let panel, panel.isVisible else { return }
        restartHideTimer()
    }

    func hide(animated: Bool = true) {
        hideTimer?.invalidate()
        hideTimer = nil
        removeDismissMonitors()
        guard let panel else { return }
        self.panel = nil
        target = nil
        isHovering = false
        lastHideAt = Date()

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: - Panel construction

    private func makePanel() -> NSPanel {
        let distance = CGFloat(settings.placementDistance)
        // Two buttons whose centers sit `distance` above and below the anchor.
        let spacing = max(2 * distance - buttonDiameter, 8)
        let contentSize = NSSize(
            width: buttonDiameter + panelPadding * 2,
            height: buttonDiameter * 2 + spacing + panelPadding * 2
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let view = OverlayView(
            buttonDiameter: buttonDiameter,
            spacing: spacing,
            onJump: { [weak self] direction in self?.performJump(direction) },
            onHoverChange: { [weak self] hovering in self?.hoverChanged(hovering) }
        )
        let hosting = FirstMouseHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: contentSize)
        panel.contentView = hosting
        return panel
    }

    /// Center the panel on the anchor, clamped to the screen the cursor is on.
    private func panelOrigin(for anchor: NSPoint, panelSize: NSSize) -> NSPoint {
        var origin = NSPoint(
            x: anchor.x - panelSize.width / 2,
            y: anchor.y - panelSize.height / 2
        )
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(anchor, $0.frame, false) }) {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - panelSize.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - panelSize.height)
        }
        return origin
    }

    // MARK: - Actions

    private func performJump(_ direction: JumpDirection) {
        guard let target else { return }
        JumpDispatcher.jump(direction, target: target)
        hide()
    }

    private func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            hideTimer?.invalidate()
            hideTimer = nil
        } else {
            restartHideTimer()
        }
    }

    private func restartHideTimer() {
        guard !isHovering else { return }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: settings.hideTimeout, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    // MARK: - Dismissal triggers

    private func installDismissMonitors() {
        removeDismissMonitors()

        // Pointer left the corridor that contains the buttons → hide. Never
        // dismiss by movement while a button is hovered.
        let moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] _ in
            guard let self, !self.isHovering else { return }
            let location = NSEvent.mouseLocation
            if abs(location.x - self.anchor.x) > self.horizontalDismissTolerance ||
                abs(location.y - self.anchor.y) > self.verticalDismissTolerance {
                self.hide()
            }
        })
        if let moveMonitor { dismissMonitors.append(moveMonitor) }

        // Click anywhere outside the panel. (Global monitors never see events
        // delivered to our own process, so button clicks don't trip this.)
        let clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            self?.hide()
        })
        if let clickMonitor { dismissMonitors.append(clickMonitor) }

        // Escape (or any typing — the user is back to ordinary work). Global key
        // monitors only deliver once Accessibility is granted; without it the
        // timeout still hides the overlay.
        let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] _ in
            self?.hide()
        })
        if let keyMonitor { dismissMonitors.append(keyMonitor) }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeDismissMonitors() {
        for monitor in dismissMonitors {
            NSEvent.removeMonitor(monitor)
        }
        dismissMonitors.removeAll()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
    }
}

/// Buttons in a non-activating panel must accept the first click without the
/// panel ever becoming key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
