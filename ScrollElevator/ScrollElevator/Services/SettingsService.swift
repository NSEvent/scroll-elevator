import Foundation
import Combine

final class SettingsService: ObservableObject {
    private enum Key {
        static let enabled = "enabled"
        static let neverHide = "neverHide"
        static let hideTimeout = "hideTimeout"
        static let placementDistance = "placementDistance"
        static let scrollThreshold = "scrollThreshold"
        static let idleOpacity = "idleOpacity"
        static let requiredModifier = "requiredModifier"
        static let appRules = "appRules"
        static let ignoredBundleIDs = "ignoredBundleIDs"  // legacy, migrated into appRules
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
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

    /// Button opacity at rest (hover is always fully opaque).
    @Published var idleOpacity: Double {
        didSet { defaults.set(idleOpacity, forKey: Key.idleOpacity) }
    }

    /// Modifier the user must hold while scrolling for the overlay to show.
    @Published var requiredModifier: ModifierGate {
        didSet { defaults.set(requiredModifier.rawValue, forKey: Key.requiredModifier) }
    }

    /// Per-app jump rules keyed by bundle identifier. Absent = .auto.
    @Published var appRules: [String: JumpRule] {
        didSet {
            defaults.set(appRules.mapValues(\.rawValue), forKey: Key.appRules)
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.neverHide: true,
            Key.hideTimeout: 2.5,
            Key.placementDistance: 56.0,
            Key.scrollThreshold: 10.0,
            Key.idleOpacity: 0.3,
            Key.requiredModifier: ModifierGate.none.rawValue,
            Key.hasCompletedOnboarding: false,
        ])
        enabled = defaults.bool(forKey: Key.enabled)
        neverHide = defaults.bool(forKey: Key.neverHide)
        hideTimeout = defaults.double(forKey: Key.hideTimeout)
        placementDistance = defaults.double(forKey: Key.placementDistance)
        scrollThreshold = defaults.double(forKey: Key.scrollThreshold)
        idleOpacity = defaults.double(forKey: Key.idleOpacity)
        requiredModifier = ModifierGate(
            rawValue: defaults.string(forKey: Key.requiredModifier) ?? ""
        ) ?? .none
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)

        var rules: [String: JumpRule] = [:]
        if let stored = defaults.dictionary(forKey: Key.appRules) as? [String: String] {
            for (bundleID, raw) in stored {
                if let rule = JumpRule(rawValue: raw) { rules[bundleID] = rule }
            }
        }
        // Migrate the legacy ignore list into app rules.
        if let legacy = defaults.stringArray(forKey: Key.ignoredBundleIDs), !legacy.isEmpty {
            for bundleID in legacy where rules[bundleID] == nil {
                rules[bundleID] = .ignore
            }
            defaults.removeObject(forKey: Key.ignoredBundleIDs)
        }
        appRules = rules
        if !rules.isEmpty {
            defaults.set(rules.mapValues(\.rawValue), forKey: Key.appRules)
        }
    }

    func rule(for bundleIdentifier: String?) -> JumpRule {
        guard let bundleIdentifier else { return .auto }
        return appRules[bundleIdentifier] ?? .auto
    }

    func isIgnored(bundleIdentifier: String?) -> Bool {
        rule(for: bundleIdentifier) == .ignore
    }
}
