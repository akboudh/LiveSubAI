import AppKit

@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidToggleSubtitles()
    func menuBarDidRequestAPIKey()
    func menuBarDidRequestShowOverlay()
    func menuBarDidQuit()
}

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var delegate: MenuBarControllerDelegate?
    private let toggleItem = NSMenuItem(title: "Start Subtitles", action: #selector(toggleSubtitles), keyEquivalent: "")

    init(delegate: MenuBarControllerDelegate) {
        self.delegate = delegate
    }

    func install() {
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.toolTip = "LiveSubAI"
            if let image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "LiveSubAI") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "LS"
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "LiveSubAI", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        toggleItem.target = self
        menu.addItem(toggleItem)

        let showOverlayItem = NSMenuItem(title: "Show Overlay", action: #selector(showOverlay), keyEquivalent: "")
        showOverlayItem.target = self
        menu.addItem(showOverlayItem)

        let keyItem = NSMenuItem(title: "Set Deepgram API Key...", action: #selector(setAPIKey), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func setRunning(_ running: Bool) {
        toggleItem.title = running ? "Stop Subtitles" : "Start Subtitles"
    }

    @objc private func toggleSubtitles() {
        delegate?.menuBarDidToggleSubtitles()
    }

    @objc private func setAPIKey() {
        delegate?.menuBarDidRequestAPIKey()
    }

    @objc private func showOverlay() {
        delegate?.menuBarDidRequestShowOverlay()
    }

    @objc private func quit() {
        delegate?.menuBarDidQuit()
    }
}
