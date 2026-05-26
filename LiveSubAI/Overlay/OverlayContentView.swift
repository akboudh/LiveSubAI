import AppKit

final class OverlayContentView: NSView {
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var currentText = ""
    private var currentFinalized = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 34, weight: .semibold)
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.cell?.usesSingleLineMode = false
        subtitleLabel.cell?.wraps = true
        subtitleLabel.cell?.isScrollable = false
        subtitleLabel.cell?.truncatesLastVisibleLine = true
        subtitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 34),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -34),
            subtitleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 20),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
            subtitleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(status: String, text: String, finalized: Bool) {
        let fallbackStatus = status == "Paused" || status == "Listening" ? "" : status
        currentText = text.isEmpty ? fallbackStatus : text
        currentFinalized = finalized
        subtitleLabel.stringValue = currentText
        subtitleLabel.textColor = finalized ? .white : NSColor.white.withAlphaComponent(0.78)
        updateSubtitleFont()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        updateSubtitleFont()
    }

    private func updateSubtitleFont() {
        guard !currentText.isEmpty else {
            subtitleLabel.font = .systemFont(ofSize: currentFinalized ? 34 : 31, weight: currentFinalized ? .semibold : .medium)
            return
        }

        let baseSize: CGFloat = currentFinalized ? 34 : 31
        let minimumSize: CGFloat = 23
        let weight: NSFont.Weight = currentFinalized ? .semibold : .medium
        let availableWidth = max(bounds.width - 68, 100)
        let availableHeight = max(bounds.height - 40, 42)

        for size in stride(from: baseSize, through: minimumSize, by: -1) {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let measuredHeight = measuredTextHeight(font: font, width: availableWidth)
            if measuredHeight <= availableHeight {
                subtitleLabel.font = font
                return
            }
        }

        subtitleLabel.font = .systemFont(ofSize: minimumSize, weight: weight)
    }

    private func measuredTextHeight(font: NSFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attributed = NSAttributedString(
            string: currentText,
            attributes: [
                .font: font,
                .paragraphStyle: paragraph
            ]
        )
        let rect = attributed.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: 10, dy: 10)
        let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.setFillColor(NSColor.black.withAlphaComponent(0.62).cgColor)
        context.addPath(path)
        context.fillPath()

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
        context.setLineWidth(1)
        context.addPath(path)
        context.strokePath()
    }
}
