import Cocoa

private let defaultPanelHeight: CGFloat = 32 * 9 + 36 + 28

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var result = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        if textHeight < rect.height {
            result.origin.y = rect.origin.y + (rect.height - textHeight) / 2
            result.size.height = textHeight
        }
        return result
    }
}

final class FloatingClipboardViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate
{
    /// Preview content uses mutually exclusive constraint groups per presentation mode.
    private enum PreviewLayoutMode {
        case collapsed
        case text
        case image
    }

    private let searchField = NSTextField()
    let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let metaLabel = NSTextField(labelWithString: "")

    private var accessibilityBannerWindow: NSWindow?
    private var secureInputBannerWindow: NSWindow?
    private let previewContainer = NSView()
    private let previewTextView = NSTextView()
    private let previewScrollView = NSScrollView()
    private let previewImageView = NSImageView()
    private let previewMetaLabel = NSTextField(labelWithString: "")
    private let metaPill = NSView()
    private var rulePillView: NSView?
    private var previewWidthConstraint: NSLayoutConstraint!
    private var previewTextConstraints: [NSLayoutConstraint] = []
    private var previewImageConstraints: [NSLayoutConstraint] = []
    private var searchFieldTop: NSLayoutConstraint?
    private var searchFieldHeight: NSLayoutConstraint?
    private var searchFieldLeading: NSLayoutConstraint?
    private var separatorWidth: NSLayoutConstraint?
    private var scrollViewWidth: NSLayoutConstraint?
    private var previewImageHeight: NSLayoutConstraint?
    private var previewLayoutMode: PreviewLayoutMode = .collapsed
    private var keyMonitor: Any?

    var previousApp: NSRunningApplication?
    private let stateController: FloatingPanelStateController
    private let settings: SettingsStore
    private let largeTypeController = LargeTypeController()
    private let isPreviewRenderer: Bool

    private var currentConfiguration: PanelConfiguration

    var onOpenPreferences: (() -> Void)?
    var onStatEvent: ((StatEventKind) -> Void)? {
        get { stateController.onStatEvent }
        set { stateController.onStatEvent = newValue }
    }

    var previewOnly = false

    private var currentPanelHeight: CGFloat {
        currentConfiguration.layout.panelHeight
    }

    private var selectedItem: ClipboardItem? {
        stateController.selectedItem
    }

    init(
        repository: ClipboardRepository,
        actionService: ClipboardActionServicing,
        settings: SettingsStore = UserDefaultsSettingsStore(),
        isPreviewRenderer: Bool = false
    ) {
        self.settings = settings
        stateController = FloatingPanelStateController(repository: repository, actionService: actionService)
        currentConfiguration = settings.panelConfiguration()
        self.isPreviewRenderer = isPreviewRenderer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
    }

    override func loadView() {
        let frame = NSRect(
            x: 0,
            y: 0,
            width: currentConfiguration.layout.listWidth,
            height: defaultPanelHeight
        )
        let rootView = NSView(frame: frame)
        rootView.appearance = NSAppearance(named: .darkAqua)
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = currentConfiguration.backgroundColor.cgColor
        rootView.autoresizingMask = [.width]
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchField()
        setupMetaLabel()
        setupPreviewContainer()
        setupTableView()
        if !isPreviewRenderer {
            setupKeyHandling()
        }
    }

    func refresh() {
        currentConfiguration = settings.panelConfiguration()
        searchField.stringValue = ""
        largeTypeController.dismiss()
        stateController.reload(configuration: currentConfiguration)
        applyTheme()
        renderState(reloadTable: true)
    }

    func applyTheme() {
        currentConfiguration = settings.panelConfiguration()
        applyConfiguration()
        tableView.reloadData()
        renderState(reloadTable: false)
    }

    func highlightZone(_ zone: HighlightZone?) {
        clearHighlights()
        guard let zone else { return }
        switch zone {
        case .list: addHighlightBorder(to: scrollView)
        case .panel: addHighlightBorder(to: view)
        case .preview: addHighlightBorder(to: previewContainer)
        case .search: addHighlightBorder(to: searchField)
        case .meta:
            addHighlightBorder(to: metaPill)
            if let pill = rulePillView { addHighlightBorder(to: pill) }
        }
    }

    private func addHighlightBorder(to target: NSView) {
        target.wantsLayer = true
        target.layer?.borderWidth = 1.5
        target.layer?.borderColor = NSColor.red.cgColor
    }

