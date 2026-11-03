import Cocoa
import QuartzCore

enum PermissionGuideLayout {
    static let panelSize = NSSize(width: 480, height: 116)
    static let tileHeight: CGFloat = 44
    static let inset: CGFloat = 18
    static let settingsInset: CGFloat = 16
    static let edgeMargin: CGFloat = 8
    static let minSettingsSize = NSSize(width: 300, height: 200)

    static func origin(settings: NSRect, visible: NSRect, size: NSSize) -> NSPoint {
        let x = settings.maxX - size.width - settingsInset
        let y = settings.minY + settingsInset
        return NSPoint(
            x: min(max(x, visible.minX + edgeMargin), visible.maxX - size.width - edgeMargin),
            y: min(max(y, visible.minY + edgeMargin), visible.maxY - size.height - edgeMargin)
        )
    }

    static func appKitFrame(fromQuartz frame: CGRect, primaryHeight: CGFloat) -> NSRect {
        NSRect(x: frame.minX, y: primaryHeight - frame.minY - frame.height, width: frame.width, height: frame.height)
    }

    static func largestSettingsFrame(_ frames: [CGRect]) -> CGRect? {
        frames
            .filter { $0.width >= minSettingsSize.width && $0.height >= minSettingsSize.height }
            .max { $0.width * $0.height < $1.width * $1.height }
    }

    static func listName(for permission: PermissionDragWindow.Permission, osMajorVersion: Int) -> String {
        switch permission {
        case .accessibility: osMajorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
        case .screenRecording: "Screen & System Audio Recording"
        }
    }

    static func instruction(appName: String, listName: String) -> String {
        "↑  Drag \(appName) into the \(listName) list above"
    }
}

final class PermissionDragWindow: NSPanel {
    enum Permission {
        case accessibility, screenRecording

        var settingsURL: URL {
            let pane = self == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
            return URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(pane)")!
        }

        var service: String {
            self == .accessibility ? "Accessibility" : "ScreenCapture"
        }

        var isGranted: Bool {
            self == .accessibility ? AXIsProcessTrusted() : CGPreflightScreenCaptureAccess()
        }
    }

    private static var current: PermissionDragWindow?
    static var resetServices: Set<Permission> = []
    static var resetCommand: (Permission) -> Void = resetStaleEntry
    static var openSettings: (URL) -> Void = { NSWorkspace.shared.open($0) }
    private static let settingsBundleId = "com.apple.systempreferences"
    private static let settingsOwners: Set<String> = ["System Settings", "System Preferences"]
    private static let followInterval: TimeInterval = 0.12
    private static let settingsPatience: TimeInterval = 15
    private static let coldRetryDelays: [TimeInterval] = [0.35, 1.2]

    private var timer: Timer?
    private var retryItems: [DispatchWorkItem] = []
    private var flight: PermissionTileFlight?
    private var tile: PermissionTileView?
    private var hasSeenSettings = false
    private let createdAt = Date()
    private let permission: Permission
    private let isColdStart: Bool

