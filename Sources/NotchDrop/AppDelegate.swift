import Cocoa
import SwiftUI

/// Application delegate — manages the notch panel, status bar icon,
/// settings window, keyboard shortcut, and drag-trigger strip.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    private var dragTrigger: DragTriggerStrip?
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var contextMenu: NSMenu?
    private(set) lazy var viewModel = NotchDropManager()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusBar()
        notchWindow = NotchWindow(viewModel: viewModel)
        // Collapse panel when all files are removed
        viewModel.onFilesEmpty = { [weak self] in
            self?.notchWindow?.collapsePanel()
        }
        // Reset auto-hide timer when user interacts with the panel
        viewModel.onUserInteraction = { [weak self] in
            self?.notchWindow?.userDidInteract()
        }
        dragTrigger = DragTriggerStrip(delegate: self)
        dragTrigger?.orderFront(nil)
        registerKeyboardShortcut()

        if AppSettings.shared.rememberFiles {
            viewModel.restoreSavedFiles()
        }
    }

    // MARK: - Status Bar

    private func buildStatusBar() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder.badge.plus",
                                   accessibilityDescription: "NotchDrop")
            button.action = #selector(handleStatusBarClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        contextMenu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: L.appName)
        menu.addItem(NSMenuItem(title: L.togglePanel, action: #selector(togglePanel), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L.settings, action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    // MARK: - Click Handling

    @objc private func handleStatusBarClick() {
        guard let event = NSApp.currentEvent else { togglePanel(); return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            if let button = statusItem?.button, let menu = contextMenu {
                let topLeft = CGPoint(x: 0, y: button.bounds.height + 5)
                menu.popUp(positioning: nil, at: topLeft, in: button)
            }
        } else {
            togglePanel()
        }
    }

    // MARK: - Keyboard Shortcut

    private func registerKeyboardShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  event.modifierFlags.contains(.control),
                  event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers == "n"
            else { return event }

            self.togglePanel()
            return nil
        }
    }

    // MARK: - Panel Actions

    @objc func togglePanel() {
        guard let window = notchWindow else { return }

        if window.isVisible && viewModel.isExpanded {
            window.collapsePanel()
        } else {
            window.orderFront(nil)
            window.expandPanel()
        }
    }

    // MARK: - Settings Window

    @objc func openSettings() {
        // Hide the notch panel when opening settings
        if viewModel.isExpanded {
            notchWindow?.collapsePanel()
        }

        if let existing = settingsWindowController {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: SettingsView())
        hostingView.sizingOptions = [.preferredContentSize]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L.settingsTitle
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindowController?.window {
            settingsWindowController = nil
        }
    }
}

// MARK: - DragTriggerDelegate

extension AppDelegate: DragTriggerDelegate {
    func fileDragDidEnter() {
        notchWindow?.cancelHideIfNeeded()
        notchWindow?.orderFront(nil)
        notchWindow?.expandPanel()
    }

    func fileDragDidExit() {
        notchWindow?.scheduleHide()
    }

    func fileWasDropped(_ url: URL) {
        viewModel.addFile(at: url)
    }

    func hoverDidActivate() {
        // Don't re-trigger if panel is already visible — that would cancel
        // the running auto-hide timer and restart it indefinitely.
        guard let window = notchWindow, !(window.isVisible && viewModel.isExpanded) else { return }
        notchWindow?.cancelHideIfNeeded()
        notchWindow?.orderFront(nil)
        notchWindow?.expandPanel()
    }

    func hoverDidDeactivate() {
        // Let the global timer handle auto-hide
    }
}
