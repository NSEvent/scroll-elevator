import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    let openWelcome: () -> Void

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings, openWelcome: openWelcome)
                .tabItem { Label("General", systemImage: "gearshape") }
            ButtonsSettingsTab(settings: settings)
                .tabItem { Label("Buttons", systemImage: "circle.circle") }
            AppsSettingsTab(settings: settings)
                .tabItem { Label("Apps", systemImage: "app.badge.checkmark") }
        }
        .frame(width: 480, height: 500)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject var settings: SettingsService
    let openWelcome: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityGranted = JumpDispatcher.isTrusted

    private let accessibilityPoll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle("Show elevator buttons after scrolling", isOn: $settings.enabled)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }

            Section("Hiding") {
                Toggle("Never hide automatically", isOn: $settings.neverHide)
                if !settings.neverHide {
                    LabeledSlider(
                        label: "Hide after",
                        value: $settings.hideTimeout,
                        range: 1...6,
                        format: { String(format: "%.1f s", $0) }
                    )
                }
            }

            Section("Modifier gate") {
                Picker("Require modifier while scrolling", selection: $settings.requiredModifier) {
                    ForEach(ModifierGate.allCases) { gate in
                        Text(gate.label).tag(gate)
                    }
                }
            }

            Section {
                if accessibilityGranted {
                    Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Accessibility access is required to send jump commands", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Grant Accessibility Access…") {
                        JumpDispatcher.promptForAccessibilityIfNeeded()
                    }
                }
                Button("Open Welcome Guide…", action: openWelcome)
            }
        }
        .formStyle(.grouped)
        .onReceive(accessibilityPoll) { _ in
            accessibilityGranted = JumpDispatcher.isTrusted
        }
    }
}

// MARK: - Buttons

private struct ButtonsSettingsTab: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        Form {
            Section("Placement") {
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

            Section("Appearance") {
                LabeledSlider(
                    label: "Idle opacity",
                    value: $settings.idleOpacity,
                    range: 0.1...1.0,
                    format: { String(format: "%.0f %%", $0 * 100) }
                )
                HStack {
                    Spacer()
                    ButtonPreview(idleOpacity: settings.idleOpacity)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Live preview of the buttons at the chosen idle opacity, over a mock page.
private struct ButtonPreview: View {
    let idleOpacity: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color(nsColor: .textBackgroundColor), Color(nsColor: .windowBackgroundColor)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            VStack(alignment: .leading, spacing: 7) {
                ForEach(0..<6, id: \.self) { row in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: row == 5 ? 90 : 160, height: 6)
                }
            }
            HStack(spacing: 28) {
                JumpButtonVisual(systemImage: "arrow.up.to.line", diameter: 34)
                    .opacity(idleOpacity)
                JumpButtonVisual(systemImage: "arrow.down.to.line", diameter: 34)
                    .opacity(idleOpacity)
            }
        }
        .frame(width: 240, height: 96)
    }
}

// MARK: - Apps

private struct AppsSettingsTab: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        Form {
            Section("App rules") {
                if settings.appRules.isEmpty {
                    Text("No app rules. Every app uses Automatic: scrollbar control when available, with sensible per-app key fallbacks (Finder uses Home/End, terminals use ⌘Home/⌘End).")
                        .foregroundStyle(.secondary)
                }
                ForEach(sortedRuleBundleIDs, id: \.self) { bundleID in
                    AppRuleRow(
                        bundleID: bundleID,
                        rule: ruleBinding(for: bundleID),
                        onRemove: { settings.appRules.removeValue(forKey: bundleID) }
                    )
                }
                Menu("Add Rule for Running App…") {
                    ForEach(addableRunningApps(), id: \.bundleID) { app in
                        Button(app.name) {
                            settings.appRules[app.bundleID] = .ignore
                        }
                    }
                }
            }

            Section {
                Text("Automatic moves the scrollbar of the scroll view under your pointer directly — no keystrokes, and background windows scroll without coming forward. Key rules are for apps where that isn't available or you want a specific command.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var sortedRuleBundleIDs: [String] {
        settings.appRules.keys.sorted {
            displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
        }
    }

    private func ruleBinding(for bundleID: String) -> Binding<JumpRule> {
        Binding(
            get: { settings.appRules[bundleID] ?? .auto },
            set: { settings.appRules[bundleID] = $0 }
        )
    }

    private func addableRunningApps() -> [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      bundleID != Bundle.main.bundleIdentifier,
                      settings.appRules[bundleID] == nil
                else { return nil }
                return (app.localizedName ?? bundleID, bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct AppRuleRow: View {
    let bundleID: String
    @Binding var rule: JumpRule
    let onRemove: () -> Void

    var body: some View {
        HStack {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            Text(displayName(for: bundleID))
                .lineLimit(1)
            Spacer()
            Picker("", selection: $rule) {
                ForEach(JumpRule.allCases) { rule in
                    Text(rule.label).tag(rule)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var appIcon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
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

// MARK: - Shared controls

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
