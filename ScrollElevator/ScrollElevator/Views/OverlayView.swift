import SwiftUI

/// The transient elevator buttons: jump-to-top above the cursor anchor,
/// jump-to-bottom below it. Small, predictable, easy to ignore.
struct OverlayView: View {
    let buttonDiameter: CGFloat
    let spacing: CGFloat
    let idleOpacity: Double
    let dimTop: Bool
    let dimBottom: Bool
    let onJump: (JumpDirection) -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        // Hover is reported per-button, not on the stack: the cursor parks in
        // the gap between the buttons when the overlay appears, and stack-wide
        // hover would permanently pause the hide timer.
        VStack(spacing: spacing) {
            JumpButton(
                systemImage: "arrow.up.to.line",
                diameter: buttonDiameter,
                idleOpacity: idleOpacity,
                dimmed: dimTop,
                helpText: "Jump to top",
                onHoverChange: onHoverChange,
                action: { onJump(.top) }
            )
            JumpButton(
                systemImage: "arrow.down.to.line",
                diameter: buttonDiameter,
                idleOpacity: idleOpacity,
                dimmed: dimBottom,
                helpText: "Jump to bottom",
                onHoverChange: onHoverChange,
                action: { onJump(.bottom) }
            )
        }
        .padding(12)
    }
}

private struct JumpButton: View {
    let systemImage: String
    let diameter: CGFloat
    let idleOpacity: Double
    let dimmed: Bool
    let helpText: String
    let onHoverChange: (Bool) -> Void
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            JumpButtonVisual(systemImage: systemImage, diameter: diameter)
                // Edge-aware: a button that can't do anything (already at the
                // top/bottom) fades further back but stays clickable — content
                // can move under a stale reading.
                .opacity(currentOpacity)
                .scaleEffect(hovering ? 1.12 : 1.0)
                .shadow(color: .black.opacity(hovering ? 0.25 : 0), radius: hovering ? 6 : 0, y: 1)
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { value in
            hovering = value
            onHoverChange(value)
        }
        .help(helpText)
    }

    private var currentOpacity: Double {
        if hovering { return dimmed ? 0.6 : 1.0 }
        return idleOpacity * (dimmed ? 0.4 : 1.0)
    }
}

/// The bare button appearance, shared with the settings preview and the
/// onboarding mock so they always match the real overlay.
struct JumpButtonVisual: View {
    let systemImage: String
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: diameter, height: diameter)
    }
}
