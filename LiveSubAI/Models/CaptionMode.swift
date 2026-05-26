import Foundation

enum CaptionMode: CaseIterable {
    case originalOnly
    case translateToEnglish
    case originalAndEnglish

    var title: String {
        switch self {
        case .originalOnly:
            "Original Only"
        case .translateToEnglish:
            "Translate to English"
        case .originalAndEnglish:
            "Original + English"
        }
    }

    var usesTranslation: Bool {
        self != .originalOnly
    }

    func next() -> CaptionMode {
        switch self {
        case .originalOnly:
            .translateToEnglish
        case .translateToEnglish:
            .originalAndEnglish
        case .originalAndEnglish:
            .originalOnly
        }
    }
}