    private func clearHighlights() {
        for target in [scrollView, view, previewContainer, searchField, metaPill, rulePillView].compactMap({ $0 as NSView? }) {
            target.layer?.borderWidth = 0
            target.layer?.borderColor = nil
        }
    }

    func focusOnList() {
        view.window?.makeFirstResponder(tableView)
        if tableView.numberOfRows > 0, tableView.selectedRow < 0 {
            let row = max(stateController.state.selectedRow, 0)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func updateAccessibilityBanner() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            accessibilityBannerWindow?.orderOut(nil)
            accessibilityBannerWindow = nil
            return
        }

        guard let window = view.window else { return }

        if accessibilityBannerWindow == nil {
            let bannerHeight: CGFloat = 28
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: currentConfiguration.layout.listWidth, height: bannerHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hidesOnDeactivate = false

            let backgroundView = NSView(
                frame: NSRect(x: 0, y: 0, width: currentConfiguration.layout.listWidth, height: bannerHeight)
            )
            backgroundView.wantsLayer = true
            backgroundView.layer?.backgroundColor = NSColor(
                calibratedRed: 0.85,
                green: 0.5,
                blue: 0.1,
                alpha: 0.95
            ).cgColor
            backgroundView.layer?.cornerRadius = 6

            let iconView = NSImageView(frame: NSRect(x: 8, y: 6, width: 16, height: 16))
            iconView.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil
            )
            iconView.contentTintColor = .white
            backgroundView.addSubview(iconView)

            let label = NSTextField(labelWithString: "Accessibility required for paste. Click to fix.")
            label.frame = NSRect(x: 30, y: 5, width: currentConfiguration.layout.listWidth - 40, height: 18)
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = .white
            label.lineBreakMode = .byTruncatingTail
            backgroundView.addSubview(label)

            let button = NSButton(frame: NSRect(x: 0, y: 0, width: currentConfiguration.layout.listWidth, height: bannerHeight))
            button.isBordered = false
            button.isTransparent = true
            button.target = self
            button.action = #selector(openAccessibilitySettings)
            backgroundView.addSubview(button)

            panel.contentView = backgroundView
            accessibilityBannerWindow = panel
        }

