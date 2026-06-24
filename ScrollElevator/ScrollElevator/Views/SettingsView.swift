import SwiftUI
import AppKit

// MARK: - Theme

/// The Settings window is styled as a small elevator control panel, echoing the
/// app icon: a graphite plate with an amber "lit call button" accent.
private enum Theme {
    /// Brand amber — the lit up-arrow glow from the icon. Brighter in dark mode,
    /// deeper in light mode so it stays legible on tinted controls either way.
    static let amber = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0.99, green: 0.76, blue: 0.34, alpha: 1)
            : NSColor(srgbRed: 0.80, green: 0.51, blue: 0.05, alpha: 1)
    })

    /// Fixed graphite for the branded header, matching the icon's machined plate
    /// regardless of system appearance.
    static let graphiteTop = Color(.sRGB, red: 0.21, green: 0.22, blue: 0.24, opacity: 1)
    static let graphiteBottom = Color(.sRGB, red: 0.115, green: 0.12, blue: 0.135, opacity: 1)
}

// MARK: - Root

struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    let openWelcome: () -> Void

    @State private var pane: Pane = .general

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader()

            PaneSelector(selection: $pane)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider().opacity(0.4)

            ScrollView {
                Group {
                    switch pane {
                    case .general: GeneralPane(settings: settings, openWelcome: openWelcome)
                    case .buttons: ButtonsPane(settings: settings)
                    case .apps:    AppsPane(settings: settings)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Tall enough that the densest pane (Buttons) never scrolls; shorter
        // panes simply leave breathing room at the bottom.
        .frame(width: 520, height: 780)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Theme.amber)
    }
}

private enum Pane: String, CaseIterable, Identifiable {
    case general, buttons, apps
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .buttons: "Buttons"
        case .apps:    "Apps"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .buttons: "arrow.up.and.down.circle.fill"
        case .apps:    "square.grid.2x2.fill"
        }
    }
}

// MARK: - Header

private struct SettingsHeader: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        return "v\(v)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Scroll Elevator")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text("Jump to the top or bottom, wherever your cursor is.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 8)

            VStack(spacing: 7) {
                CallGlyphs()
                Text(version)
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Theme.graphiteTop, Theme.graphiteBottom],
                    startPoint: .top, endPoint: .bottom
                )
                LinearGradient(
                    colors: [.white.opacity(0.06), .clear],
                    startPoint: .top, endPoint: .center
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.amber.opacity(0.5)).frame(height: 1)
        }
    }
}

/// The icon's signature: an amber-lit up call, an idle down call.
private struct CallGlyphs: View {
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "arrow.up.to.line")
                .foregroundStyle(Theme.amber)
                .shadow(color: Theme.amber.opacity(0.7), radius: 4)
            Image(systemName: "arrow.down.to.line")
                .foregroundStyle(.white.opacity(0.3))
        }
        .font(.system(size: 12, weight: .bold))
    }
}

// MARK: - Pane selector

private struct PaneSelector: View {
    @Binding var selection: Pane

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Pane.allCases) { pane in
                let isSelected = selection == pane
                Button {
                    withAnimation(.easeOut(duration: 0.14)) { selection = pane }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: pane.symbol)
                            .font(.system(size: 11, weight: .semibold))
                        Text(pane.title)
                    }
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(isSelected ? Theme.amber : Color.secondary)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.amber.opacity(isSelected ? 0.16 : 0))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Theme.amber.opacity(isSelected ? 0.35 : 0), lineWidth: 1)
                            )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - Card

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    var footnote: String? = nil
    var indentsContent: Bool = true
    var resetDisabled: Bool = false
    var onReset: (() -> Void)? = nil
    @ViewBuilder let content: Content

    /// Aligns indented content roughly under the section title (past the icon).
    private let contentIndent: CGFloat = 24

    init(
        title: String,
        systemImage: String,
        footnote: String? = nil,
        indentsContent: Bool = true,
        resetDisabled: Bool = false,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.footnote = footnote
        self.indentsContent = indentsContent
        self.resetDisabled = resetDisabled
        self.onReset = onReset
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(title.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                if let onReset {
                    Spacer(minLength: 8)
                    Button(action: onReset) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.amber)
                    .disabled(resetDisabled)
                    .opacity(resetDisabled ? 0.35 : 1)
                    .help("Restore this section to its default settings")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                content

                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, indentsContent ? contentIndent : 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @ObservedObject var settings: SettingsService
    let openWelcome: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityGranted = JumpDispatcher.isTrusted

    private let accessibilityPoll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Behavior", systemImage: "switch.2") {
                Toggle("Show elevator buttons after scrolling", isOn: $settings.enabled)
                Divider().opacity(0.4)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }

            SettingsCard(title: "Hiding", systemImage: "eye.slash") {
                Toggle("Never hide automatically", isOn: $settings.neverHide)
                if !settings.neverHide {
                    Divider().opacity(0.4)
                    TunedSlider(
                        label: "Hide after",
                        value: $settings.hideTimeout,
                        range: 1...6,
                        unit: { String(format: "%.1f s", $0) }
                    )
                }
            }

            SettingsCard(
                title: "Modifier Gate",
                systemImage: "command",
                footnote: "Require a held modifier while scrolling for the buttons to appear."
            ) {
                Picker("Require modifier while scrolling", selection: $settings.requiredModifier) {
                    ForEach(ModifierGate.allCases) { gate in
                        Text(gate.label).tag(gate)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsCard(title: "Accessibility", systemImage: "accessibility") {
                if accessibilityGranted {
                    StatusChip(
                        text: "Accessibility access granted",
                        systemImage: "checkmark.seal.fill",
                        tint: .green
                    )
                } else {
                    StatusChip(
                        text: "Required to send jump commands",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                    Button("Grant Accessibility Access…") {
                        JumpDispatcher.promptForAccessibilityIfNeeded()
                    }
                }
                Divider().opacity(0.4)
                Button(action: openWelcome) {
                    Label("Open Welcome Guide", systemImage: "sparkles")
                }
                .buttonStyle(.link)
            }
        }
        .onReceive(accessibilityPoll) { _ in
            accessibilityGranted = JumpDispatcher.isTrusted
        }
    }
}

private struct StatusChip: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(text).font(.callout)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.12)))
    }
}

