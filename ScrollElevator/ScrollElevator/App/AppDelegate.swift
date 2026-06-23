import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsService!
    private var scrollMonitor: ScrollMonitor!
    private var overlayController: OverlayController!
    private var menuBarService: MenuBarService!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = SettingsService()
        overlayController = OverlayController(settings: settings)
        scrollMonitor = ScrollMonitor(settings: settings, overlayController: overlayController)
        menuBarService = MenuBarService(
            settings: settings,
            openSettings: { [weak self] in self?.showSettingsWindow() },
            openWelcome: { [weak self] in self?.showOnboardingWindow() }
        )

        if settings.hasCompletedOnboarding {
            // Returning user: surface the system prompt only if the grant is missing.
            JumpDispatcher.promptForAccessibilityIfNeeded()
        } else {
            showOnboardingWindow()
        }

        scrollMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scrollMonitor.stop()
    }

    private func showSettingsWindow() {
        if settingsWindow == nil {
            let hosting = NSHostingView(rootView: SettingsView(
                settings: settings,
                openWelcome: { [weak self] in self?.showOnboardingWindow() }
            ))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 780),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Scroll Elevator Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.contentView = hosting
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboardingWindow() {
        if onboardingWindow == nil {
            let hosting = NSHostingView(rootView: OnboardingView(
                settings: settings,
                dismiss: { [weak self] in
                    self?.settings.hasCompletedOnboarding = true
                    self?.onboardingWindow?.close()
                }
            ))
            hosting.frame.size = hosting.fittingSize
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Scroll Elevator"
            window.titlebarAppearsTransparent = true
            window.contentView = hosting
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
