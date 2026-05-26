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
    private let translator = DeepLTranslationClient()

    private var isRunning = false
    private var latestFinalText = ""
    private var latestDisplayState = SubtitleDisplayState.empty
    private var captionMode: CaptionMode = .originalOnly
    private var translationGeneration = 0
    private var nextFinalSequence = 1
    private var orderingBuffer = TranslationOrderingBuffer()
    private var orderedDisplayQueue: [CompletedSubtitleSegment] = []
    private var isDrainingDisplayQueue = false
    private var cachedDeepLAPIKey: String?

    func start() {
        menuBar.install()
        menuBar.setCaptionMode(captionMode)
        controlWindow.show()
        controlWindow.setCaptionMode(captionMode)
        overlay.show()
        hotkeys.registerHotkeys(toggleSubtitles: { [weak self] in
            Task { @MainActor in
                self?.toggleSubtitles()
            }
        }, toggleTranslationMode: { [weak self] in
            Task { @MainActor in
                self?.toggleCaptionMode()
            }
        })
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
            overlay.update(status: "Paused", state: latestDisplayState)
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
            cachedDeepLAPIKey = try? deepLAPIKey()
            latestFinalText = ""
            latestDisplayState = .empty
            translationGeneration += 1
            nextFinalSequence = 1
            orderingBuffer.reset()
            orderedDisplayQueue.removeAll()
            isDrainingDisplayQueue = false
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
            overlay.update(status: error.localizedDescription, state: latestDisplayState)
        }
    }

    func stopSubtitles() async {
        guard isRunning else { return }
        await audioCapture.stop()
        deepgram.disconnect()
        translationGeneration += 1
        orderedDisplayQueue.removeAll()
        isDrainingDisplayQueue = false
        isRunning = false
        menuBar.setRunning(false)
        controlWindow.setRunning(false)
        overlay.update(status: "Paused", state: latestDisplayState)
    }

    func promptForAPIKey() {
        promptForKey(
            title: "Deepgram API Key",
            message: "The key is stored in Keychain and used only for the streaming transcription connection.",
            placeholder: "Deepgram API key"
        ) { [settings] key in
            try settings.setDeepgramAPIKey(key)
        }
    }

    func promptForTranslationAPIKey() {
        promptForKey(
            title: "DeepL API Key",
            message: "The key is stored in Keychain and used only to translate finalized subtitle segments into English.",
            placeholder: "DeepL API key"
        ) { [weak self] key in
            try self?.settings.setDeepLAPIKey(key)
            self?.cachedDeepLAPIKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func promptForKey(title: String, message: String, placeholder: String, save: (String) throws -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        input.placeholderString = placeholder
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try save(input.stringValue)
                controlWindow.setStatus("API key saved")
            } catch {
                overlay.update(status: error.localizedDescription, state: latestDisplayState)
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

    private func deepLAPIKey() throws -> String? {
        if let key = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !key.isEmpty {
            try settings.setDeepLAPIKey(key)
            return key
        }
        if let cachedDeepLAPIKey, !cachedDeepLAPIKey.isEmpty {
            return cachedDeepLAPIKey
        }
        if let key = try settings.deepLAPIKey(), !key.isEmpty {
            cachedDeepLAPIKey = key
            return key
        }
        return nil
    }

    func toggleCaptionMode() {
        captionMode = captionMode.next()
        menuBar.setCaptionMode(captionMode)
        controlWindow.setCaptionMode(captionMode)
        controlWindow.setStatus("Mode: \(captionMode.title)")
        if captionMode.usesTranslation {
            cachedDeepLAPIKey = try? deepLAPIKey()
        }
    }

    private func handle(_ event: TranscriptEvent) {
        switch event {
        case .partial(let text):
            handlePartial(text)
            controlWindow.setStatus("Listening")
        case .final(let text):
            handleFinal(text)
            controlWindow.setStatus("Listening")
        case .error(let message):
            overlay.update(status: message, state: latestDisplayState)
            controlWindow.setStatus(message)
        }
    }

    private func handlePartial(_ text: String) {
        switch captionMode {
        case .originalOnly:
            updateOverlay(SubtitleDisplayState(primaryText: text, secondaryText: nil, isPartial: true))
        case .translateToEnglish:
            updateOverlay(SubtitleDisplayState(primaryText: "Listening...", secondaryText: nil, isPartial: true))
        case .originalAndEnglish:
            updateOverlay(SubtitleDisplayState(primaryText: text, secondaryText: "Waiting for English translation", isPartial: true))
        }
    }

    private func handleFinal(_ text: String) {
        latestFinalText = text
        guard captionMode.usesTranslation else {
            let segment = CompletedSubtitleSegment(sequence: nextFinalSequence, sourceText: text, englishText: nil, translationSucceeded: true)
            nextFinalSequence += 1
            render(segment)
            return
        }

        let sequence = nextFinalSequence
        nextFinalSequence += 1
        let generation = translationGeneration

        guard let key = try? deepLAPIKey(), !key.isEmpty else {
            controlWindow.setStatus("Missing DeepL API key; showing original")
            completeTranslation(
                CompletedSubtitleSegment(sequence: sequence, sourceText: text, englishText: nil, translationSucceeded: false),
                generation: generation
            )
            return
        }

        updateOverlay(SubtitleDisplayState(primaryText: "Translating...", secondaryText: captionMode == .originalAndEnglish ? text : nil, isPartial: true))

        Task { [weak self] in
            guard let self else { return }
            do {
                let english = try await translator.translateToEnglish(text, apiKey: key)
                await MainActor.run {
                    self.completeTranslation(
                        CompletedSubtitleSegment(sequence: sequence, sourceText: text, englishText: english, translationSucceeded: true),
                        generation: generation
                    )
                }
            } catch {
                await MainActor.run {
                    self.controlWindow.setStatus("Translation unavailable; showing original")
                    self.completeTranslation(
                        CompletedSubtitleSegment(sequence: sequence, sourceText: text, englishText: nil, translationSucceeded: false),
                        generation: generation
                    )
                }
            }
        }
    }

    private func completeTranslation(_ segment: CompletedSubtitleSegment, generation: Int) {
        guard generation == translationGeneration else { return }
        let ready = orderingBuffer.enqueue(segment)
        enqueueOrderedDisplay(ready)
    }

    private func enqueueOrderedDisplay(_ segments: [CompletedSubtitleSegment]) {
        guard !segments.isEmpty else { return }
        orderedDisplayQueue.append(contentsOf: segments)
        drainOrderedDisplayQueue()
    }

    private func drainOrderedDisplayQueue() {
        guard !isDrainingDisplayQueue, !orderedDisplayQueue.isEmpty else { return }
        isDrainingDisplayQueue = true
        let segment = orderedDisplayQueue.removeFirst()
        render(segment)

        guard !orderedDisplayQueue.isEmpty else {
            isDrainingDisplayQueue = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.isDrainingDisplayQueue = false
            self.drainOrderedDisplayQueue()
        }
    }

    private func render(_ segment: CompletedSubtitleSegment) {
        let state: SubtitleDisplayState
        switch captionMode {
        case .originalOnly:
            state = SubtitleDisplayState(primaryText: segment.sourceText, secondaryText: nil, isPartial: false)
        case .translateToEnglish:
            state = SubtitleDisplayState(primaryText: segment.englishText ?? segment.sourceText, secondaryText: nil, isPartial: false)
        case .originalAndEnglish:
            if let englishText = segment.englishText {
                state = SubtitleDisplayState(primaryText: englishText, secondaryText: segment.sourceText, isPartial: false)
            } else {
                state = SubtitleDisplayState(primaryText: segment.sourceText, secondaryText: "Translation unavailable", isPartial: false)
            }
        }
        updateOverlay(state)
    }

    private func updateOverlay(_ state: SubtitleDisplayState) {
        latestDisplayState = state
        overlay.update(status: "Listening", state: state)
    }
}

extension AppCoordinator: MenuBarControllerDelegate {
    func menuBarDidToggleSubtitles() {
        toggleSubtitles()
    }

    func menuBarDidRequestAPIKey() {
        promptForAPIKey()
    }

    func menuBarDidRequestTranslationAPIKey() {
        promptForTranslationAPIKey()
    }

    func menuBarDidToggleCaptionMode() {
        toggleCaptionMode()
    }

    func menuBarDidRequestShowOverlay() {
        overlay.show()
        overlay.update(status: isRunning ? "Listening" : "Paused", state: latestDisplayState)
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

    func controlWindowDidRequestTranslationAPIKey() {
        promptForTranslationAPIKey()
    }

    func controlWindowDidToggleCaptionMode() {
        toggleCaptionMode()
    }

    func controlWindowDidRequestShowOverlay() {
        overlay.show()
        overlay.update(status: isRunning ? "Listening" : "Paused", state: latestDisplayState)
    }

    func controlWindowDidQuit() {
        NSApp.terminate(nil)
    }
}
