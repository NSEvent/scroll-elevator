import SwiftUI

/// Press lifecycle reported to the controller. Releasing outside the button
/// cancels — no jump fires — matching standard button semantics.
enum PressPhase {
    case began
    case releasedInside
    case releasedOutside
}

/// Hover/press state for the overlay buttons. The panel is permanently
/// click-through (so scroll gestures fall through to the app beneath instead of
/// being stolen), which means SwiftUI never sees the mouse. The controller
/// drives these from a global mouse-move monitor (hover) and a CGEventTap
/// (press), and the buttons render from them.
final class OverlayInputState: ObservableObject {
    @Published var hovered: JumpDirection?
    @Published var pressed: JumpDirection?
}

/// The transient elevator buttons: jump-to-top above the cursor anchor,
/// jump-to-bottom below it. Small, predictable, easy to ignore. Display-only —
/// all interaction is fed in through `input`.
struct OverlayView: View {
    let buttonDiameter: CGFloat
    let spacing: CGFloat
    let idleOpacity: Double
    let dimTop: Bool
    let dimBottom: Bool
    @ObservedObject var input: OverlayInputState

    var body: some View {
        VStack(spacing: spacing) {
            JumpButton(
                systemImage: "arrow.up.to.line",
                diameter: buttonDiameter,
                idleOpacity: idleOpacity,
                dimmed: dimTop,
                helpText: "Jump to top — hold to cruise",
                hovering: input.hovered == .top,
                pressed: input.pressed == .top
            )
            JumpButton(
                systemImage: "arrow.down.to.line",
                diameter: buttonDiameter,
                idleOpacity: idleOpacity,
                dimmed: dimBottom,
                helpText: "Jump to bottom — hold to cruise",
                hovering: input.hovered == .bottom,
                pressed: input.pressed == .bottom
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
    let hovering: Bool
    let pressed: Bool

    var body: some View {
        JumpButtonVisual(systemImage: systemImage, diameter: diameter)
            // Edge-aware: a button that can't do anything (already at the
            // top/bottom) fades further back but stays usable — content
            // can move under a stale reading.
            .opacity(currentOpacity)
            .scaleEffect(pressed ? 0.92 : (hovering ? 1.12 : 1.0))
            .shadow(color: .black.opacity(hovering ? 0.25 : 0), radius: hovering ? 6 : 0, y: 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.08), value: pressed)
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
