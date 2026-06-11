import AppKit
import Combine

/// Watches global scroll events and feeds them to the burst state machine.
/// The overlay shows the moment a burst crosses the scroll threshold —
/// mid-gesture — and continued scrolling keeps it alive.
final class ScrollMonitor {
    private let settings: SettingsService
    private let overlayController: OverlayController

    private var scrollEventMonitor: Any?
    private var burstEndTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private var machine = ScrollBurstMachine()
    private var burstTarget: ScrollTarget?
    private var burstIgnored = false

    /// Quiet period that ends a burst for phase-less wheel-mouse scrolling.
    private let burstEndInterval: TimeInterval = 0.18

    init(settings: SettingsService, overlayController: OverlayController) {
        self.settings = settings
        self.overlayController = overlayController

        // Tear the monitor down entirely while disabled instead of filtering
        // per-event — no wasted wakeups, and any visible overlay goes away.
        settings.$enabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                if enabled {
                    self?.start()
                } else {
                    self?.stop()
                    self?.overlayController.hide()
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        guard scrollEventMonitor == nil, settings.enabled else { return }
        scrollEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
        }
    }

    func stop() {
        if let scrollEventMonitor {
            NSEvent.removeMonitor(scrollEventMonitor)
            self.scrollEventMonitor = nil
        }
        burstEndTimer?.invalidate()
        machine.reset()
        clearBurst()
    }

    private func handleScroll(_ event: NSEvent) {
        if !machine.burstActive {
            // Burst start: capture the target once, where the hand already is.
            burstTarget = nil
            burstIgnored = false
            if let target = TargetResolver.resolve(atCocoaPoint: NSEvent.mouseLocation),
               !settings.isIgnored(bundleIdentifier: target.bundleIdentifier) {
                burstTarget = target
            } else {
                burstIgnored = true
            }
        }

        let gateOpen = burstTarget != nil && !burstIgnored && modifierSatisfied(event)
        let output = machine.scrollEvent(
            absDeltaY: abs(event.scrollingDeltaY),
            gestureEnded: event.phase == .ended || event.phase == .cancelled,
            momentumEnded: event.momentumPhase == .ended,
            threshold: settings.scrollThreshold,
            gateOpen: gateOpen
        )

        if let target = burstTarget {
            switch output.display {
            case .show:
                overlayController.show(for: target, at: NSEvent.mouseLocation)
            case .extend:
                // Also re-shows if a corridor-exit hid the overlay mid-burst
                // (once the cooldown passes) — no dead zone on long scrolls.
                overlayController.extendOrReshow(for: target)
            case .none:
                break
            }
        }

        if output.burstEnded {
            burstEndTimer?.invalidate()
            clearBurst()
        } else {
            burstEndTimer?.invalidate()
            burstEndTimer = Timer.scheduledTimer(withTimeInterval: burstEndInterval, repeats: false) { [weak self] _ in
                self?.machine.quietTimeout()
                self?.clearBurst()
            }
        }
    }

    private func modifierSatisfied(_ event: NSEvent) -> Bool {
        guard let flag = settings.requiredModifier.flag else { return true }
        return event.modifierFlags.contains(flag)
    }

    private func clearBurst() {
        burstTarget = nil
        burstIgnored = false
    }
}
