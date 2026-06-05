import SwiftUI

/// App entry point.
/// Uses NSApplicationDelegateAdaptor to manage AppKit windows and status bar.
@main
struct NotchDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
