import AppKit

@MainActor
protocol ControlWindowControllerDelegate: AnyObject {
    func controlWindowDidToggleSubtitles()
    func controlWindowDidRequestAPIKey()
    func controlWindowDidRequestShowOverlay()
    func controlWindowDidQuit()
}

@MainActor
final class ControlWindowController {
    private let window: NSWindow
    private let statusLabel = NSTextField(labelWithString: "Paused")
    private let toggleButton = NSButton(title: "Start Subtitles", target: nil, action: nil)
    private weak var delegate: ControlWindowControllerDelegate?

    init(delegate: ControlWindowControllerDelegate) {
        self.delegate = delegate

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 210))

        let titleLabel = NSTextField(labelWithString: "LiveSubAI")
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.alignment = .center

        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center

        toggleButton.bezelStyle = .rounded

        let keyButton = NSButton(title: "Set Deepgram API Key", target: nil, action: nil)
        keyButton.bezelStyle = .rounded

        let overlayButton = NSButton(title: "Show Overlay", target: nil, action: nil)
        overlayButton.bezelStyle = .rounded

        let quitButton = NSButton(title: "Quit", target: nil, action: nil)
        quitButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [toggleButton, keyButton, overlayButton, quitButton])
        buttonStack.orientation = .vertical
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        let stack = NSStackView(views: [titleLabel, statusLabel, buttonStack])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -64),
            buttonStack.widthAnchor.constraint(equalToConstant: 220)
        ])

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 210),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LiveSubAI"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentView = contentView

        toggleButton.target = self
        toggleButton.action = #selector(toggleSubtitles)
        keyButton.target = self
        keyButton.action = #selector(setAPIKey)
        overlayButton.target = self
        overlayButton.action = #selector(showOverlay)
        quitButton.target = self
        quitButton.action = #selector(quit)
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        if let visibleFrame = NSScreen.main?.visibleFrame {
            let size = window.frame.size
            let origin = NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2
            )
            window.setFrameOrigin(origin)
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    func setRunning(_ running: Bool) {
        toggleButton.title = running ? "Stop Subtitles" : "Start Subtitles"
        statusLabel.stringValue = running ? "Listening" : "Paused"
    }

    func setStatus(_ status: String) {
        statusLabel.stringValue = status
    }

    @objc private func toggleSubtitles() {
        delegate?.controlWindowDidToggleSubtitles()
    }

    @objc private func setAPIKey() {
        delegate?.controlWindowDidRequestAPIKey()
    }

    @objc private func showOverlay() {
        delegate?.controlWindowDidRequestShowOverlay()
    }

    @objc private func quit() {
        delegate?.controlWindowDidQuit()
    }
}
