import Cocoa

final class LargeTypeWindow: NSWindow {
    private let textView = NSTextView()
    private let contentImageView = NSImageView()
    private let backdropView = NSView()
    private let overlayView = NSView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool {
        false
    }

    private func setupViews(in _: NSRect) {
        contentView?.subviews.forEach { $0.removeFromSuperview() }
        guard let cv = contentView else { return }

        overlayView.frame = cv.bounds
        overlayView.autoresizingMask = [.width, .height]
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor(white: 0, alpha: 0.6).cgColor
        cv.addSubview(overlayView)

        backdropView.wantsLayer = true
        backdropView.layer?.cornerRadius = 16
        backdropView.layer?.masksToBounds = true
        backdropView.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.9).cgColor
        cv.addSubview(backdropView)

        contentImageView.imageScaling = .scaleProportionallyDown
        contentImageView.imageAlignment = .alignCenter
    }

    func showText(_ text: String) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        setFrame(screenFrame, display: true)
        setupViews(in: screenFrame)

        let cvSize = contentView?.bounds.size ?? screenFrame.size
        let maxWidth = cvSize.width * 0.95
        let maxHeight = cvSize.height * 0.9
        let padding: CGFloat = 40
        let fontSize = fontSizeForLength(text.count)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)

        let textWidth = maxWidth - padding * 2

        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )

        let contentW = min(max(boundingRect.width, 200), textWidth)
        let contentH = boundingRect.height

        let backdropW = contentW + padding * 2
        let backdropH = min(contentH + padding * 2, maxHeight)

        let x = (cvSize.width - backdropW) / 2
        let y = (cvSize.height - backdropH) / 2
        backdropView.frame = NSRect(x: x, y: y, width: backdropW, height: backdropH)

        textView.frame = backdropView.bounds.insetBy(dx: padding, dy: padding)
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.string = text
        textView.font = font
        textView.textColor = .white
        textView.alignment = .center
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: contentW, height: .greatestFiniteMagnitude)
        backdropView.addSubview(textView)

        orderFrontRegardless()
    }

    func showImage(_ data: Data) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let image = NSImage(data: data) else { return }
        let screenFrame = screen.frame
        setFrame(screenFrame, display: true)
        setupViews(in: screenFrame)

        let cvSize = contentView?.bounds.size ?? screenFrame.size
        let imageSize = image.size
        let maxW = cvSize.width * 0.7
        let maxH = cvSize.height * 0.7
        let scale = min(maxW / imageSize.width, maxH / imageSize.height, 1.0)
        let w = imageSize.width * scale + 40
        let h = imageSize.height * scale + 40

        let x = (cvSize.width - w) / 2
        let y = (cvSize.height - h) / 2
        backdropView.frame = NSRect(x: x, y: y, width: w, height: h)

        contentImageView.frame = NSRect(x: 20, y: 20, width: w - 40, height: h - 40)
        contentImageView.image = image
        backdropView.addSubview(contentImageView)

        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
        textView.string = ""
        contentImageView.image = nil
    }

    private func fontSizeForLength(_ length: Int) -> CGFloat {
        if length <= 10 { return 96 }
        if length <= 30 { return 72 }
        if length <= 100 { return 48 }
        if length <= 300 { return 36 }
        return 24
    }
}

final class LargeTypeController {
    private var window: LargeTypeWindow?
    private var eventMonitor: Any?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func show(item: ClipboardItem) {
        dismiss()

        let win = LargeTypeWindow()

        if item.isImage, let data = item.imageData {
            win.showImage(data)
        } else if let text = item.content, !text.isEmpty {
            win.showText(text)
        } else {
            return
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismiss()
            return event
        }

        window = win
    }

    func dismiss() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.dismiss()
        window = nil
    }
}
