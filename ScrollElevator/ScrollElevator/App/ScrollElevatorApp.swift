import SwiftUI

@main
struct ScrollElevatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The settings window is owned by AppDelegate (NSWindow + NSHostingView) so we
        // can show it on demand from the status menu in an LSUIElement app. This scene
        // exists only to satisfy the App protocol; it never opens.
        Settings { EmptyView() }
    }
}