        let frame = window.frame
        let bannerY = frame.maxY + (secureInputBannerWindow != nil ? 36 : 4)
        accessibilityBannerWindow?.setFrameOrigin(NSPoint(x: frame.origin.x, y: bannerY))
        if let banner = accessibilityBannerWindow {
            window.addChildWindow(banner, ordered: .above)
        }
    }

    func updateSecureInputBanner(isActive: Bool) {
        if !isActive {
            secureInputBannerWindow?.orderOut(nil)
            secureInputBannerWindow = nil
            return
        }

        guard let window = view.window else { return }

        if secureInputBannerWindow == nil {
            secureInputBannerWindow = makeBannerWindow(
                icon: "lock.fill",
                text: "Secure Input is active",
                color: NSColor(calibratedRed: 0.8, green: 0.15, blue: 0.15, alpha: 0.95)
            )
        }

        let frame = window.frame
        secureInputBannerWindow?.setFrameOrigin(NSPoint(x: frame.origin.x, y: frame.maxY + 4))
        if let banner = secureInputBannerWindow {
            window.addChildWindow(banner, ordered: .above)
        }
    }

    private func makeBannerWindow(icon: String, text: String, color: NSColor) -> NSWindow {
        let bannerHeight: CGFloat = 28
        let width = currentConfiguration.layout.listWidth

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: bannerHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false

        let bg = NSView(frame: NSRect(x: 0, y: 0, width: width, height: bannerHeight))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = color.cgColor
        bg.layer?.cornerRadius = 6

        let iconView = NSImageView(frame: NSRect(x: 8, y: 6, width: 16, height: 16))
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        iconView.contentTintColor = .white
        bg.addSubview(iconView)

        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 30, y: 5, width: width - 40, height: 18)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        bg.addSubview(label)

        panel.contentView = bg
        return panel
    }

    private func setupSearchField() {
        let layout = currentConfiguration.layout

        searchField.cell = VerticallyCenteredTextFieldCell()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchField.focusRingType = .none
        searchField.drawsBackground = false
        searchField.isBordered = false
        searchField.isBezeled = false
        searchField.appearance = NSAppearance(named: .darkAqua)
        view.addSubview(searchField)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        view.addSubview(separator)

        let textLeading = layout.horizontalPadding + 22 + 10
        let leading = searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: textLeading)
        searchFieldLeading = leading

        NSLayoutConstraint.activate([
            { let constraint = searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: layout.verticalPadding); searchFieldTop = constraint; return constraint }(),
            leading,
            searchField.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: layout.listWidth - layout.horizontalPadding),
            { let constraint = searchField.heightAnchor.constraint(equalToConstant: layout.rowHeight); searchFieldHeight = constraint; return constraint }(),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            { let constraint = separator.widthAnchor.constraint(equalToConstant: layout.listWidth); separatorWidth = constraint; return constraint }(),
        ])
    }

    private func setupMetaLabel() {
        metaPill.translatesAutoresizingMaskIntoConstraints = false
        metaPill.wantsLayer = true
        metaPill.layer?.backgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.5).cgColor
        metaPill.layer?.cornerRadius = 10
        metaPill.isHidden = true

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.isEditable = false
        metaLabel.drawsBackground = false
        metaLabel.alignment = .center
        metaPill.addSubview(metaLabel)
    }

    private func setupPreviewContainer() {
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = currentConfiguration.preview.backgroundColor.cgColor
        view.addSubview(previewContainer)

        previewWidthConstraint = previewContainer.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previewWidthConstraint,
        ])

        previewScrollView.translatesAutoresizingMaskIntoConstraints = false
        previewScrollView.hasVerticalScroller = true
        previewScrollView.drawsBackground = false
        previewScrollView.scrollerStyle = .overlay
        previewScrollView.documentView = previewTextView

        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.drawsBackground = false
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = false
        previewTextView.textContainer?.widthTracksTextView = true

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyDown
        previewImageView.imageAlignment = .alignTop
        previewImageView.isHidden = true
        previewImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        previewImageView.setContentHuggingPriority(.defaultLow, for: .vertical)

        let rulePill = NSView()
        rulePill.translatesAutoresizingMaskIntoConstraints = false
        rulePill.wantsLayer = true
        rulePill.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 0.8).cgColor
        rulePill.layer?.cornerRadius = 8

        previewMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        previewMetaLabel.isEditable = false
        previewMetaLabel.drawsBackground = false
        previewMetaLabel.alignment = .center
        rulePill.addSubview(previewMetaLabel)

        previewContainer.addSubview(rulePill)
        previewContainer.addSubview(previewScrollView)
        previewContainer.addSubview(previewImageView)
        previewContainer.addSubview(metaPill)

        rulePillView = rulePill

        let imageHeightConstraint = previewImageView.heightAnchor.constraint(lessThanOrEqualToConstant: currentPanelHeight - 30)
        previewImageHeight = imageHeightConstraint

        NSLayoutConstraint.activate([
            rulePill.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            rulePill.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),

            previewMetaLabel.topAnchor.constraint(equalTo: rulePill.topAnchor, constant: 3),
            previewMetaLabel.bottomAnchor.constraint(equalTo: rulePill.bottomAnchor, constant: -3),
            previewMetaLabel.leadingAnchor.constraint(equalTo: rulePill.leadingAnchor, constant: 8),
            previewMetaLabel.trailingAnchor.constraint(equalTo: rulePill.trailingAnchor, constant: -8),

            metaPill.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            metaPill.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -6),

            metaLabel.topAnchor.constraint(equalTo: metaPill.topAnchor, constant: 3),
            metaLabel.bottomAnchor.constraint(equalTo: metaPill.bottomAnchor, constant: -3),
            metaLabel.leadingAnchor.constraint(equalTo: metaPill.leadingAnchor, constant: 10),
            metaLabel.trailingAnchor.constraint(equalTo: metaPill.trailingAnchor, constant: -10),
        ])

        previewTextConstraints = [
            previewScrollView.topAnchor.constraint(equalTo: rulePill.bottomAnchor, constant: 4),
            previewScrollView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 8),
            previewScrollView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),
            previewScrollView.bottomAnchor.constraint(equalTo: metaPill.topAnchor, constant: -8),
        ]

        previewImageConstraints = [
            previewImageView.topAnchor.constraint(equalTo: rulePill.bottomAnchor, constant: 4),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 8),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),
            previewImageView.bottomAnchor.constraint(lessThanOrEqualTo: metaPill.topAnchor, constant: -8),
            imageHeightConstraint,
        ]

        applyPreviewLayout(mode: .collapsed)
    }

    private func setupTableView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        view.addSubview(scrollView)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.doubleAction = #selector(pasteSelected)
        tableView.style = .fullWidth
        tableView.selectionHighlightStyle = .regular
        tableView.appearance = NSAppearance(named: .darkAqua)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            { let constraint = scrollView.widthAnchor.constraint(equalToConstant: currentConfiguration.layout.listWidth); scrollViewWidth = constraint; return constraint }(),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func applyConfiguration() {
        let configuration = currentConfiguration

        view.appearance = NSAppearance(named: configuration.theme == .dark ? .darkAqua : .aqua)
        view.layer?.backgroundColor = configuration.backgroundColor.cgColor
        previewContainer.layer?.backgroundColor = configuration.preview.backgroundColor.cgColor

        let layout = configuration.layout

        view.layer?.cornerRadius = layout.cornerRadius
        view.layer?.masksToBounds = layout.cornerRadius > 0 || layout.margin > 0
        if layout.cornerRadius > 0 || layout.margin > 0 {
            view.window?.isOpaque = false
            view.window?.backgroundColor = .clear
        } else {
            view.window?.isOpaque = true
            view.window?.backgroundColor = configuration.backgroundColor
        }

        if let window = view.window {
            let frame = window.frame
            let inset = layout.margin
            view.frame = NSRect(
                x: inset,
                y: inset,
                width: frame.width - inset * 2,
                height: frame.height - inset * 2
            )
        }

        searchFieldTop?.constant = layout.verticalPadding
        searchFieldHeight?.constant = layout.rowHeight
        searchFieldLeading?.constant = layout.horizontalPadding + 22 + 10
        separatorWidth?.constant = layout.listWidth
        scrollViewWidth?.constant = layout.listWidth
        previewImageHeight?.constant = currentPanelHeight - 30

        searchField.font = font(named: configuration.search.fontName, size: configuration.search.fontSize)
        searchField.textColor = configuration.search.textColor
        updateSearchPlaceholder()

        tableView.rowHeight = layout.rowHeight
        previewTextView.font = font(named: configuration.preview.fontName, size: configuration.preview.fontSize)
        previewTextView.textContainerInset = NSSize(width: configuration.preview.padding, height: configuration.preview.padding)
        previewTextView.textColor = configuration.preview.textColor

        metaLabel.font = .systemFont(ofSize: configuration.preview.metaFontSize)
        metaLabel.textColor = configuration.theme == .dark
            ? NSColor(calibratedWhite: 0.7, alpha: 1.0)
            : NSColor(calibratedWhite: 0.35, alpha: 1.0)
        previewMetaLabel.font = .systemFont(ofSize: configuration.preview.metaFontSize)
        previewMetaLabel.textColor = configuration.theme == .dark
            ? NSColor(calibratedWhite: 0.8, alpha: 1.0)
            : NSColor(calibratedWhite: 0.25, alpha: 1.0)

        largeTypeController.fontSize = configuration.largeTypeFontSize
        resizeWindow()
    }

    private func renderState(reloadTable: Bool) {
        if reloadTable {
            tableView.reloadData()
        }

        DispatchQueue.main.async { [weak self] in
            self?.alignSearchFieldToTableText()
        }

        let selectedRow = stateController.state.selectedRow
        if selectedRow >= 0, selectedRow < stateController.items.count {
            tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
        }

        metaLabel.stringValue = stateController.state.metaText
        metaPill.isHidden = stateController.state.metaText.isEmpty
        renderPreview()
        resizeWindow()
    }

    private func renderPreview() {
        let previewState = stateController.state.preview

        guard previewState.isVisible else {
            applyPreviewLayout(mode: .collapsed)
            previewTextView.string = ""
            previewImageView.image = nil
            rulePillView?.isHidden = true
            return
        }

        switch previewState.content {
        case let .text(text):
            applyPreviewLayout(mode: .text)
            previewTextView.string = text
            previewImageView.image = nil
        case let .image(data):
            applyPreviewLayout(mode: .image)
            previewImageView.image = NSImage(data: data)
            previewTextView.string = ""
        case .none:
            applyPreviewLayout(mode: .text)
            previewTextView.string = ""
            previewImageView.image = nil
        }

        if let rule = previewState.ruleText, !rule.isEmpty {
            previewMetaLabel.stringValue = "Rule: \(rule)"
            rulePillView?.isHidden = false
        } else {
            previewMetaLabel.stringValue = previewState.infoText
            rulePillView?.isHidden = previewState.infoText.isEmpty
        }
    }

    private func applyPreviewLayout(mode: PreviewLayoutMode) {
        let desiredWidth = mode == .collapsed ? 0 : currentConfiguration.layout.previewWidth
        guard previewLayoutMode != mode || previewWidthConstraint.constant != desiredWidth else { return }

        NSLayoutConstraint.deactivate(previewTextConstraints)
        NSLayoutConstraint.deactivate(previewImageConstraints)

        previewLayoutMode = mode

        switch mode {
        case .collapsed:
            previewWidthConstraint.constant = desiredWidth
            previewContainer.isHidden = true
            previewScrollView.isHidden = true
            previewImageView.isHidden = true
        case .text:
            previewWidthConstraint.constant = desiredWidth
            previewContainer.isHidden = false
            previewScrollView.isHidden = false
            previewImageView.isHidden = true
            NSLayoutConstraint.activate(previewTextConstraints)
        case .image:
            previewWidthConstraint.constant = desiredWidth
            previewContainer.isHidden = false
            previewScrollView.isHidden = true
            previewImageView.isHidden = false
            NSLayoutConstraint.activate(previewImageConstraints)
        }
    }

    private func resizeWindow() {
        guard let window = view.window else { return }
        let frame = window.frame
        let width = currentConfiguration.layout.listWidth
            + (stateController.state.preview.isVisible ? currentConfiguration.layout.previewWidth : 0)
        let height = currentPanelHeight
        let originY = frame.origin.y + frame.height - height
        window.setFrame(NSRect(x: frame.origin.x, y: originY, width: width, height: height), display: true)
    }

    private func alignSearchFieldToTableText() {
        guard tableView.numberOfRows > 0,
              let cell = tableView.view(atColumn: 0, row: 0, makeIfNecessary: true) as? ClipTableCellView,
              let tf = cell.textField
        else { return }
        let textX = tf.convert(tf.bounds.origin, to: view).x
        searchFieldLeading?.constant = textX
    }

    private func performSearch() {
        stateController.updateFilter(searchField.stringValue, configuration: currentConfiguration)
        renderState(reloadTable: true)
    }

    private func selectRow(_ row: Int, forcePreview: Bool) {
        stateController.selectRow(row, configuration: currentConfiguration, forcePreview: forcePreview)
        renderState(reloadTable: false)
    }

    private func updateSearchPlaceholder() {
        let font = searchField.font ?? .systemFont(ofSize: currentConfiguration.search.fontSize)
        let color = currentConfiguration.search.placeholderColor

        searchField.placeholderAttributedString = NSAttributedString(
            string: "Type to search...",
            attributes: [
                .foregroundColor: color,
                .font: font,
            ]
        )
    }

    private func font(named name: String, size: CGFloat) -> NSFont {
        if let font = NSFont(name: name, size: size) {
            return font
        }
        return .systemFont(ofSize: size)
    }

    private func currentCellFont() -> NSFont {
        if let font = NSFont(name: currentConfiguration.typography.fontName, size: currentConfiguration.typography.fontSize) {
            return font
        }
        return .systemFont(
            ofSize: currentConfiguration.typography.fontSize,
            weight: currentConfiguration.typography.fontWeight
        )
    }

    private func setupKeyHandling() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, event.window == self.view.window else { return event }

            if self.previewOnly {
                switch event.keyCode {
                case 53, 36, 48:
                    return event
                case 51:
                    if event.modifierFlags.contains(.command) { return event }
                    if self.view.window?.firstResponder !== self.searchField.currentEditor() {
                        self.view.window?.makeFirstResponder(self.searchField)
                    }
                    if !self.searchField.stringValue.isEmpty {
                        self.searchField.stringValue = String(self.searchField.stringValue.dropLast())
                        self.performSearch()
                    }
                    return nil
                case 125, 126:
                    self.view.window?.makeFirstResponder(self.tableView)
                    self.tableView.keyDown(with: event)
                    return nil
                case 124:
                    self.stateController.showPreviewForSelection()
                    self.renderState(reloadTable: false)
                    return nil
                default:
                    if event.modifierFlags.contains(.command) { return event }
                    let navigationKeys: Set<UInt16> = [116, 121, 115, 119, 123]
                    if !navigationKeys.contains(event.keyCode),
                       let characters = event.characters, !characters.isEmpty,
                       characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
                    {
                        self.view.window?.makeFirstResponder(self.searchField)
                        self.searchField.stringValue += characters
                        self.performSearch()
                        return nil
                    }
                    return event
                }
            }

            switch event.keyCode {
            case 53:
                self.largeTypeController.dismiss()
                self.view.window?.orderOut(nil)
                return nil

            case 36:
                self.pasteSelected()
                return nil

            case 48:
                if self.settings.largeTypeEnabled {
                    if self.largeTypeController.isVisible {
                        self.largeTypeController.dismiss()
                    } else if let item = self.selectedItem {
                        self.largeTypeController.show(item: item, on: self.view.window?.screen)
                    }
                }
                return nil

            case 124:
                if !self.largeTypeController.isVisible {
                    self.stateController.openExternalPreviewForSelection()
                }
                return nil

            case 125, 126:
                self.view.window?.makeFirstResponder(self.tableView)
                self.tableView.keyDown(with: event)
                if self.largeTypeController.isVisible, let item = self.selectedItem {
                    self.largeTypeController.show(item: item, on: self.view.window?.screen)
                }
                return nil

            case 51:
                if event.modifierFlags.contains(.command) {
                    let newRow = self.stateController.removeSelected(configuration: self.currentConfiguration)
                    self.tableView.reloadData()
                    if let newRow {
                        self.tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                    }
                    self.renderState(reloadTable: false)
                    return nil
                }

                if self.view.window?.firstResponder !== self.searchField.currentEditor() {
                    self.view.window?.makeFirstResponder(self.searchField)
                }
                if !self.searchField.stringValue.isEmpty {
                    self.searchField.stringValue = String(self.searchField.stringValue.dropLast())
                    self.performSearch()
                }
                return nil

            default:
                if event.modifierFlags.contains(.command), event.characters == "," {
                    self.onOpenPreferences?()
                    return nil
                }

                if event.modifierFlags.contains(.command),
                   let characters = event.characters,
                   let number = Int(characters), number >= 1, number <= 9
                {
                    self.pasteAt(number - 1)
                    return nil
                }

                let navigationKeys: Set<UInt16> = [125, 126, 116, 121, 115, 119, 123, 124]
                if !navigationKeys.contains(event.keyCode),
                   !event.modifierFlags.contains(.command),
                   let characters = event.characters, !characters.isEmpty,
                   characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
                {
                    self.view.window?.makeFirstResponder(self.searchField)
                    self.searchField.stringValue += characters
                    self.performSearch()
                    return nil
                }

                return event
            }
        }
    }

    @objc private func pasteSelected() {
        pasteAt(stateController.state.selectedRow)
    }

    private func pasteAt(_ index: Int) {
        let app = previousApp
        view.window?.orderOut(nil)
        stateController.paste(at: index, previousApp: app)
    }

    func numberOfRows(in _: NSTableView) -> Int {
        stateController.items.count
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard let item = stateController.item(at: row) else { return nil }

        let cell: ClipTableCellView
        if let reused = tableView.makeView(
            withIdentifier: ClipTableCellView.identifier,
            owner: nil
        ) as? ClipTableCellView {
            cell = reused
        } else {
            cell = ClipTableCellView()
        }

        let typography = currentConfiguration.typography
        cell.configure(
            with: item,
            row: row,
            fontSize: typography.fontSize,
            fontName: typography.fontName,
            textColor: typography.textColor,
            shortcutColor: typography.textColor.withAlphaComponent(0.5),
            fontWeight: typography.fontWeight,
            iconSize: typography.iconSize,
            padding: currentConfiguration.layout.horizontalPadding
        )
        return cell
    }

    func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        let rowView = ClipTableRowView()
        rowView.accentColor = currentConfiguration.typography.accentColor
        return rowView
    }

    func tableViewSelectionDidChange(_: Notification) {
        selectRow(tableView.selectedRow, forcePreview: stateController.state.preview.isVisible)
    }

    func controlTextDidChange(_: Notification) {
        performSearch()
    }
}
