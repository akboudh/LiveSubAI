import Foundation

enum TranscriptEvent: Equatable {
    case partial(String)
    case final(String)
    case error(String)
}
