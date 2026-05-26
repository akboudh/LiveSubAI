import Foundation

enum LiveSubAIError: LocalizedError {
    case missingAPIKey
    case screenCapturePermissionDenied
    case screenCaptureUnavailable(String)
    case systemAudioCaptureUnavailable(String)
    case noDisplayAvailable
    case unsupportedAudioFormat
    case missingTranslationAPIKey
    case translationUnavailable(String)
    case webSocketDisconnected

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Missing Deepgram API key"
        case .screenCapturePermissionDenied:
            "Screen Recording permission denied"
        case .screenCaptureUnavailable(let message):
            message
        case .systemAudioCaptureUnavailable(let message):
            message
        case .noDisplayAvailable:
            "No display available for system audio capture"
        case .unsupportedAudioFormat:
            "Unsupported system audio format"
        case .missingTranslationAPIKey:
            "Missing DeepL API key"
        case .translationUnavailable(let message):
            message
        case .webSocketDisconnected:
            "Deepgram connection disconnected"
        }
    }
}
