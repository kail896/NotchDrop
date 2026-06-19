import Cocoa
import SwiftUI

/// The floating panel that appears centred below the notch when triggered.
/// **Stays hidden when collapsed** — only the left/right TriggerWindows
/// are visible in the idle state.
final class NotchWindow: NSPanel {
    private let viewModel: NotchDropManager
    private var hideWorkItem: DispatchWorkItem?
    private var isAnimating = false

    private let expandedHeight: CGFloat = 340

    // MARK: - Init

    init(viewModel: NotchDropManager) {
        self.viewModel = viewModel

        let screen = NSScreen.main ?? .init()
        let rect = Self.hiddenRect(for: screen)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        let hostView = makeHostingView()
        let notchView = NotchContentView(viewModel: viewModel, hostingView: hostView, window: self)
        self.contentView = notchView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        orderOut(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configurePanel() {
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hasShadow = true
        ignoresMouseEvents = false
        isMovable = false
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        styleMask.insert(.fullSizeContentView)
        acceptsMouseMovedEvents = true
    }

    private func makeHostingView() -> NSHostingView<NotchPanelView> {
        let panelView = NotchPanelView(viewModel: viewModel)
        let host = NSHostingView(rootView: panelView)
        host.autoresizingMask = [.width, .height]
        host.wantsLayer = true
        host.layer?.cornerRadius = 18
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        return host
    }

    // MARK: - Expand / Collapse

    func expandPanel() {
        guard !isAnimating else { return }
        isAnimating = true
        cancelScheduledHide()
        viewModel.isExpanded = true

        if !isVisible {
            alphaValue = 1.0
            setFrame(Self.expandedRect(for: NSScreen.main ?? .init()), display: false)
            orderFront(nil)
            isAnimating = false
            // Start global auto-hide timer
            scheduleHide()
            return
        }

        let targetRect = Self.expandedRect(for: NSScreen.main ?? .init())

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            self.animator().setFrame(targetRect, display: true)
            self.animator().alphaValue = 1.0
        } completionHandler: { [weak self] in
            self?.isAnimating = false
            // Start global auto-hide timer
            self?.scheduleHide()
        }
    }

    func collapsePanel() {
        guard !isAnimating, viewModel.isExpanded else { return }

        isAnimating = true
        viewModel.isExpanded = false

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.6, 1)
            self.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.orderOut(nil)
            self.alphaValue = 1.0
            self.setFrame(Self.hiddenRect(for: NSScreen.main ?? .init()), display: false)
            self.isAnimating = false
        }
    }

    /// Start the global hide timer — panel will hide after `autoHideDelay` seconds.
    func scheduleHide() {
        cancelScheduledHide()
        let workItem = DispatchWorkItem { [weak self] in
            self?.collapsePanel()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AppSettings.shared.autoHideDelay, execute: workItem)
    }

    /// Restart the hide timer (call after file operations extend the session).
    func restartHideTimer() {
        if isVisible { scheduleHide() }
    }

    /// Reset the auto-hide timer when the user interacts with panel content.
    func userDidInteract() {
        if viewModel.isExpanded { scheduleHide() }
    }

    func cancelHideIfNeeded() { cancelScheduledHide() }

    private func cancelScheduledHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    // MARK: - Screen Changes

    @objc private func screenParametersDidChange() {
        guard isVisible else { return }
        let rect = viewModel.isExpanded
            ? Self.expandedRect(for: NSScreen.main ?? .init())
            : Self.hiddenRect(for: NSScreen.main ?? .init())
        setFrame(rect, display: true, animate: true)
    }

    // MARK: - Geometry Helpers

    private static func hiddenRect(for screen: NSScreen) -> NSRect {
        let fw = screen.visibleFrame
        return NSRect(x: fw.midX - 220, y: fw.maxY - 10, width: 440, height: 10)
    }

    static func expandedRect(for screen: NSScreen) -> NSRect {
        let fw = screen.visibleFrame
        return NSRect(x: fw.midX - 220, y: fw.maxY - 340, width: 440, height: 340)
    }
}

// MARK: - Custom Content View (Drag Destination only)

final class NotchContentView: NSView {
    private let viewModel: NotchDropManager
    private let hostingView: NSHostingView<NotchPanelView>
    private weak var parentWindow: NotchWindow?

    init(
        viewModel: NotchDropManager,
        hostingView: NSHostingView<NotchPanelView>,
        window: NotchWindow
    ) {
        self.viewModel = viewModel
        self.hostingView = hostingView
        self.parentWindow = window
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true

        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        registerForDraggedTypes([.fileURL, .string])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Drag Destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        parentWindow?.cancelHideIfNeeded()
        viewModel.isDropTargeted = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        viewModel.isDropTargeted = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        viewModel.isDropTargeted = false
        parentWindow?.scheduleHide()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        viewModel.isDropTargeted = false
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        var accepted = false
        for item in items {
            if let urlStr = item.string(forType: .fileURL),
               let url = URL(string: urlStr) {
                viewModel.addFile(at: url)
                accepted = true
            }
        }
        if accepted {
            // Restart the hide timer after a successful drop
            parentWindow?.scheduleHide()
        }
        return accepted
    }
}
