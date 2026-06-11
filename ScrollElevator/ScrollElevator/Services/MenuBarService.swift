import AppKit
import Combine

final class MenuBarService: NSObject, NSMenuDelegate {
    private let settings: SettingsService
    private let openSettings: () -> Void
    private let openWelcome: () -> Void
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    /// Last non-self frontmost app, for the "Ignore <App>" quick action.
    /// (When the status menu opens, frontmost may briefly be us.)
    private var lastExternalApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?

    init(settings: SettingsService, openSettings: @escaping () -> Void, openWelcome: @escaping () -> Void) {
        self.settings = settings
        self.openSettings = openSettings
        self.openWelcome = openWelcome
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(enabled: settings.enabled)

        // Filled icon while active, outline while disabled.
        settings.$enabled
            .removeDuplicates()
            .sink { [weak self] enabled in self?.updateIcon(enabled: enabled) }
            .store(in: &cancellables)

        lastExternalApp = NSWorkspace.shared.frontmostApplication
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.lastExternalApp = app
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func updateIcon(enabled: Bool) {
        statusItem.button?.image = Self.hallCallIcon(filled: enabled)
        statusItem.button?.appearsDisabled = !enabled
    }

    /// Elevator hall-call buttons: two stacked triangles. Filled while active,
    /// outlined while disabled. Drawn as a template image so the system tints
    /// it correctly in light/dark menu bars.
    private static func hallCallIcon(filled: Bool) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            let up = NSBezierPath()
            up.move(to: NSPoint(x: 8, y: 15))
            up.line(to: NSPoint(x: 2.8, y: 8.9))
            up.line(to: NSPoint(x: 13.2, y: 8.9))
            up.close()

            let down = NSBezierPath()
            down.move(to: NSPoint(x: 8, y: 1))
            down.line(to: NSPoint(x: 2.8, y: 7.1))
            down.line(to: NSPoint(x: 13.2, y: 7.1))
            down.close()

            NSColor.black.setFill()
            NSColor.black.setStroke()
            for path in [up, down] {
                path.lineJoinStyle = .round
                if filled {
                    path.fill()
                } else {
                    path.lineWidth = 1.3
                    path.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Scroll Elevator"
        return image
    }

    // Rebuild on every open so the checkmarks and Accessibility state are fresh.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.enabled ? .on : .off
        menu.addItem(enabledItem)

        if let app = lastExternalApp, let bundleID = app.bundleIdentifier {
            let name = app.localizedName ?? bundleID
            let ignored = settings.isIgnored(bundleIdentifier: bundleID)
            let ignoreItem = NSMenuItem(
                title: ignored ? "Stop Ignoring \(name)" : "Ignore \(name)",
                action: #selector(toggleIgnoreFrontmost(_:)),
                keyEquivalent: ""
            )
            ignoreItem.target = self
            ignoreItem.representedObject = bundleID
            menu.addItem(ignoreItem)
        }

        menu.addItem(.separator())

        if !JumpDispatcher.isTrusted {
            let axItem = NSMenuItem(
                title: "Grant Accessibility Access…",
                action: #selector(grantAccessibility),
                keyEquivalent: ""
            )
            axItem.target = self
            menu.addItem(axItem)
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let welcomeItem = NSMenuItem(title: "Welcome Guide", action: #selector(showWelcome), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Scroll Elevator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
    }

    @objc private func toggleIgnoreFrontmost(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        if settings.isIgnored(bundleIdentifier: bundleID) {
            settings.appRules.removeValue(forKey: bundleID)
        } else {
            settings.appRules[bundleID] = .ignore
        }
    }

    @objc private func grantAccessibility() {
        JumpDispatcher.promptForAccessibilityIfNeeded()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func showWelcome() {
        openWelcome()
    }
}
