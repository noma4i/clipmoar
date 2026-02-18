import Cocoa

private let listWidth: CGFloat = 460
private let previewWidth: CGFloat = 260
private let rowHeight: CGFloat = 32
private let panelHeight: CGFloat = 32 * 9 + 36 + 28
private let cellFont = NSFont.systemFont(ofSize: 15)
private let availableTextWidth: CGFloat = 460 - 80

final class FloatingClipboardViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate
{
    private let searchField = NSTextField()
    let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let metaLabel = NSTextField(labelWithString: "")

    private let previewContainer = NSView()
    private let previewTextView = NSTextView()
    private let previewScrollView = NSScrollView()
    private let previewImageView = NSImageView()
    private let previewMetaLabel = NSTextField(labelWithString: "")
    private var previewWidthConstraint: NSLayoutConstraint!
    private var isPreviewVisible = false
    private var rulePillView: NSView?

    private let dataSource: FloatingPanelDataSource
    private let settings: SettingsStore
    private let largeTypeController = LargeTypeController()
    var onOpenPreferences: (() -> Void)?
    var previewOnly = false

    private var currentTheme: PanelTheme = .dark
    private var currentFontSize: CGFloat = 15
    private var currentAccentColor: NSColor = .init(calibratedRed: 0.15, green: 0.45, blue: 0.65, alpha: 0.9)

    private var selectedItem: ClipboardItem? {
        dataSource.item(at: tableView.selectedRow)
    }

