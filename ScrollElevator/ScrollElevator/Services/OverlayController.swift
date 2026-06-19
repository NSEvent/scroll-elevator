import AppKit
import CoreGraphics
import SwiftUI

/// Owns the non-activating overlay panel: placement around the cursor anchor,
/// the optional hide timeout, and all dismissal triggers.
///
/// The panel is permanently click-through (`ignoresMouseEvents = true`). macOS
/// latches a continuous scroll gesture to whichever window first receives it and
/// won't release it mid-gesture, so a panel that ever grabs the mouse will steal
/// any scroll that starts (or drifts) over it. Keeping it transparent lets every
/// scroll fall through to the app beneath untouched. Button hover and clicks are
/// instead read from a global mouse-move monitor and a CGEventTap that consumes
/// clicks landing on a button.
final class OverlayController {
    private let settings: SettingsService

    private var panel: NSPanel?
    private var input: OverlayInputState?
    private var target: ScrollTarget?
    private var anchor: NSPoint = .zero
    private var isHovering = false
    private var hideTimer: Timer?
    private var lastHideAt: Date = .distantPast

    // Dismissal monitors, installed only while the overlay is visible.
    private var dismissMonitors: [Any] = []
    private var workspaceObserver: NSObjectProtocol?

    // Click tap, installed only while the overlay is visible.
    private var clickTap: CFMachPort?
    private var clickTapSource: CFRunLoopSource?
    private var pressedButton: JumpDirection?

    /// Minimum quiet time after a hide before the overlay may reappear.
    private let cooldown: TimeInterval = 0.75
    /// A new burst anchored at least this far away repositions a visible overlay.
    private let repositionDistance: CGFloat = 40

    private let buttonDiameter: CGFloat = 38
    private let panelPadding: CGFloat = 12
    /// Hit-test slop around a button circle, in points.
    private let buttonHitSlop: CGFloat = 6

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