    static func show(_ permission: Permission, from source: NSPoint? = nil) {
        if let current, current.permission != permission {
            current.dismiss()
        }
        if current == nil, !permission.isGranted {
            resetOnce(permission)
        }
        let isColdStart = NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleId).isEmpty
        openSettings(permission.settingsURL)
        guard current == nil, !permission.isGranted, Bundle.main.bundleURL.pathExtension == "app" else { return }
        let window = PermissionDragWindow(permission: permission, isColdStart: isColdStart, source: source)
        current = window
        window.follow()
    }

    static func resetOnce(_ permission: Permission) {
        guard resetServices.insert(permission).inserted else { return }
        resetCommand(permission)
    }

    private static func resetStaleEntry(_ permission: Permission) {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", permission.service, bundleId]
        try? process.run()
        process.waitUntilExit()
    }

    private static var appName: String {
        var name = FileManager.default.displayName(atPath: Bundle.main.bundlePath)
        if name.lowercased().hasSuffix(".app") { name = String(name.dropLast(4)) }
        return name.isEmpty ? "ClipMoar" : name
    }

    private init(permission: Permission, isColdStart: Bool, source: NSPoint?) {
        self.permission = permission
        self.isColdStart = isColdStart
        let size = PermissionGuideLayout.panelSize
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        contentView = makeContent()
        if let source, shouldFly(from: source), let tile {
            tile.isHidden = true
            alphaValue = 0
            flight = makeFlight(from: source, tile: tile)
        }
        timer = Timer(timeInterval: Self.followInterval, repeats: true) { [weak self] _ in
            self?.follow()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit {
        timer?.invalidate()
        retryItems.forEach { $0.cancel() }
        flight?.cancel()
    }

    private func makeContent() -> NSView {
        let size = PermissionGuideLayout.panelSize
        let inset = PermissionGuideLayout.inset
        let content = PermissionGuideBackgroundView(frame: NSRect(origin: .zero, size: size))

        let listName = PermissionGuideLayout.listName(
            for: permission,
            osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
        let label = NSTextField(wrappingLabelWithString: PermissionGuideLayout.instruction(appName: Self.appName, listName: listName))
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.frame = NSRect(x: inset, y: 61, width: size.width - 2 * inset, height: 36)
        content.addSubview(label)

        let tile = PermissionTileView(
            frame: NSRect(x: inset, y: 17, width: size.width - 2 * inset, height: PermissionGuideLayout.tileHeight),
            bundleURL: Bundle.main.bundleURL,
            appName: Self.appName
        )
        content.addSubview(tile)
        self.tile = tile
        return content
    }

    private func shouldFly(from source: NSPoint) -> Bool {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return false }
        return NSApp.windows.contains { $0 !== self && $0.isVisible && $0.frame.contains(source) }
    }

    private func makeFlight(from source: NSPoint, tile: PermissionTileView) -> PermissionTileFlight {
        PermissionTileFlight(
            origin: source,
            image: tile.snapshotImage(),
            target: { [weak self, weak tile] in
                guard let self, let tile else { return nil }
                return convertToScreen(tile.convert(tile.bounds, to: nil)).center
            },
            progress: { [weak self] alpha in self?.alphaValue = alpha },
            finish: { [weak self] in
                self?.tile?.isHidden = false
                self?.alphaValue = 1
                self?.flight = nil
            }
        )
    }

    private func follow() {
        if permission.isGranted {
            dismiss()
            return
        }
        guard let quartz = Self.settingsFrame() else {
            if hasSeenSettings || Date().timeIntervalSince(createdAt) > Self.settingsPatience { dismiss() }
            return
        }
        if !hasSeenSettings {
            hasSeenSettings = true
            scheduleColdStartRetries()
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? quartz.maxY
        let settings = PermissionGuideLayout.appKitFrame(fromQuartz: quartz, primaryHeight: primaryHeight)
        let screen = NSScreen.screens.first { $0.frame.intersects(settings) } ?? NSScreen.main
        let origin = PermissionGuideLayout.origin(
            settings: settings,
            visible: screen?.visibleFrame ?? settings,
            size: frame.size
        )
        setFrameOrigin(origin)
        flight?.startLanding()
        orderFrontRegardless()
        invalidateShadow()
    }

    private func scheduleColdStartRetries() {
        guard isColdStart else { return }
        let url = permission.settingsURL
        for delay in Self.coldRetryDelays {
            let item = DispatchWorkItem { Self.openSettings(url) }
            retryItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func dismiss() {
        timer?.invalidate()
        timer = nil
        retryItems.forEach { $0.cancel() }
        retryItems = []
        flight?.cancel()
        flight = nil
        orderOut(nil)
        if Self.current === self { Self.current = nil }
    }

    private static func settingsFrame() -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        let frames = windows.compactMap { info -> CGRect? in
            guard let owner = info[kCGWindowOwnerName as String] as? String, settingsOwners.contains(owner),
                  info[kCGWindowLayer as String] as? Int == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: boundsDict)
        }
        return PermissionGuideLayout.largestSettingsFrame(frames)
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}

private func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
}

private func drawPermissionTile(in bounds: NSRect, icon: NSImage, name: String, dark: Bool) {
    let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
    NSColor(white: dark ? 0.18 : 0.89, alpha: 1).setFill()
    background.fill()
    NSColor(white: dark ? 1 : 0, alpha: 0.10).setStroke()
    background.lineWidth = 1
    background.stroke()
    icon.draw(in: NSRect(x: 10, y: 6, width: 32, height: 32))
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor(white: dark ? 0.94 : 0.12, alpha: 1),
    ]
    (name as NSString).draw(at: NSPoint(x: 52, y: 14), withAttributes: attributes)
}

private final class PermissionGuideBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.borderWidth = 1
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
        }
    }
}

private final class PermissionTileView: NSView, NSDraggingSource {
    private let bundleURL: URL
    private let icon: NSImage
    private let appName: String
    private var mouseDownEvent: NSEvent?

    init(frame frameRect: NSRect, bundleURL: URL, appName: String) {
        self.bundleURL = bundleURL
        self.appName = appName
        icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 32, height: 32)
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func draw(_: NSRect) {
        drawPermissionTile(in: bounds, icon: icon, name: appName, dark: isDarkAppearance(effectiveAppearance))
    }

