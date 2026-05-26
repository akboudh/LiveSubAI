import XCTest
@testable import LiveSubAI

final class TranslationOrderingBufferTests: XCTestCase {
    func testHoldsOutOfOrderSegmentsUntilEarlierSegmentArrives() {
        var buffer = TranslationOrderingBuffer()

        let second = CompletedSubtitleSegment(
            sequence: 2,
            sourceText: "dos",
            englishText: "two",
            translationSucceeded: true
        )
        XCTAssertEqual(buffer.enqueue(second), [])

        let first = CompletedSubtitleSegment(
            sequence: 1,
            sourceText: "uno",
            englishText: "one",
            translationSucceeded: true
        )
        XCTAssertEqual(buffer.enqueue(first), [first, second])
    }

    func testFallbackSegmentStillUnblocksQueue() {
        var buffer = TranslationOrderingBuffer()

        let first = CompletedSubtitleSegment(
            sequence: 1,
            sourceText: "bonjour",
            englishText: nil,
            translationSucceeded: false
        )
        XCTAssertEqual(buffer.enqueue(first), [first])
    }
}
