import AppKit

/// Watches global scroll events and groups them into bursts. The overlay shows
/// after a qualifying burst *ends* (brief quiet period), never on the first tick.
final class ScrollMonitor {
    private let settings: SettingsService
    private let overlayController: OverlayController

    private var scrollEventMonitor: Any?
    private var burstEndTimer: Timer?

    // Active-burst state
    private var burstTarget: ScrollTarget?
    private var burstIgnored = false
    private var burstQualified = false
    private var accumulatedDelta: CGFloat = 0

    /// Quiet period after the last scroll event that ends a burst.
    private let burstEndInterval: TimeInterval = 0.18

    init(settings: SettingsService, overlayController: OverlayController) {
        self.settings = settings
        self.overlayController = overlayController
    }

    func start() {
        guard scrollEventMonitor == nil else { return }
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
        resetBurst()
    }

    private func handleScroll(_ event: NSEvent) {
        guard settings.enabled else { return }

        if burstTarget == nil && !burstIgnored {
            // Burst start: capture the target once, where the hand already is.
            if let target = TargetResolver.resolve(atCocoaPoint: NSEvent.mouseLocation),
               !settings.isIgnored(bundleIdentifier: target.bundleIdentifier) {
                burstTarget = target
            } else {
                // Track the burst so we don't re-resolve on every tick, but never show.
                burstIgnored = true
            }
        }

        accumulatedDelta += abs(event.scrollingDeltaY)

        if let target = burstTarget {
            // Show as soon as the burst crosses the threshold — even mid-gesture.
            // (The max(_, 1) keeps a zero threshold from firing on the delta-less
            // touch events at gesture start.)
            if !burstQualified, accumulatedDelta >= max(settings.scrollThreshold, 1) {
                burstQualified = true
                overlayController.show(for: target, at: NSEvent.mouseLocation)
            } else if burstQualified {
                // Continued scrolling keeps the overlay alive.
                overlayController.extend()
            }
        }

        // The burst ends when the gesture or its momentum ends, or — for wheel
        // mice, which carry no phase info — after a quiet period.
        if event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended {
            burstEndTimer?.invalidate()
            resetBurst()
            return
        }

        burstEndTimer?.invalidate()
        burstEndTimer = Timer.scheduledTimer(withTimeInterval: burstEndInterval, repeats: false) { [weak self] _ in
            self?.resetBurst()
        }
    }

    private func resetBurst() {
        burstTarget = nil
        burstIgnored = false
        burstQualified = false
        accumulatedDelta = 0
    }
}
