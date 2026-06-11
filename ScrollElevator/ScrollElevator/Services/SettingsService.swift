import Foundation
import Combine

final class SettingsService: ObservableObject {
    private enum Key {
        static let enabled = "enabled"
        static let neverHide = "neverHide"
        static let hideTimeout = "hideTimeout"
        static let placementDistance = "placementDistance"
        static let scrollThreshold = "scrollThreshold"
        static let ignoredBundleIDs = "ignoredBundleIDs"
    }

    private let defaults = UserDefaults.standard

    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Key.enabled) }
    }

    /// When true (the default), the overlay never hides on a timer — only when
    /// the pointer leaves the corridor or a button is clicked.
    @Published var neverHide: Bool {
        didSet { defaults.set(neverHide, forKey: Key.neverHide) }
    }

    /// Seconds the overlay stays up before fading out (when not hovered).
    /// Only applies when neverHide is off.
    @Published var hideTimeout: Double {
        didSet { defaults.set(hideTimeout, forKey: Key.hideTimeout) }
    }

    /// Distance in points from the cursor anchor to each button's center.
    @Published var placementDistance: Double {
        didSet { defaults.set(placementDistance, forKey: Key.placementDistance) }
    }

    /// Accumulated |scrollingDeltaY| a burst must reach before the overlay shows.
    @Published var scrollThreshold: Double {
        didSet { defaults.set(scrollThreshold, forKey: Key.scrollThreshold) }
    }

    @Published var ignoredBundleIDs: [String] {
        didSet { defaults.set(ignoredBundleIDs, forKey: Key.ignoredBundleIDs) }
    }

    init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.neverHide: true,
            Key.hideTimeout: 2.5,
            Key.placementDistance: 56.0,
            Key.scrollThreshold: 10.0,
            Key.ignoredBundleIDs: [String](),
        ])
        enabled = defaults.bool(forKey: Key.enabled)
        neverHide = defaults.bool(forKey: Key.neverHide)
        hideTimeout = defaults.double(forKey: Key.hideTimeout)
        placementDistance = defaults.double(forKey: Key.placementDistance)
        scrollThreshold = defaults.double(forKey: Key.scrollThreshold)
        ignoredBundleIDs = defaults.stringArray(forKey: Key.ignoredBundleIDs) ?? []
    }

    func isIgnored(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return ignoredBundleIDs.contains(bundleIdentifier)
    }
}
