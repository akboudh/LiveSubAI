import Foundation

struct CompletedSubtitleSegment: Equatable {
    let sequence: Int
    let sourceText: String
    let englishText: String?
    let translationSucceeded: Bool
}

struct TranslationOrderingBuffer {
    private var nextSequence = 1
    private var pending: [Int: CompletedSubtitleSegment] = [:]

    mutating func reset() {
        nextSequence = 1
        pending.removeAll()
    }

    mutating func enqueue(_ segment: CompletedSubtitleSegment) -> [CompletedSubtitleSegment] {
        guard segment.sequence >= nextSequence else {
            return []
        }

        pending[segment.sequence] = segment

        var ready: [CompletedSubtitleSegment] = []
        while let segment = pending.removeValue(forKey: nextSequence) {
            ready.append(segment)
            nextSequence += 1
        }
        return ready
    }
}
