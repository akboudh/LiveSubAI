import AppKit

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayWindowController {
    private let window: OverlayPanel
    private let contentView = OverlayContentView()
    private var fadeWorkItem: DispatchWorkItem?
    private var screenRefreshTimer: Timer?

    init() {
        window = OverlayPanel(
            contentRect: Self.overlayFrame(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
            .transient
        ]
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.worksWhenModal = true
        window.isReleasedWhenClosed = false
        window.contentView = contentView
    }

    func show() {
        window.setFrame(Self.overlayFrame(), display: true)
        window.orderFrontRegardless()
        startScreenRefresh()
        update(status: "Paused", text: "")
    }

    func update(status: String, text: String, finalized: Bool = true) {
        keepOnActiveScreen()
        contentView.update(status: status, text: text, finalized: finalized)
        fadeWorkItem?.cancel()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().alphaValue = text.isEmpty && status == "Listening" ? 0.25 : 1
        }

        guard finalized, !text.isEmpty else { return }
        let item = DispatchWorkItem { [weak window] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                window?.animator().alphaValue = 0.72
            }
        }
        fadeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
    }

    private func startScreenRefresh() {
        screenRefreshTimer?.invalidate()
        screenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.keepOnActiveScreen()
            }
        }
    }

    private func keepOnActiveScreen() {
        let frame = Self.overlayFrame()
        guard !window.frame.equalTo(frame) else {
            return
        }
        window.setFrame(frame, display: true, animate: false)
        window.orderFrontRegardless()
    }

    private static func overlayFrame() -> NSRect {
        let screenFrame = activeScreen()?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let width = min(screenFrame.width * 0.74, 980)
        let height: CGFloat = 116
        let bottomInset = max(screenFrame.height * 0.10, 72)
        return NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.minY + bottomInset,
            width: width,
            height: height
        )
    }

    private static func activeScreen() -> NSScreen? {
        if let keyWindowScreen = NSApp.keyWindow?.screen {
            return keyWindowScreen
        }

        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return mouseScreen
        }

        return NSScreen.main ?? NSScreen.screens.first
    }
}
