import Cocoa
import ImageIO

final class ClipTableCellView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("FloatingClipCell")
    private static let thumbnailCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 10 * 1024 * 1024
        return cache
    }()

    private static let iconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 30
        return cache
    }()

    private let shortcutLabel = NSTextField(labelWithString: "")
    private var iconLeading: NSLayoutConstraint?
    private var shortcutTrailing: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        nil
    }

    func configure(with item: ClipboardItem, row: Int, fontSize: CGFloat = 15, fontName: String = "", textColor: NSColor = NSColor(calibratedWhite: 0.9, alpha: 1.0), shortcutColor: NSColor = NSColor(calibratedWhite: 0.45, alpha: 1.0), fontWeight: NSFont.Weight = .regular, iconSize: CGFloat = 22, padding: CGFloat = 10) {
        let iconSz = NSSize(width: iconSize, height: iconSize)
        if item.isImage {
            let cacheKey = "\(item.fingerprint ?? item.uuid?.uuidString ?? "img")_\(Int(iconSize))" as NSString
            if let cached = Self.thumbnailCache.object(forKey: cacheKey) {
                imageView?.image = cached
            } else if let data = item.imageData,
                      let thumb = Self.createThumbnail(from: data, maxPixelSize: iconSize * 2)
            {
                thumb.size = iconSz
                Self.thumbnailCache.setObject(thumb, forKey: cacheKey, cost: data.count)
                imageView?.image = thumb
            }
        } else if item.isFile, let urls = item.fileURLs, let first = urls.first {
            let cacheKey = first.path as NSString
            if let cached = Self.iconCache.object(forKey: cacheKey) {
                imageView?.image = cached
            } else {
                let icon = NSWorkspace.shared.icon(forFile: first.path)
                icon.size = iconSz
                Self.iconCache.setObject(icon, forKey: cacheKey)
                imageView?.image = icon
            }
        } else {
            let icon: NSImage
            if let bundleId = item.sourceAppBundleId {
                let cacheKey = bundleId as NSString
                if let cached = Self.iconCache.object(forKey: cacheKey) {
                    icon = cached
                } else if let appIcon = item.sourceAppIcon {
                    appIcon.size = iconSz
                    Self.iconCache.setObject(appIcon, forKey: cacheKey)
                    icon = appIcon
                } else {
                    icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) ?? NSImage()
                }
            } else {
                icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) ?? NSImage()
            }
            icon.size = iconSz
            imageView?.image = icon
        }

        textField?.stringValue = item.displayTitle
        textField?.textColor = textColor
        let weight = item.isPinned ? NSFont.Weight.bold : fontWeight
        if fontName.isEmpty {
            textField?.font = .systemFont(ofSize: fontSize, weight: weight)
        } else {
            textField?.font = NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: weight)
        }

        shortcutLabel.textColor = shortcutColor

        if row < 9 {
            shortcutLabel.stringValue = "\u{2318}\(row + 1)"
            shortcutLabel.isHidden = false
        } else {
            shortcutLabel.isHidden = true
        }

        iconLeading?.constant = padding
        shortcutTrailing?.constant = -padding
    }

    private static func createThumbnail(from data: Data, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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

        let il = icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10)
        iconLeading = il
        let st = shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        shortcutTrailing = st

        NSLayoutConstraint.activate([
            il,
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.trailingAnchor.constraint(equalTo: shortcutLabel.leadingAnchor, constant: -8),

            st,
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutLabel.widthAnchor.constraint(equalToConstant: 36),
        ])
    }
}

final class ClipTableRowView: NSTableRowView {
    var accentColor: NSColor = .init(calibratedRed: 0.15, green: 0.45, blue: 0.65, alpha: 0.9)

    override func drawSelection(in _: NSRect) {
        if selectionHighlightStyle != .none {
            accentColor.setFill()
            bounds.fill()
        }
    }

    override func drawBackground(in _: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
    }
}
