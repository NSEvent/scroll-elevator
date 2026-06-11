import AppKit
import SwiftUI

/// Owns the non-activating overlay panel: placement around the cursor anchor,
/// the optional hide timeout, and all dismissal triggers.
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

        let panel = makePanel(for: newTarget)
        self.panel = panel
        panel.setFrameOrigin(panelOrigin(for: anchor, panelSize: panel.frame.size))
        // No entrance animation — a fade-in reads as a flash. The buttons are
        // translucent at rest, so an instant appearance is already gentle.
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        installDismissMonitors()
        restartHideTimer()
    }

    /// Keep a visible overlay alive while scrolling continues; if a corridor
    /// exit hid it mid-burst, bring it back at the current cursor position
    /// (the cooldown still applies, so this can't flicker).
    func extendOrReshow(for target: ScrollTarget) {
        if let panel, panel.isVisible {
            restartHideTimer()
        } else {
            show(for: target, at: NSEvent.mouseLocation)
        }
    }

    func hide(animated: Bool = true) {
        stopCruise()
        cruiseStartTimer?.invalidate()
        cruiseStartTimer = nil
        pressStartedAt = nil
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

    private func makePanel(for target: ScrollTarget) -> NSPanel {
        let distance = CGFloat(settings.placementDistance)
        // Two buttons whose centers sit `distance` above and below the anchor.
        let spacing = max(2 * distance - buttonDiameter, 8)
        let contentSize = NSSize(
            width: buttonDiameter + panelPadding * 2,
            height: buttonDiameter * 2 + spacing + panelPadding * 2
        )

        let panel = OverlayPanel(
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
        panel.onDeadClick = { [weak self] in self?.hide() }

        // Edge awareness: dim the button that can't do anything. Only known
        // when the target exposes an AX scrollbar; nil means "don't dim".
        let position = JumpDispatcher.isTrusted
            ? AXScrollJumper.scrollPosition(atCocoaPoint: target.capturePoint)
            : nil

        let view = OverlayView(
            buttonDiameter: buttonDiameter,
            spacing: spacing,
            idleOpacity: settings.idleOpacity,
            dimTop: position.map { $0 <= 0.001 } ?? false,
            dimBottom: position.map { $0 >= 0.999 } ?? false,
            onPress: { [weak self] direction, phase in self?.pressChanged(direction, phase: phase) },
            onHoverChange: { [weak self] hovering in self?.hoverChanged(hovering) }
        )
        let hosting = FirstMouseHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: contentSize)
        // Only the two button circles are clickable; the gap between them —
        // where the cursor parks — stays click-through.
        let padding = panelPadding
        let diameter = buttonDiameter
        hosting.interactiveRegion = { point, bounds in
            let radius = diameter / 2 + 2
            let centerX = bounds.width / 2
            let edgeOffset = padding + diameter / 2
            // The two buttons are symmetric about the vertical center, so this
            // check is independent of view flippedness.
            let toNear = hypot(point.x - centerX, point.y - edgeOffset)
            let toFar = hypot(point.x - centerX, (bounds.height - point.y) - edgeOffset)
            return min(toNear, toFar) <= radius
        }
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

    /// Quick press = jump; hold past `cruiseDelay` = cruise while held.
    private var pressStartedAt: Date?
    private var cruiseStartTimer: Timer?
    private var cruiseTimer: Timer?
    private var cruiseBeganAt: Date?
    private var cruising = false
    private var cruiseStopMonitor: Any?

    private let cruiseDelay: TimeInterval = 0.35
    /// Cruise speed ramp, in points/second.
    private let cruiseBaseSpeed: Double = 500
    private let cruiseAcceleration: Double = 700  // per second of hold
    private let cruiseMaxSpeed: Double = 2500
    private let cruiseTickHz: Double = 60
    /// Hard cap — a lost mouse-up can never scroll forever.
    private let cruiseMaxDuration: TimeInterval = 20

    private func pressChanged(_ direction: JumpDirection, phase: PressPhase) {
        switch phase {
        case .began:
            pressStartedAt = Date()
            cruiseStartTimer?.invalidate()
            cruiseStartTimer = Timer.scheduledTimer(withTimeInterval: cruiseDelay, repeats: false) { [weak self] _ in
                self?.startCruise(direction)
            }
        case .releasedInside:
            cruiseStartTimer?.invalidate()
            cruiseStartTimer = nil
            pressStartedAt = nil
            if cruising {
                stopCruise()
            } else {
                performJump(direction)
            }
        case .releasedOutside:
            // Dragged off the button before letting go: cancel — no jump.
            cruiseStartTimer?.invalidate()
            cruiseStartTimer = nil
            pressStartedAt = nil
            if cruising {
                stopCruise()
            } else {
                restartHideTimer()
            }
        }
    }

    private func performJump(_ direction: JumpDirection) {
        guard let target else { return }
        JumpDispatcher.jump(direction, target: target, rule: settings.rule(for: target.bundleIdentifier))
        hide()
    }

    // MARK: - Cruise

    private func startCruise(_ direction: JumpDirection) {
        guard !cruising, let panel else { return }
        // The hold only cruises if the pointer is still on the button it
        // pressed — holding after dragging off is a cancel-in-progress.
        guard pointerOnButton(direction) else { return }
        cruising = true
        cruiseBeganAt = Date()
        // Synthetic wheel events route by cursor position; make the panel
        // transparent to them so they reach the target window beneath. The
        // active press keeps delivering its mouse-up to us regardless.
        panel.ignoresMouseEvents = true

        cruiseTimer = Timer.scheduledTimer(withTimeInterval: 1 / cruiseTickHz, repeats: true) { [weak self] _ in
            self?.cruiseTick(direction)
        }

        // Backstop: if the mouse-up is ever misrouted past our gesture, the
        // global monitor (which sees other apps' events) still ends the cruise.
        cruiseStopMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            self?.stopCruise()
        })
    }

    private func cruiseTick(_ direction: JumpDirection) {
        guard cruising, let beganAt = cruiseBeganAt else { return }
        let elapsed = Date().timeIntervalSince(beganAt)
        guard elapsed < cruiseMaxDuration else {
            stopCruise()
            return
        }
        let speed = min(cruiseMaxSpeed, cruiseBaseSpeed + cruiseAcceleration * elapsed)
        JumpDispatcher.cruiseTick(direction, pixels: Int32((speed / cruiseTickHz).rounded()))
    }

    private func stopCruise() {
        guard cruising else { return }
        cruising = false
        cruiseBeganAt = nil
        cruiseTimer?.invalidate()
        cruiseTimer = nil
        if let cruiseStopMonitor {
            NSEvent.removeMonitor(cruiseStopMonitor)
            self.cruiseStopMonitor = nil
        }
        panel?.ignoresMouseEvents = false
        restartHideTimer()
    }

    /// Whether the pointer is currently over the given button, computed from
    /// the panel's actual frame (which may be clamped at screen edges).
    private func pointerOnButton(_ direction: JumpDirection) -> Bool {
        guard let panel else { return false }
        let frame = panel.frame
        let centerX = frame.midX
        let edgeOffset = panelPadding + buttonDiameter / 2
        let centerY = direction == .top ? frame.maxY - edgeOffset : frame.minY + edgeOffset
        let location = NSEvent.mouseLocation
        return hypot(location.x - centerX, location.y - centerY) <= buttonDiameter / 2 + 6
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
        hideTimer?.invalidate()
        hideTimer = nil
        guard !settings.neverHide, !isHovering, !cruising else { return }
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

/// Safety net behind the hit-test guard: if a click somehow lands on the panel
/// without hitting a button, dismiss instead of silently swallowing it.
private final class OverlayPanel: NSPanel {
    var onDeadClick: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           let contentView,
           contentView.hitTest(event.locationInWindow) == nil {
            onDeadClick?()
            return
        }
        super.sendEvent(event)
    }
}

/// Buttons in a non-activating panel must accept the first click without the
/// panel ever becoming key — and only the button circles are interactive.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    /// Returns whether a point (in this view's coordinates) is clickable.
    var interactiveRegion: ((NSPoint, NSRect) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        if let interactiveRegion, !interactiveRegion(local, bounds) {
            return nil
        }
        return super.hitTest(point)
    }
}
