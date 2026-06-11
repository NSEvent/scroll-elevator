import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        Form {
            Section {
                Toggle("Show elevator buttons after scrolling", isOn: $settings.enabled)
            }

            Section("Behavior") {
                LabeledSlider(
                    label: "Hide after",
                    value: $settings.hideTimeout,
                    range: 1...6,
                    format: { String(format: "%.1f s", $0) }
                )
                LabeledSlider(
                    label: "Button distance",
                    value: $settings.placementDistance,
                    range: 30...80,
                    format: { String(format: "%.0f pt", $0) }
                )
                LabeledSlider(
                    label: "Scroll threshold",
                    value: $settings.scrollThreshold,
                    range: 0...200,
                    format: { String(format: "%.0f pt", $0) }
                )
            }

            Section("Ignored Apps") {
                if settings.ignoredBundleIDs.isEmpty {
                    Text("No ignored apps. The overlay shows for every app.")
                        .foregroundStyle(.secondary)
                }
                ForEach(settings.ignoredBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(displayName(for: bundleID))
                        Spacer()
                        Button(role: .destructive) {
                            settings.ignoredBundleIDs.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                Menu("Add Running App…") {
                    ForEach(addableRunningApps(), id: \.bundleID) { app in
                        Button(app.name) {
                            settings.ignoredBundleIDs.append(app.bundleID)
                        }
                    }
                }
            }

            Section {
                if JumpDispatcher.isTrusted {
                    Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Accessibility access is required to send jump commands", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Grant Accessibility Access…") {
                        JumpDispatcher.promptForAccessibilityIfNeeded()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 460)
    }

    private func displayName(for bundleID: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = app.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    private func addableRunningApps() -> [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      bundleID != Bundle.main.bundleIdentifier,
                      !settings.ignoredBundleIDs.contains(bundleID)
                else { return nil }
                return (app.localizedName ?? bundleID, bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        HStack {
            Text(label)
            Slider(value: $value, in: range)
            Text(format(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }
}
