import AppKit
import Combine

final class MenuBarService: NSObject, NSMenuDelegate {
    private let settings: SettingsService
    private let openSettings: () -> Void
    private var statusItem: NSStatusItem!

    init(settings: SettingsService, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.openSettings = openSettings
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "arrow.up.and.down.circle",
                accessibilityDescription: "Scroll Elevator"
            )
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Rebuild on every open so the Enabled checkmark and Accessibility state are fresh.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.enabled ? .on : .off
        menu.addItem(enabledItem)

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

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Scroll Elevator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
    }

    @objc private func grantAccessibility() {
        JumpDispatcher.promptForAccessibilityIfNeeded()
    }

    @objc private func showSettings() {
        openSettings()
    }
}
