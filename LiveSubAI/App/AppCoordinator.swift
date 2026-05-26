import AppKit
import Foundation

@MainActor
final class AppCoordinator {
    private let settings = SettingsManager()
    private let overlay = OverlayWindowController()
    private lazy var controlWindow = ControlWindowController(delegate: self)
    private lazy var menuBar = MenuBarController(delegate: self)
    private let hotkeys = HotkeyManager()
    private let audioCapture = AudioCaptureManager()
    private let deepgram = DeepgramStreamingClient()

    private var isRunning = false
    private var latestFinalText = ""

    func start() {
        menuBar.install()
        controlWindow.show()
        overlay.show()
        hotkeys.registerToggleHotkey { [weak self] in
            Task { @MainActor in
                self?.toggleSubtitles()
            }
        }
        Task {
            await updateScreenRecordingStatus()
        }
    }

    func showControlWindow() {
        controlWindow.show()
    }

    func stop() {
        Task {
            await stopSubtitles()
        }
        hotkeys.unregisterAll()
    }

    private func updateScreenRecordingStatus() async {
        guard await !audioCapture.hasScreenCaptureAccess() else {
            controlWindow.setStatus("Ready")
            overlay.update(status: "Paused", text: latestFinalText)
            return
        }
        overlay.update(status: "System Audio permission required", text: "")
        controlWindow.setStatus("System Audio permission required")
    }

    private func requestScreenRecordingIfNeeded() async -> Bool {
        guard await !audioCapture.hasScreenCaptureAccess() else {
            return true
        }
        overlay.update(status: "System Audio permission required", text: "")
        controlWindow.setStatus("System Audio permission required")
        let openedSettings = await audioCapture.requestScreenCaptureAccess()
        if !openedSettings {
            overlay.update(status: "Enable System Audio Recording for LiveSubAI", text: "")
            controlWindow.setStatus("Enable System Audio Recording for LiveSubAI")
        }
        return false
    }

    func toggleSubtitles() {
        if isRunning {
            Task { await stopSubtitles() }
        } else {
            Task { await startSubtitles() }
        }
    }

    func startSubtitles() async {
        guard !isRunning else { return }

        do {
            guard await requestScreenRecordingIfNeeded() else { return }
            let key = try await deepgramAPIKey()
            latestFinalText = ""
            overlay.update(status: "Connecting...", text: "")
            controlWindow.setStatus("Connecting...")
            try await deepgram.connect(apiKey: key) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            }
            try await audioCapture.start { [weak self] audioChunk in
                self?.deepgram.send(audio: audioChunk)
            }
            isRunning = true
            menuBar.setRunning(true)
            controlWindow.setRunning(true)
            overlay.update(status: "Listening", text: "")
        } catch {
            isRunning = false
            menuBar.setRunning(false)
            controlWindow.setRunning(false)
            controlWindow.setStatus(error.localizedDescription)
            overlay.update(status: error.localizedDescription, text: latestFinalText)
        }
    }

    func stopSubtitles() async {
        guard isRunning else { return }
        await audioCapture.stop()
        deepgram.disconnect()
        isRunning = false
        menuBar.setRunning(false)
        controlWindow.setRunning(false)
        overlay.update(status: "Paused", text: latestFinalText)
    }

    func promptForAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Deepgram API Key"
        alert.informativeText = "The key is stored in Keychain and used only for the streaming transcription connection."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        input.placeholderString = "Deepgram API key"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try settings.setDeepgramAPIKey(input.stringValue)
                controlWindow.setStatus("API key saved")
            } catch {
                overlay.update(status: error.localizedDescription, text: latestFinalText)
                controlWindow.setStatus(error.localizedDescription)
            }
        }
    }

    private func deepgramAPIKey() async throws -> String {
        if let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"], !key.isEmpty {
            try settings.setDeepgramAPIKey(key)
            return key
        }
        if let key = try settings.deepgramAPIKey(), !key.isEmpty {
            return key
        }
        throw LiveSubAIError.missingAPIKey
    }

    private func handle(_ event: TranscriptEvent) {
        switch event {
        case .partial(let text):
            overlay.update(status: "Listening", text: text, finalized: false)
            controlWindow.setStatus("Listening")
        case .final(let text):
            latestFinalText = text
            overlay.update(status: "Listening", text: text, finalized: true)
            controlWindow.setStatus("Listening")
        case .error(let message):
            overlay.update(status: message, text: latestFinalText)
            controlWindow.setStatus(message)
        }
    }
}

extension AppCoordinator: MenuBarControllerDelegate {
    func menuBarDidToggleSubtitles() {
        toggleSubtitles()
    }

    func menuBarDidRequestAPIKey() {
        promptForAPIKey()
    }

    func menuBarDidRequestShowOverlay() {
        overlay.show()
        overlay.update(status: isRunning ? "Listening" : "Paused", text: latestFinalText)
    }

    func menuBarDidQuit() {
        NSApp.terminate(nil)
    }
}

extension AppCoordinator: ControlWindowControllerDelegate {
    func controlWindowDidToggleSubtitles() {
        toggleSubtitles()
    }

    func controlWindowDidRequestAPIKey() {
        promptForAPIKey()
    }

    func controlWindowDidRequestShowOverlay() {
        overlay.show()
        overlay.update(status: isRunning ? "Listening" : "Paused", text: latestFinalText)
    }

    func controlWindowDidQuit() {
        NSApp.terminate(nil)
    }
}
