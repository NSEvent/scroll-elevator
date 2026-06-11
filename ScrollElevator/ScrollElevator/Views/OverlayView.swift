import SwiftUI

/// Press lifecycle reported to the controller. Releasing outside the button
/// cancels — no jump fires — matching standard button semantics.
enum PressPhase {
    case began
    case releasedInside
    case releasedOutside
}

/// The transient elevator buttons: jump-to-top above the cursor anchor,
/// jump-to-bottom below it. Small, predictable, easy to ignore.
struct OverlayView: View {
    let buttonDiameter: CGFloat
    let spacing: CGFloat
    let idleOpacity: Double
    let dimTop: Bool
    let dimBottom: Bool
    /// Reports the press lifecycle; the controller decides jump (quick
    /// release), cruise (hold), or cancel (released off the button).
    let onPress: (JumpDirection, PressPhase) -> Void
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
                helpText: "Jump to top — hold to cruise",
                onHoverChange: onHoverChange,
                onPress: { phase in onPress(.top, phase) }
            )
            JumpButton(
                systemImage: "arrow.down.to.line",
                diameter: buttonDiameter,
                idleOpacity: idleOpacity,
                dimmed: dimBottom,
                helpText: "Jump to bottom — hold to cruise",
                onHoverChange: onHoverChange,
                onPress: { phase in onPress(.bottom, phase) }
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
    let onPress: (PressPhase) -> Void

    @State private var hovering = false
    @State private var pressed = false
    @State private var pressActive = false

    var body: some View {
        JumpButtonVisual(systemImage: systemImage, diameter: diameter)
            // Edge-aware: a button that can't do anything (already at the
            // top/bottom) fades further back but stays clickable — content
            // can move under a stale reading.
            .opacity(currentOpacity)
            .scaleEffect(pressed ? 0.92 : (hovering ? 1.12 : 1.0))
            .shadow(color: .black.opacity(hovering ? 0.25 : 0), radius: hovering ? 6 : 0, y: 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.08), value: pressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !pressActive {
                            pressActive = true
                            onPress(.began)
                        }
                        // Pressed look tracks whether the pointer is still on
                        // the button, like a standard control.
                        pressed = isInside(value.location)
                    }
                    .onEnded { value in
                        pressActive = false
                        pressed = false
                        onPress(isInside(value.location) ? .releasedInside : .releasedOutside)
                    }
            )
            .onHover { value in
                hovering = value
                onHoverChange(value)
            }
            .help(helpText)
    }

    /// Inside the button circle, with a little slop for micro-drift.
    private func isInside(_ point: CGPoint) -> Bool {
        let center = diameter / 2
        return hypot(point.x - center, point.y - center) <= diameter / 2 + 6
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
