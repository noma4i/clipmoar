import Cocoa

final class ClipTableCellView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("FloatingClipCell")
    private let shortcutLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        nil
    }

    func configure(with item: ClipboardItem, row: Int) {
        if item.isImage, let data = item.imageData, let thumb = NSImage(data: data) {
            thumb.size = NSSize(width: 22, height: 22)
            imageView?.image = thumb
        } else if item.isFile, let urls = item.fileURLs, let first = urls.first {
            let icon = NSWorkspace.shared.icon(forFile: first.path)
            icon.size = NSSize(width: 22, height: 22)
            imageView?.image = icon
        } else {
            imageView?.image = item.sourceAppIcon
                ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
            imageView?.image?.size = NSSize(width: 22, height: 22)
        }

        textField?.stringValue = item.displayTitle
        textField?.textColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)
        textField?.font = item.isPinned
            ? .boldSystemFont(ofSize: 15)
            : .systemFont(ofSize: 15)

        if row < 9 {
            shortcutLabel.stringValue = "\u{2318}\(row + 1)"
            shortcutLabel.isHidden = false
        } else {
            shortcutLabel.isHidden = true
        }
    }

    private func setupSubviews() {
        identifier = Self.identifier

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        imageView = icon

        let title = NSTextField(labelWithString: "")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.lineBreakMode = .byTruncatingTail
        title.drawsBackground = false
        addSubview(title)
        textField = title

        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.textColor = NSColor(calibratedWhite: 0.45, alpha: 1.0)
        shortcutLabel.alignment = .right
        shortcutLabel.drawsBackground = false
        addSubview(shortcutLabel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.trailingAnchor.constraint(equalTo: shortcutLabel.leadingAnchor, constant: -8),

            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutLabel.widthAnchor.constraint(equalToConstant: 36),
        ])
    }
}

final class ClipTableRowView: NSTableRowView {
    override func drawSelection(in _: NSRect) {
        if selectionHighlightStyle != .none {
            NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.65, alpha: 0.9).setFill()
            bounds.fill()
        }
    }

    override func drawBackground(in _: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
    }
}
