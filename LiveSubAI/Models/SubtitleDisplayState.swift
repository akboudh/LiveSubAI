import Foundation

struct SubtitleDisplayState: Equatable {
    let primaryText: String
    let secondaryText: String?
    let isPartial: Bool

    static let empty = SubtitleDisplayState(primaryText: "", secondaryText: nil, isPartial: false)
}
