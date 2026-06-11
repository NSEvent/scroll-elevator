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
            let anchor = NSEvent.mouseLocation
            if let target = TargetResolver.resolve(atCocoaPoint: anchor),
               !settings.isIgnored(bundleIdentifier: target.bundleIdentifier) {
                burstTarget = target
            } else {
                // Track the burst so we don't re-resolve on every tick, but never show.
                burstIgnored = true
            }
        }

        accumulatedDelta += abs(event.scrollingDeltaY)

        burstEndTimer?.invalidate()
        burstEndTimer = Timer.scheduledTimer(withTimeInterval: burstEndInterval, repeats: false) { [weak self] _ in
            self?.burstDidEnd()
        }
    }

    private func burstDidEnd() {
        defer { resetBurst() }
        guard let target = burstTarget,
              accumulatedDelta >= settings.scrollThreshold else { return }
        overlayController.show(for: target)
    }

    private func resetBurst() {
        burstTarget = nil
        burstIgnored = false
        accumulatedDelta = 0
    }
}