    init(repository: ClipboardRepository, actionService: ClipboardActionServicing, settings: SettingsStore = UserDefaultsSettingsStore()) {
        self.settings = settings
        dataSource = FloatingPanelDataSource(repository: repository, actionService: actionService)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: listWidth, height: panelHeight))
        v.appearance = NSAppearance(named: .darkAqua)
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1.0).cgColor
        v.autoresizingMask = [.width]
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchField()
        setupMetaLabel()
        setupPreviewContainer()
        setupTableView()
        setupKeyHandling()
    }

    // MARK: - Public

    func refresh() {
        applyTheme()
        searchField.stringValue = ""
        largeTypeController.dismiss()
        hidePreview()
        dataSource.fetch()
        tableView.reloadData()

        if !dataSource.items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateSelection(for: 0)
        } else {
            metaLabel.stringValue = ""
        }
    }

    private func applyTheme() {
        let theme = PanelTheme(rawValue: settings.panelTheme) ?? .dark
        let fontSize = CGFloat(settings.panelFontSize)
        let accent = AccentColor(rawValue: settings.panelAccentColor) ?? .blue

        switch theme {
        case .dark:
            view.appearance = NSAppearance(named: .darkAqua)
            view.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1.0).cgColor
            searchField.textColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)
        case .light:
            view.appearance = NSAppearance(named: .aqua)
            view.layer?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1.0).cgColor
            searchField.textColor = NSColor(calibratedWhite: 0.1, alpha: 1.0)
        case .system:
            view.appearance = nil
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            searchField.textColor = .labelColor
        }

        view.window?.backgroundColor = NSColor(cgColor: view.layer?.backgroundColor ?? CGColor.black) ?? .black

        searchField.font = .systemFont(ofSize: fontSize)
        tableView.rowHeight = max(fontSize * 2.2, 28)

        currentTheme = theme
        currentFontSize = fontSize
        currentAccentColor = accent.color

        let ltSize = settings.largeTypeFontSize
        largeTypeController.fontSize = ltSize > 0 ? CGFloat(ltSize) : nil
    }

    func focusOnList() {
        view.window?.makeFirstResponder(tableView)
        if tableView.numberOfRows > 0, tableView.selectedRow < 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Setup

    private let searchIcon = NSImageView()

    private func setupSearchField() {
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.contentTintColor = NSColor(calibratedWhite: 0.5, alpha: 1.0)
        view.addSubview(searchIcon)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Type to search..."
        searchField.delegate = self
        searchField.focusRingType = .none
        searchField.drawsBackground = false
        searchField.isBordered = false
        searchField.isBezeled = false
        searchField.font = .systemFont(ofSize: 16)
        searchField.textColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)
        searchField.appearance = NSAppearance(named: .darkAqua)
        view.addSubview(searchField)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        view.addSubview(separator)

        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),

            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: listWidth - 12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.widthAnchor.constraint(equalToConstant: listWidth),
        ])
    }

    private let metaPill = NSView()

    private func setupMetaLabel() {
        metaPill.translatesAutoresizingMaskIntoConstraints = false
        metaPill.wantsLayer = true
        metaPill.layer?.backgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.5).cgColor
        metaPill.layer?.cornerRadius = 10
        metaPill.isHidden = true

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.isEditable = false
        metaLabel.textColor = NSColor(calibratedWhite: 0.7, alpha: 1.0)
        metaLabel.font = .systemFont(ofSize: 10)
        metaLabel.alignment = .center
        metaLabel.drawsBackground = false
        metaPill.addSubview(metaLabel)
    }

    private func setupPreviewContainer() {
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0).cgColor
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
        previewTextView.textColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)
        previewTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        previewTextView.textContainerInset = NSSize(width: 6, height: 6)
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
        previewMetaLabel.font = .systemFont(ofSize: 10)
        previewMetaLabel.textColor = NSColor(calibratedWhite: 0.8, alpha: 1.0)
        previewMetaLabel.isEditable = false
        previewMetaLabel.drawsBackground = false
        previewMetaLabel.alignment = .center
        rulePill.addSubview(previewMetaLabel)

        previewContainer.addSubview(rulePill)
        previewContainer.addSubview(previewScrollView)
        previewContainer.addSubview(previewImageView)
        previewContainer.addSubview(metaPill)

        rulePillView = rulePill

        NSLayoutConstraint.activate([
            rulePill.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            rulePill.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),

            previewMetaLabel.topAnchor.constraint(equalTo: rulePill.topAnchor, constant: 3),
            previewMetaLabel.bottomAnchor.constraint(equalTo: rulePill.bottomAnchor, constant: -3),
            previewMetaLabel.leadingAnchor.constraint(equalTo: rulePill.leadingAnchor, constant: 8),
            previewMetaLabel.trailingAnchor.constraint(equalTo: rulePill.trailingAnchor, constant: -8),

            previewScrollView.topAnchor.constraint(equalTo: rulePill.bottomAnchor, constant: 4),
            previewScrollView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 8),
            previewScrollView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),
            previewScrollView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -12),

            previewImageView.topAnchor.constraint(equalTo: rulePill.bottomAnchor, constant: 4),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 8),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),
            previewImageView.heightAnchor.constraint(lessThanOrEqualToConstant: panelHeight - 30),

            metaPill.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            metaPill.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -6),

            metaLabel.topAnchor.constraint(equalTo: metaPill.topAnchor, constant: 3),
            metaLabel.bottomAnchor.constraint(equalTo: metaPill.bottomAnchor, constant: -3),
            metaLabel.leadingAnchor.constraint(equalTo: metaPill.leadingAnchor, constant: 10),
            metaLabel.trailingAnchor.constraint(equalTo: metaPill.trailingAnchor, constant: -10),
        ])
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
        tableView.rowHeight = rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.doubleAction = #selector(pasteSelected)
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.appearance = NSAppearance(named: .darkAqua)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: listWidth),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupKeyHandling() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  self.view.window?.isVisible == true else { return event }

            if self.previewOnly {
                switch event.keyCode {
                case 125, 126: // Arrow up/down
                    self.view.window?.makeFirstResponder(self.tableView)
                    self.tableView.keyDown(with: event)
                    return nil
                case 51: // Backspace - search
                    if self.view.window?.firstResponder !== self.searchField.currentEditor() {
                        self.view.window?.makeFirstResponder(self.searchField)
                    }
                    if !self.searchField.stringValue.isEmpty {
                        self.searchField.stringValue = String(self.searchField.stringValue.dropLast())
                        self.performSearch()
                    }
                    return nil
                default:
                    let navKeys: Set<UInt16> = [125, 126, 116, 121, 115, 119, 123, 124, 53, 36, 48]
                    if !navKeys.contains(event.keyCode),
                       !event.modifierFlags.contains(.command),
                       let chars = event.characters, !chars.isEmpty,
                       chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
                    {
                        self.view.window?.makeFirstResponder(self.searchField)
                        self.searchField.stringValue += chars
                        self.performSearch()
                        return nil
                    }
                    return event
                }
            }

            switch event.keyCode {
            case 53: // Escape
                self.largeTypeController.dismiss()
                self.view.window?.orderOut(nil)
                return nil

            case 36: // Return
                self.pasteSelected()
                return nil

            case 48: // Tab - Large Type toggle
                if self.settings.largeTypeEnabled {
                    if self.largeTypeController.isVisible {
                        self.largeTypeController.dismiss()
                    } else if let item = self.selectedItem {
                        self.largeTypeController.show(item: item)
                    }
                }
                return nil

            case 124: // Arrow right - only when Large Type is not showing
                if !self.largeTypeController.isVisible,
                   let item = self.selectedItem
                {
                    self.dataSource.openInExternalPreview(item)
                }
                return nil

            case 125, 126: // Arrow up/down
                self.view.window?.makeFirstResponder(self.tableView)
                self.tableView.keyDown(with: event)
                if self.largeTypeController.isVisible,
                   let item = self.selectedItem
                {
                    self.largeTypeController.show(item: item)
                }
                return nil

            case 51: // Backspace
                if event.modifierFlags.contains(.command) {
                    let row = self.tableView.selectedRow
                    if row >= 0 {
                        self.dataSource.remove(at: row)
                        self.tableView.reloadData()
                        let newRow = min(row, self.dataSource.items.count - 1)
                        if newRow >= 0 {
                            self.tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                            self.updateSelection(for: newRow)
                        }
                    }
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
                // Cmd+, opens preferences
                if event.modifierFlags.contains(.command), event.characters == "," {
                    self.onOpenPreferences?()
                    return nil
                }

                // Cmd+1..9
                if event.modifierFlags.contains(.command),
                   let char = event.characters,
                   let num = Int(char), num >= 1, num <= 9
                {
                    self.pasteAt(num - 1)
                    return nil
                }

                // Typing goes to search
                let navKeys: Set<UInt16> = [125, 126, 116, 121, 115, 119, 123, 124]
                if !navKeys.contains(event.keyCode),
                   !event.modifierFlags.contains(.command),
                   let chars = event.characters, !chars.isEmpty,
                   chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
                {
                    self.view.window?.makeFirstResponder(self.searchField)
                    self.searchField.stringValue += chars
                    self.performSearch()
                    return nil
                }

                return event
            }
        }
    }

    // MARK: - Preview

    private func showPreview(for item: ClipboardItem) {
        previewImageView.image = nil
        previewTextView.string = ""

        if item.isImage, let data = item.imageData {
            previewScrollView.isHidden = true
            previewImageView.isHidden = false
            previewImageView.image = NSImage(data: data)
            rulePillView?.isHidden = true
            previewMetaLabel.stringValue = dataSource.imageMetadata(for: item)
        } else {
            previewImageView.isHidden = true
            previewScrollView.isHidden = false
            previewTextView.string = item.content ?? ""
        }

        if let rule = item.appliedRule, !rule.isEmpty {
            rulePillView?.isHidden = false
            previewMetaLabel.stringValue = "Rule: \(rule)"
        } else {
            rulePillView?.isHidden = true
        }

        metaPill.isHidden = false

        if !isPreviewVisible {
            isPreviewVisible = true
            guard let window = view.window else { return }
            let frame = window.frame
            previewWidthConstraint.constant = previewWidth
            window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y,
                                   width: listWidth + previewWidth, height: panelHeight), display: true)
        }
    }

    private func hidePreview() {
        guard isPreviewVisible else { return }
        isPreviewVisible = false
        previewTextView.string = ""
        previewImageView.image = nil
        metaPill.isHidden = true

        guard let window = view.window else { return }
        let frame = window.frame
        previewWidthConstraint.constant = 0
        window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y,
                               width: listWidth, height: panelHeight), display: true)
    }

    // MARK: - Private

    private func performSearch() {
        dataSource.fetch(filter: searchField.stringValue)
        tableView.reloadData()

        if !dataSource.items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateSelection(for: 0)
        } else {
            metaLabel.stringValue = ""
            hidePreview()
        }
    }

    private func updateSelection(for row: Int) {
        guard let item = dataSource.item(at: row) else {
            metaLabel.stringValue = ""
            hidePreview()
            return
        }

        let meta = dataSource.meta(for: item, availableTextWidth: availableTextWidth, font: cellFont)
        metaLabel.stringValue = meta.text

        showPreview(for: item)
    }

    @objc private func pasteSelected() {
        pasteAt(tableView.selectedRow)
    }

    private func pasteAt(_ index: Int) {
        view.window?.orderOut(nil)
        dataSource.paste(at: index)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in _: NSTableView) -> Int {
        dataSource.items.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard let item = dataSource.item(at: row) else { return nil }

        let cell: ClipTableCellView
        if let reused = tableView.makeView(withIdentifier: ClipTableCellView.identifier, owner: nil) as? ClipTableCellView {
            cell = reused
        } else {
            cell = ClipTableCellView()
        }

        let textColor: NSColor
        let shortcutColor: NSColor
        switch currentTheme {
        case .dark:
            textColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)
            shortcutColor = NSColor(calibratedWhite: 0.45, alpha: 1.0)
        case .light:
            textColor = NSColor(calibratedWhite: 0.1, alpha: 1.0)
            shortcutColor = NSColor(calibratedWhite: 0.5, alpha: 1.0)
        case .system:
            textColor = .labelColor
            shortcutColor = .secondaryLabelColor
        }
        cell.configure(with: item, row: row, fontSize: currentFontSize, textColor: textColor, shortcutColor: shortcutColor)
        return cell
    }

    func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        let row = ClipTableRowView()
        row.accentColor = currentAccentColor
        return row
    }

    func tableViewSelectionDidChange(_: Notification) {
        updateSelection(for: tableView.selectedRow)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_: Notification) {
        performSearch()
    }
}
