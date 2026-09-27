import AppKit
import Combine

/// Optional second trigger: press and hold the left mouse button in place and
/// the elevator buttons appear at the cursor, no scroll needed. Installed only
/// while both the app and the "show on long press" setting are enabled.
///
/// Listen-only: the press is never consumed, so the app beneath still gets its
/// normal mouse-down/up. Clicks on the overlay's own buttons are swallowed by
/// the overlay's event tap and never reach this monitor.
final class LongPressMonitor {
    private let settings: SettingsService
    private let overlayController: OverlayController

    private var eventMonitor: Any?
    private var holdTimer: Timer?
    private var machine = LongPressMachine()
    private var cancellables = Set<AnyCancellable>()

    /// How long the button must be held still before the overlay appears.
    private let holdDelay: TimeInterval = 0.5

    init(settings: SettingsService, overlayController: OverlayController) {
        self.settings = settings
        self.overlayController = overlayController

        // Use the published values from the stream rather than re-reading
        // `settings` — `@Published` fires in willSet, so the stored property
        // still holds the old value inside the sink (see ScrollMonitor.start).
        settings.$enabled
            .combineLatest(settings.$showOnLongPress)
            .map { $0 && $1 }
            .removeDuplicates()
            .sink { [weak self] active in
                if active { self?.start() } else { self?.stop() }
            }
            .store(in: &cancellables)
    }

    func start() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        cancelHold()
    }

    private func handle(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            // A double-click's second press is not a hold gesture.
            guard event.clickCount == 1 else {
                cancelHold()
                return
            }
            machine.mouseDown(at: location)
            holdTimer?.invalidate()
            // .common modes: other apps' drag tracking must not stall the timer.
            let timer = Timer(timeInterval: holdDelay, repeats: false) { [weak self] _ in
                self?.holdElapsed()
            }
            RunLoop.main.add(timer, forMode: .common)
            holdTimer = timer
        case .leftMouseDragged:
            if machine.mouseDragged(to: location) { cancelHold() }
        case .leftMouseUp:
            cancelHold()
        default:
            break
        }
    }

    private func holdElapsed() {
        holdTimer = nil
        guard machine.holdElapsed() else { return }
        // Only a real window under the pointer — long-pressing the menu bar
        // or Dock opens their own menus and shouldn't also summon the overlay.
        let point = NSEvent.mouseLocation
        guard let target = TargetResolver.resolve(atCocoaPoint: point, allowFrontmostFallback: false),
              !settings.isIgnored(bundleIdentifier: target.bundleIdentifier) else { return }
        // A deliberate hold skips the post-hide cooldown, which exists to stop
        // scroll-driven flicker — otherwise a hold that dismissed a visible
        // overlay (by clicking outside it) could never bring it back.
        overlayController.show(for: target, at: point, ignoringCooldown: true)
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        machine.mouseUp()
    }
}
