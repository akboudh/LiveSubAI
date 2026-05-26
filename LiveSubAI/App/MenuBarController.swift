import AppKit

@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidToggleSubtitles()
    func menuBarDidRequestAPIKey()
    func menuBarDidRequestTranslationAPIKey()
    func menuBarDidToggleCaptionMode()
    func menuBarDidRequestShowOverlay()
    func menuBarDidQuit()
}

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var delegate: MenuBarControllerDelegate?
    private let toggleItem = NSMenuItem(title: "Start Subtitles", action: #selector(toggleSubtitles), keyEquivalent: "")
    private let captionModeItem = NSMenuItem(title: "Mode: Original Only", action: #selector(toggleCaptionMode), keyEquivalent: "")

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

        captionModeItem.target = self
        menu.addItem(captionModeItem)

        let showOverlayItem = NSMenuItem(title: "Show Overlay", action: #selector(showOverlay), keyEquivalent: "")
        showOverlayItem.target = self
        menu.addItem(showOverlayItem)

        let keyItem = NSMenuItem(title: "Set Deepgram API Key...", action: #selector(setAPIKey), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)

        let translationKeyItem = NSMenuItem(title: "Set DeepL API Key...", action: #selector(setTranslationAPIKey), keyEquivalent: "")
        translationKeyItem.target = self
        menu.addItem(translationKeyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func setRunning(_ running: Bool) {
        toggleItem.title = running ? "Stop Subtitles" : "Start Subtitles"
    }

    func setCaptionMode(_ mode: CaptionMode) {
        captionModeItem.title = "Mode: \(mode.title)"
    }

    @objc private func toggleSubtitles() {
        delegate?.menuBarDidToggleSubtitles()
    }

    @objc private func toggleCaptionMode() {
        delegate?.menuBarDidToggleCaptionMode()
    }

    @objc private func setAPIKey() {
        delegate?.menuBarDidRequestAPIKey()
    }

    @objc private func setTranslationAPIKey() {
        delegate?.menuBarDidRequestTranslationAPIKey()
    }

    @objc private func showOverlay() {
        delegate?.menuBarDidRequestShowOverlay()
    }

    @objc private func quit() {
        delegate?.menuBarDidQuit()
    }
}
