import Cocoa

// MARK: - Drag + Hover Trigger Strip

/// A 2 px transparent strip at the **very top** of the screen.
///
/// Detects two kinds of events:
/// 1. **File drags** anywhere along the strip → `fileDragDidEnter/Exit`
/// 2. **Mouse hover** in a narrow centre zone (near the notch) → `hoverDidActivate/Deactivate`
final class DragTriggerStrip: NSPanel {
    private weak var dragDelegate: DragTriggerDelegate?

    init(delegate: DragTriggerDelegate) {
        self.dragDelegate = delegate

        let screen = NSScreen.main ?? .init()
        let rect = Self.computeRect(screen: screen)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configure()
        contentView = DragHandlerView(dragDelegate: delegate)
        contentView?.registerForDraggedTypes([.fileURL, .string])

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hasShadow = false
        ignoresMouseEvents = false
        isMovable = false
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        alphaValue = 0.0  // Fully invisible
    }

    static func computeRect(screen: NSScreen) -> NSRect {
        let f = screen.frame
        return NSRect(x: f.minX, y: f.maxY - 2, width: f.width, height: 2)
    }

    @objc private func screenChanged() {
        setFrame(Self.computeRect(screen: NSScreen.main ?? .init()), display: true, animate: true)
    }
}

// MARK: - DragTriggerDelegate

@MainActor
protocol DragTriggerDelegate: AnyObject {
    // File drag events (full width)
    func fileDragDidEnter()
    func fileDragDidExit()
    func fileWasDropped(_ url: URL)
    // Hover events (centre zone only)
    func hoverDidActivate()
    func hoverDidDeactivate()
}

// MARK: - Drag Handler NSView

/// The content view of the trigger strip.
/// - Registers for file drops (full width).
/// - Has a **small NSTrackingArea in the centre** to detect mouse hover near the notch.
private class DragHandlerView: NSView {
    private weak var dragDelegate: DragTriggerDelegate?
    /// Width of the centre hover zone (points).
    private let hoverZoneWidth: CGFloat = 220

    init(dragDelegate: DragTriggerDelegate?) {
        self.dragDelegate = dragDelegate
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Tracking Area (centre zone only)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)

        // Very narrow zone at the top-centre, near the notch.
        let midX = bounds.width / 2
        let zoneRect = CGRect(
            x: midX - hoverZoneWidth / 2,
            y: 0,
            width: hoverZoneWidth,
            height: bounds.height
        ).insetBy(dx: 0, dy: -20)   // extend downward for easier activation
         .offsetBy(dx: 0, dy: 20)

        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        addTrackingArea(NSTrackingArea(rect: zoneRect, options: opts, owner: self, userInfo: nil))
    }

    // MARK: - Mouse Hover

    override func mouseEntered(with event: NSEvent) {
        dragDelegate?.hoverDidActivate()
    }

    override func mouseExited(with event: NSEvent) {
        dragDelegate?.hoverDidDeactivate()
    }

    // MARK: - File Drags (full width)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragDelegate?.fileDragDidEnter()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragDelegate?.fileDragDidExit()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        var ok = false
        for item in items {
            if let urlStr = item.string(forType: .fileURL),
               let url = URL(string: urlStr) {
                dragDelegate?.fileWasDropped(url)
                ok = true
            }
        }
        return ok
    }
}
