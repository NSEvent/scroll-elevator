import SwiftUI

/// The transient elevator buttons: jump-to-top above the cursor anchor,
/// jump-to-bottom below it. Small, predictable, easy to ignore.
struct OverlayView: View {
    let buttonDiameter: CGFloat
    let spacing: CGFloat
    let onJump: (JumpDirection) -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        VStack(spacing: spacing) {
            JumpButton(systemImage: "arrow.up.to.line", diameter: buttonDiameter) {
                onJump(.top)
            }
            JumpButton(systemImage: "arrow.down.to.line", diameter: buttonDiameter) {
                onJump(.bottom)
            }
        }
        .padding(12)
        .onHover(perform: onHoverChange)
    }
}

private struct JumpButton: View {
    let systemImage: String
    let diameter: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
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
            // Unobtrusive at rest; solid once the pointer aims at it.
            .opacity(hovering ? 1.0 : 0.3)
            .scaleEffect(hovering ? 1.12 : 1.0)
            .shadow(color: .black.opacity(hovering ? 0.25 : 0), radius: hovering ? 6 : 0, y: 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
