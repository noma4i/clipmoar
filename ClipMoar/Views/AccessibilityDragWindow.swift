import Cocoa

final class AccessibilityDragWindow: NSPanel {
    private static var current: AccessibilityDragWindow?
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    private static let settingsBundleId = "com.apple.systempreferences"
    private static let size = NSSize(width: 300, height: 68)

    private var timer: Timer?
    private var hasSeenSettings = false

    static func show() {
        if current == nil, !AXIsProcessTrusted() {
            resetStaleEntry()
        }
        NSWorkspace.shared.open(settingsURL)
        guard current == nil, !AXIsProcessTrusted() else { return }
        let window = AccessibilityDragWindow()
        current = window
        window.follow()
    }

    private static func resetStaleEntry() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleId]
        try? process.run()
        process.waitUntilExit()
    }

    private init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        contentView = makeContent()
        invalidateShadow()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.follow()
        }
    }

    private func makeContent() -> NSView {
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        background.material = .popover
        background.state = .active
        background.maskImage = Self.roundedMask(radius: Self.size.height / 2.8)

        let iconSize: CGFloat = 44
        let icon = AppIconDragView(
            frame: NSRect(x: 14, y: (Self.size.height - iconSize) / 2, width: iconSize, height: iconSize)
        )
        background.addSubview(icon)

        let title = NSTextField(labelWithString: "Drag ClipMoar into the list")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 70, y: 36, width: Self.size.width - 70 - 34, height: 17)
        background.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Then switch it on in System Settings")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.frame = NSRect(x: 70, y: 17, width: Self.size.width - 70 - 34, height: 15)
        background.addSubview(subtitle)

        let close = NSButton(frame: NSRect(x: Self.size.width - 28, y: (Self.size.height - 16) / 2, width: 16, height: 16))
        close.bezelStyle = .regularSquare
        close.isBordered = false
        close.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        close.contentTintColor = .tertiaryLabelColor
        close.target = self
        close.action = #selector(dismiss)
        background.addSubview(close)
        return background
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func follow() {
        let isSettingsRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.settingsBundleId).isEmpty
        hasSeenSettings = hasSeenSettings || isSettingsRunning
        if AXIsProcessTrusted() || (hasSeenSettings && !isSettingsRunning) {
            dismiss()
            return
        }
        let isSettingsFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.settingsBundleId
        guard isSettingsFrontmost, let settingsFrame = Self.systemSettingsFrame() else {
            orderOut(nil)
            return
        }
        let screen = NSScreen.screens.first { $0.frame.intersects(settingsFrame) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? settingsFrame
        let gap: CGFloat = 8
        let belowY = settingsFrame.minY - Self.size.height - gap
        let y = belowY >= visible.minY ? belowY : settingsFrame.minY + 44
        setFrameOrigin(NSPoint(x: settingsFrame.midX - Self.size.width / 2, y: y))
        guard !isVisible else { return }
        alphaValue = 0
        orderFrontRegardless()
        invalidateShadow()
        animator().alphaValue = 1
    }

    @objc private func dismiss() {
        timer?.invalidate()
        timer = nil
        orderOut(nil)
        Self.current = nil
    }

    private static func systemSettingsFrame() -> NSRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        for info in windows {
            guard info[kCGWindowOwnerName as String] as? String == "System Settings",
                  info[kCGWindowLayer as String] as? Int == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            return NSRect(x: bounds.minX, y: primaryHeight - bounds.maxY, width: bounds.width, height: bounds.height)
        }
        return nil
    }
}

private final class AppIconDragView: NSImageView, NSDraggingSource {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        image = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        imageScaling = .scaleProportionallyUpOrDown
        isEditable = false
        toolTip = "Drag into the Accessibility list"
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func mouseDown(with _: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