// MARK: - Buttons

private struct ButtonsPane: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        VStack(spacing: 16) {
            LivePreviewCard(distance: settings.placementDistance, idleOpacity: settings.idleOpacity)

            SettingsCard(
                title: "Placement",
                systemImage: "arrow.up.and.down",
                resetDisabled: settings.isPlacementDefault,
                onReset: { withAnimation(.easeOut(duration: 0.2)) { settings.resetPlacement() } }
            ) {
                TunedSlider(
                    label: "Button distance",
                    value: $settings.placementDistance,
                    range: 30...160,
                    unit: { String(format: "%.0f pt", $0) }
                )
                Divider().opacity(0.4)
                TunedSlider(
                    label: "Scroll threshold",
                    value: $settings.scrollThreshold,
                    range: 0...200,
                    unit: { String(format: "%.0f pt", $0) }
                )
            }

            SettingsCard(
                title: "Appearance",
                systemImage: "circle.lefthalf.filled",
                footnote: "Buttons rest at this opacity and become fully opaque on hover.",
                resetDisabled: settings.isAppearanceDefault,
                onReset: { withAnimation(.easeOut(duration: 0.2)) { settings.resetAppearance() } }
            ) {
                TunedSlider(
                    label: "Idle opacity",
                    value: $settings.idleOpacity,
                    range: 0.1...1.0,
                    unit: { String(format: "%.0f%%", $0 * 100) }
                )
            }
        }
    }
}

/// A live mock of the overlay over a small window, reacting to the distance and
/// opacity sliders. Uses the real `JumpButtonVisual` so it always matches the
/// actual overlay buttons.
private struct LivePreviewCard: View {
    let distance: Double
    let idleOpacity: Double

    /// Map the real 30–160 pt distance onto the preview's compressed scale.
    private var gap: CGFloat {
        let t = (distance - 30) / (160 - 30)
        return 12 + CGFloat(t) * 50
    }

    /// Trailing inset per mock text line — full-width lines (0) interrupted by
    /// a few short ones to suggest paragraph breaks.
    private let lineInsets: [CGFloat] = [0, 0, 64, 0, 0, 38, 0, 96]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    // Darken the mock page so it recedes instead of pulling focus.
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.black.opacity(0.14), .black.opacity(0.26)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                )

            // Mock page content. Lines flow the full width of the page; a
            // varied trailing inset on some rows reads like paragraph text.
            VStack(alignment: .leading, spacing: 9) {
                ForEach(lineInsets.indices, id: \.self) { row in
                    Capsule()
                        .fill(.primary.opacity(0.09))
                        .frame(height: 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, lineInsets[row])
                }
            }
            .padding(.top, 30)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Traffic-light dots.
            HStack(spacing: 6) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 0.31, green: 0.79, blue: 0.27)).frame(width: 9, height: 9)
                Spacer()
            }
            .padding(.top, 11)
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // The overlay itself: anchored on the cursor, a button each way.
            VStack(spacing: gap) {
                JumpButtonVisual(systemImage: "arrow.up.to.line", diameter: 34)
                    .opacity(idleOpacity)
                Image(systemName: "cursorarrow")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                JumpButtonVisual(systemImage: "arrow.down.to.line", diameter: 34)
                    .opacity(idleOpacity)
            }
            .animation(.easeOut(duration: 0.12), value: gap)
        }
        .frame(height: 224)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

private struct TunedSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: (Double) -> String

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(unit(value))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.amber.opacity(0.14)))
            }
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Apps

private struct AppsPane: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(
                title: "App Rules",
                systemImage: "slider.horizontal.3",
                footnote: "Add a rule only for exceptions — to ignore an app entirely, or force it to jump with a specific keyboard shortcut instead."
            ) {
                if settings.appRules.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.amber)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Works automatically everywhere")
                                .font(.callout.weight(.medium))
                            Text("Scroll Elevator already jumps whatever window your pointer is over, in every app. No rules needed.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                } else {
                    ForEach(sortedRuleBundleIDs, id: \.self) { bundleID in
                        AppRuleRow(
                            bundleID: bundleID,
                            rule: ruleBinding(for: bundleID),
                            onRemove: { settings.appRules.removeValue(forKey: bundleID) }
                        )
                        if bundleID != sortedRuleBundleIDs.last {
                            Divider().opacity(0.4)
                        }
                    }
                }

                Divider().opacity(0.4)

                Menu {
                    ForEach(addableRunningApps(), id: \.bundleID) { app in
                        Button(app.name) {
                            settings.appRules[app.bundleID] = .ignore
                        }
                    }
                } label: {
                    Label("Add Rule for Running App…", systemImage: "plus.circle.fill")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
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
