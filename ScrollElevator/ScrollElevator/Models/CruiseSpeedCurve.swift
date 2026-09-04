import Foundation

/// The hold-to-cruise acceleration curve, separated from the overlay so its
/// legacy behavior and user-controlled scaling stay deterministic and testable.
enum CruiseSpeedCurve {
    static let defaultMultiplier = 1.0
    static let supportedMultipliers = 0.25...2.0

    private static let basePointsPerSecond = 500.0
    private static let acceleration = 700.0
    private static let maximumPointsPerSecond = 2_500.0

    static func clampedMultiplier(_ multiplier: Double) -> Double {
        guard multiplier.isFinite else { return defaultMultiplier }
        return min(max(multiplier, supportedMultipliers.lowerBound), supportedMultipliers.upperBound)
    }

    static func pointsPerSecond(elapsed: TimeInterval, multiplier: Double) -> Double {
        let unscaled = min(
            maximumPointsPerSecond,
            basePointsPerSecond + acceleration * max(elapsed, 0)
        )
        return unscaled * clampedMultiplier(multiplier)
    }

    static func pixelsPerTick(
        elapsed: TimeInterval,
        multiplier: Double,
        tickRate: Double = 60
    ) -> Int32 {
        guard tickRate.isFinite, tickRate > 0 else { return 0 }
        return Int32((pointsPerSecond(elapsed: elapsed, multiplier: multiplier) / tickRate).rounded())
    }
}
