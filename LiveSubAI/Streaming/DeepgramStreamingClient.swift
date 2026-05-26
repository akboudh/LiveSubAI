import Foundation

final class DeepgramStreamingClient: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onEvent: ((TranscriptEvent) -> Void)?
    private let parser = DeepgramTranscriptParser()
    private let queue = DispatchQueue(label: "LiveSubAI.DeepgramStreaming")
    private var isConnected = false

    func connect(apiKey: String, onEvent: @escaping (TranscriptEvent) -> Void) async throws {
        disconnect()
        self.onEvent = onEvent

        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: "multi"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "endpointing", value: "150")
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        receiveLoop()
    }

    func send(audio: Data) {
        guard isConnected, !audio.isEmpty else { return }
        queue.async { [weak self] in
            self?.webSocketTask?.send(.data(audio)) { error in
                if let error {
                    self?.onEvent?(.error(error.localizedDescription))
                }
            }
        }
    }

    func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handle(message)
                if self.isConnected {
                    self.receiveLoop()
                }
            case .failure(let error):
                self.isConnected = false
                self.onEvent?(.error(error.localizedDescription))
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let event = parser.parse(text) {
                onEvent?(event)
            }
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8),
                  let event = parser.parse(text) else { return }
            onEvent?(event)
        @unknown default:
            break
        }
    }
}

extension DeepgramStreamingClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        if closeCode != .normalClosure && closeCode != .goingAway {
            onEvent?(.error("Deepgram connection closed"))
        }
    }
}