    /// All overlay timers must run in .common modes: while the user holds a
    /// button, the run loop is in event-tracking mode and .default-mode timers
    /// (Timer.scheduledTimer) never fire — which silently broke hold-to-cruise.
    private func commonModeTimer(interval: TimeInterval, repeats: Bool, block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
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
        installClickTap()
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
        pressedButton = nil
        hideTimer?.invalidate()
        hideTimer = nil
        removeDismissMonitors()
        removeClickTap()
        guard let panel else { return }
        self.panel = nil
        self.input = nil
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
        // Permanently click-through: never grab (and so never latch) a scroll.
        // Clicks are recovered via the event tap; see the type comment.
        panel.ignoresMouseEvents = true

        // Edge awareness: dim the button that can't do anything. Only known
        // when the target exposes an AX scrollbar; nil means "don't dim".
        let position = JumpDispatcher.isTrusted
            ? AXScrollJumper.scrollPosition(atCocoaPoint: target.capturePoint)
            : nil

        let input = OverlayInputState()
        self.input = input

        let view = OverlayView(
            buttonDiameter: buttonDiameter,
            spacing: spacing,
            idleOpacity: settings.idleOpacity,
            dimTop: position.map { $0 <= 0.001 } ?? false,
            dimBottom: position.map { $0 >= 0.999 } ?? false,
            input: input
        )
        let hosting = NSHostingView(rootView: view)
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

    // MARK: - Button geometry

    /// Which button (if any) the given Cocoa-global point sits on, computed from
    /// the panel's actual frame (which may be clamped at screen edges).
    fileprivate func button(at location: NSPoint) -> JumpDirection? {
        guard let panel else { return nil }
        let frame = panel.frame
        let centerX = frame.midX
        let edgeOffset = panelPadding + buttonDiameter / 2
        let radius = buttonDiameter / 2 + buttonHitSlop
        let topCenter = NSPoint(x: centerX, y: frame.maxY - edgeOffset)
        if hypot(location.x - topCenter.x, location.y - topCenter.y) <= radius { return .top }
        let bottomCenter = NSPoint(x: centerX, y: frame.minY + edgeOffset)
        if hypot(location.x - bottomCenter.x, location.y - bottomCenter.y) <= radius { return .bottom }
        return nil
    }

    // MARK: - Click tap

    /// The panel can't receive clicks (it's click-through), so a session-level
    /// event tap watches for left-clicks landing on a button, consumes them so
    /// the app beneath doesn't also see them, and drives the press lifecycle.
    private func installClickTap() {
        guard clickTap == nil else { return }
        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseUp.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseDragged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: overlayClickTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // No accessibility trust → no tap. Scroll still passes through; the
            // buttons just won't click until the permission is granted.
            return
        }
        clickTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        clickTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeClickTap() {
        if let tap = clickTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = clickTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        clickTapSource = nil
        clickTap = nil
    }

    /// Called on the main thread from the tap callback. Returns nil to consume.
    fileprivate func handleClickEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let clickTap { CGEvent.tapEnable(tap: clickTap, enable: true) }
            return passthrough

        case .leftMouseDown:
            guard let direction = button(at: NSEvent.mouseLocation) else { return passthrough }
            pressedButton = direction
            input?.pressed = direction
            pressChanged(direction, phase: .began)
            return nil

        case .leftMouseDragged:
            guard let pressed = pressedButton else { return passthrough }
            // Pressed look tracks whether the pointer is still on the button.
            input?.pressed = (button(at: NSEvent.mouseLocation) == pressed) ? pressed : nil
            return nil

        case .leftMouseUp:
            guard let pressed = pressedButton else { return passthrough }
            let inside = button(at: NSEvent.mouseLocation) == pressed
            pressedButton = nil
            input?.pressed = nil
            pressChanged(pressed, phase: inside ? .releasedInside : .releasedOutside)
            return nil

        default:
            return passthrough
        }
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
            cruiseStartTimer = commonModeTimer(interval: cruiseDelay, repeats: false) { [weak self] in
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
        guard !cruising, panel != nil else { return }
        // The hold only cruises if the pointer is still on the button it
        // pressed — holding after dragging off is a cancel-in-progress.
        guard button(at: NSEvent.mouseLocation) == direction else { return }
        cruising = true
        cruiseBeganAt = Date()

        cruiseTimer = commonModeTimer(interval: 1 / cruiseTickHz, repeats: true) { [weak self] in
            self?.cruiseTick(direction)
        }

        // Backstop: if the mouse-up is ever missed by the tap, the global monitor
        // (which sees other apps' events) still ends the cruise.
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
        restartHideTimer()
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
        hideTimer = commonModeTimer(interval: settings.hideTimeout, repeats: false) { [weak self] in
            self?.hide()
        }
    }

    // MARK: - Dismissal triggers

    private func installDismissMonitors() {
        removeDismissMonitors()

        // Track hover from raw movement (the panel is click-through, so SwiftUI
        // never reports it) and hide on a corridor exit. Never dismiss by
        // movement while a button is hovered.
        let moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] _ in
            guard let self else { return }
            let location = NSEvent.mouseLocation
            let over = self.button(at: location)
            if self.input?.hovered != over { self.input?.hovered = over }
            if (over != nil) != self.isHovering { self.hoverChanged(over != nil) }
            if over == nil {
                if abs(location.x - self.anchor.x) > self.horizontalDismissTolerance ||
                    abs(location.y - self.anchor.y) > self.verticalDismissTolerance {
                    self.hide()
                }
            }
        })
        if let moveMonitor { dismissMonitors.append(moveMonitor) }

        // Click anywhere outside a button. (A click on a button is consumed by
        // the tap, so it never reaches this monitor.)
        let clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            guard let self else { return }
            if self.button(at: NSEvent.mouseLocation) == nil {
                self.hide()
            }
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

/// C-compatible trampoline for the click tap. Routes back to the controller via
/// the refcon pointer; runs on the main run loop (where the source is added).
private func overlayClickTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<OverlayController>.fromOpaque(refcon).takeUnretainedValue()
    return controller.handleClickEvent(type: type, event: event)
}
