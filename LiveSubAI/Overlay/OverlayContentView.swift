import AppKit

final class OverlayContentView: NSView {
    private let primaryLabel = NSTextField(labelWithString: "")
    private let secondaryLabel = NSTextField(labelWithString: "")
    private let labelStack = NSStackView()
    private var currentText = ""
    private var currentSecondaryText: String?
    private var currentFinalized = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        configure(label: primaryLabel, maxLines: 2)
        configure(label: secondaryLabel, maxLines: 1)
        secondaryLabel.textColor = NSColor.white.withAlphaComponent(0.68)

        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.orientation = .vertical
        labelStack.alignment = .centerX
        labelStack.spacing = 6
        labelStack.addArrangedSubview(primaryLabel)
        labelStack.addArrangedSubview(secondaryLabel)
        addSubview(labelStack)

        NSLayoutConstraint.activate([
            labelStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 34),
            labelStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -34),
            labelStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 16),
            labelStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
            labelStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            primaryLabel.widthAnchor.constraint(equalTo: labelStack.widthAnchor),
            secondaryLabel.widthAnchor.constraint(equalTo: labelStack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(status: String, text: String, finalized: Bool) {
        let fallbackStatus = status == "Paused" || status == "Listening" ? "" : status
        let state = SubtitleDisplayState(primaryText: text.isEmpty ? fallbackStatus : text, secondaryText: nil, isPartial: !finalized)
        update(state: state)
    }

    func update(state: SubtitleDisplayState) {
        currentText = state.primaryText
        currentSecondaryText = state.secondaryText
        currentFinalized = !state.isPartial
        primaryLabel.stringValue = currentText
        secondaryLabel.stringValue = state.secondaryText ?? ""
        secondaryLabel.isHidden = (state.secondaryText ?? "").isEmpty
        primaryLabel.textColor = state.isPartial ? NSColor.white.withAlphaComponent(0.78) : .white
        secondaryLabel.textColor = NSColor.white.withAlphaComponent(state.isPartial ? 0.48 : 0.68)
        updateSubtitleFont()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        updateSubtitleFont()
    }

    private func updateSubtitleFont() {
        guard !currentText.isEmpty else {
            primaryLabel.font = .systemFont(ofSize: currentFinalized ? 34 : 31, weight: currentFinalized ? .semibold : .medium)
            secondaryLabel.font = .systemFont(ofSize: 19, weight: .regular)
            return
        }

        let baseSize: CGFloat = currentFinalized ? 34 : 31
        let minimumSize: CGFloat = 23
        let weight: NSFont.Weight = currentFinalized ? .semibold : .medium
        let availableWidth = max(bounds.width - 68, 100)
        let availableHeight = max(bounds.height - 40, 42)

        for size in stride(from: baseSize, through: minimumSize, by: -1) {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let secondaryFont = NSFont.systemFont(ofSize: max(size - 12, 16), weight: .regular)
            let measuredHeight = measuredTextHeight(text: currentText, font: font, width: availableWidth)
                + secondaryHeight(font: secondaryFont, width: availableWidth)
            if measuredHeight <= availableHeight {
                primaryLabel.font = font
                secondaryLabel.font = secondaryFont
                return
            }
        }

        primaryLabel.font = .systemFont(ofSize: minimumSize, weight: weight)
        secondaryLabel.font = .systemFont(ofSize: 16, weight: .regular)
    }

    private func secondaryHeight(font: NSFont, width: CGFloat) -> CGFloat {
        guard let currentSecondaryText, !currentSecondaryText.isEmpty else { return 0 }
        return measuredTextHeight(text: currentSecondaryText, font: font, width: width) + 6
    }

    private func measuredTextHeight(text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attributed = NSAttributedString(
            string: text,
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

    private func configure(label: NSTextField, maxLines: Int) {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 34, weight: .semibold)
        label.maximumNumberOfLines = maxLines
        label.lineBreakMode = .byWordWrapping
        label.cell?.usesSingleLineMode = false
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.cell?.truncatesLastVisibleLine = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
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