    func snapshotImage() -> NSImage {
        let dark = isDarkAppearance(effectiveAppearance)
        let icon = icon
        let name = appName
        return NSImage(size: bounds.size, flipped: false) { rect in
            drawPermissionTile(in: rect, icon: icon, name: name, dark: dark)
            return true
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownEvent else { return }
        let dx = event.locationInWindow.x - start.locationInWindow.x
        let dy = event.locationInWindow.y - start.locationInWindow.y
        guard hypot(dx, dy) >= 3 else { return }
        let item = NSDraggingItem(pasteboardWriter: bundleURL as NSURL)
        item.setDraggingFrame(bounds, contents: snapshotImage())
        let session = beginDraggingSession(with: [item], event: start, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .none
        mouseDownEvent = nil
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

private final class PermissionTileFlight {
    private static let padding: CGFloat = 40
    private static let lift: TimeInterval = 0.18
    private static let duration: TimeInterval = 0.62
    private static let patience: TimeInterval = 4
    private static let rise: CGFloat = 12

    private let panel: NSPanel
    private let layer = CALayer()
    private let blur = CIFilter(name: "CIGaussianBlur")
    private let origin: NSPoint
    private let target: () -> NSPoint?
    private let progress: (CGFloat) -> Void
    private let finish: () -> Void
    private let shownAt = CACurrentMediaTime()
    private var landingStartedAt: CFTimeInterval?
    private var timer: Timer?

    init(origin: NSPoint, image: NSImage, target: @escaping () -> NSPoint?, progress: @escaping (CGFloat) -> Void, finish: @escaping () -> Void) {
        self.origin = origin
        self.target = target
        self.progress = progress
        self.finish = finish
        let tileSize = image.size
        let size = NSSize(width: tileSize.width + 2 * Self.padding, height: tileSize.height + 2 * Self.padding)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let host = NSView(frame: NSRect(origin: .zero, size: size))
        host.wantsLayer = true
        host.layerUsesCoreImageFilters = true
        layer.bounds = CGRect(origin: .zero, size: tileSize)
        layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        layer.contents = image
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: -6)
        blur?.name = "blur"
        blur?.setValue(0, forKey: kCIInputRadiusKey)
        layer.filters = blur.map { [$0] }
        host.layer?.addSublayer(layer)
        panel.contentView = host

        place(center: origin, scale: 0.7, blur: 4, opacity: 0)
        panel.orderFrontRegardless()
        timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            self?.step()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit {
        timer?.invalidate()
        panel.orderOut(nil)
    }

    func startLanding() {
        if landingStartedAt == nil { landingStartedAt = CACurrentMediaTime() }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
    }

    private func end() {
        cancel()
        finish()
    }

    private func step() {
        let now = CACurrentMediaTime()
        guard let startedAt = landingStartedAt else {
            if now - shownAt > Self.patience {
                end()
                return
            }
            let t = Self.easeOut(Self.clamp((now - shownAt) / Self.lift))
            place(center: NSPoint(x: origin.x, y: origin.y + Self.rise * t), scale: 0.7 + 0.1 * t, blur: 4 * (1 - t), opacity: t)
            return
        }
        guard let landing = target() else {
            end()
            return
        }
        let t = Self.clamp((now - startedAt) / Self.duration)
        let e = Self.easeInOut(t)
        let start = NSPoint(x: origin.x, y: origin.y + Self.rise)
        let distance = hypot(landing.x - start.x, landing.y - start.y)
        let control = NSPoint(x: (start.x + landing.x) / 2, y: max(start.y, landing.y) + min(160, distance * 0.25))
        let u = 1 - e
        let point = NSPoint(
            x: u * u * start.x + 2 * u * e * control.x + e * e * landing.x,
            y: u * u * start.y + 2 * u * e * control.y + e * e * landing.y
        )
        place(center: point, scale: 0.8 + 0.2 * e, blur: 6 * sin(.pi * e), opacity: 1)
        progress(Self.easeOut(Self.clamp((t - 0.45) / 0.55)))
        if t >= 1 { end() }
    }

    private func place(center: NSPoint, scale: CGFloat, blur radius: CGFloat, opacity: CGFloat) {
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeScale(scale, scale, 1)
        layer.opacity = Float(opacity)
        layer.setValue(radius, forKeyPath: "filters.blur.inputRadius")
        CATransaction.commit()
    }

    private static func clamp(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }

    private static func easeOut(_ t: CGFloat) -> CGFloat {
        1 - pow(1 - t, 3)
    }

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
}
