import SwiftUI
import AppKit

/// First-run welcome: what the app does, a visual of the overlay, and the
/// Accessibility grant — the one piece of setup the app can't do itself.
struct OnboardingView: View {
    @ObservedObject var settings: SettingsService
    let dismiss: () -> Void

    @State private var accessibilityGranted = JumpDispatcher.isTrusted
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private let accessibilityPoll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                Text("Scroll Elevator")
                    .font(.title.bold())
                Text("Elevator buttons, right where your hand already is.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            OverlayMock()

            VStack(alignment: .leading, spacing: 10) {
                OnboardingBullet(
                    symbol: "scroll",
                    text: "Scroll anywhere — two translucent buttons appear around your cursor."
                )
                OnboardingBullet(
                    symbol: "arrow.up.to.line",
                    text: "Click to jump the scrolled window to its top or bottom. Hold to cruise — the page glides while you hold."
                )
                OnboardingBullet(
                    symbol: "cursorarrow.motionlines",
                    text: "Move your mouse away and they vanish. They never steal focus or clicks."
                )
            }
            .frame(maxWidth: 380, alignment: .leading)

            GroupBox {
                HStack {
                    if accessibilityGranted {
                        Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                    } else {
                        Label("Accessibility access is needed to perform jumps", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Grant Access…") {
                            JumpDispatcher.promptForAccessibilityIfNeeded()
                        }
                    }
                }
                .padding(4)
            }
            .frame(maxWidth: 380)

            Toggle("Launch Scroll Elevator at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.set(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }

            Button(action: dismiss) {
                Text("Get Started")
                    .frame(maxWidth: 200)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 24)
        }
        .frame(width: 460)
        .onReceive(accessibilityPoll) { _ in
            accessibilityGranted = JumpDispatcher.isTrusted
        }
    }
}

/// A mock page with the elevator buttons over it, matching the real overlay.
private struct OverlayMock: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color(nsColor: .textBackgroundColor), Color(nsColor: .windowBackgroundColor)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<7, id: \.self) { row in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: row % 3 == 2 ? 180 : 300, height: 7)
                }
            }
            VStack(spacing: 26) {
                JumpButtonVisual(systemImage: "arrow.up.to.line", diameter: 38)
                Image(systemName: "cursorarrow")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                JumpButtonVisual(systemImage: "arrow.down.to.line", diameter: 38)
            }
        }
        .frame(width: 380, height: 170)
    }
}

private struct OnboardingBullet: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                // Claim the vertical space wrapping needs; otherwise the host
                // view's fittingSize under-measures and the last bullet truncates.
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }
}
