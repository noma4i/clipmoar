import Cocoa
import CoreData

private let listWidth: CGFloat = 460
private let previewWidth: CGFloat = 260
private let rowHeight: CGFloat = 32
private let panelHeight: CGFloat = 32 * 9 + 36 + 20

final class FloatingClipboardViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    private let searchField = NSTextField()
    let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let metaLabel = NSTextField(labelWithString: "")

    private let previewContainer = NSView()
    private let previewTextView = NSTextView()
    private let previewScrollView = NSScrollView()
    private let previewImageView = NSImageView()
    private var previewWidthConstraint: NSLayoutConstraint!
    private var isPreviewVisible = false

    private let repository: ClipboardRepository
    private let actionService: ClipboardActionServicing
    private var items: [ClipboardItem] = []

    init(repository: ClipboardRepository, actionService: ClipboardActionServicing) {
        self.repository = repository
        self.actionService = actionService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: listWidth, height: panelHeight))
        v.appearance = NSAppearance(named: .darkAqua)
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1.0).cgColor
        v.autoresizingMask = [.width, .height]
        self.view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchField()
        setupMetaLabel()
        setupPreviewContainer()
        setupTableView()
        setupKeyHandling()
    }

    // MARK: - Setup

    private func setupSearchField() {
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
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchField.widthAnchor.constraint(equalToConstant: listWidth - 24),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 2),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.widthAnchor.constraint(equalToConstant: listWidth)
        ])
    }

    private func setupMetaLabel() {
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.isEditable = false
        metaLabel.textColor = NSColor(calibratedWhite: 0.45, alpha: 1.0)
        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.alignment = .right
        metaLabel.drawsBackground = false
        view.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            metaLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            metaLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            metaLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            metaLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
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
            previewWidthConstraint
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

        previewContainer.addSubview(previewScrollView)
        previewContainer.addSubview(previewImageView)

        NSLayoutConstraint.activate([
            previewScrollView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            previewScrollView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 4),
            previewScrollView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -4),
            previewScrollView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -4),

            previewImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 4),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -4),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -4)
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
            scrollView.bottomAnchor.constraint(equalTo: metaLabel.topAnchor)
        ])
    }

    private func setupKeyHandling() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  self.view.window?.isVisible == true else { return event }

            if event.keyCode == 53 {
                self.view.window?.orderOut(nil)
                return nil
            }

            if event.keyCode == 36 {
                self.pasteSelected()
                return nil
            }

            if event.modifierFlags.contains(.command),
               let char = event.characters,
               let num = Int(char), num >= 1, num <= 9 {
                self.pasteItem(at: num - 1)
                return nil
            }

            // Arrow up/down always go to table
            if event.keyCode == 125 || event.keyCode == 126 {
                self.view.window?.makeFirstResponder(self.tableView)
                self.tableView.keyDown(with: event)
                return nil
            }

            if event.keyCode == 51 {
                if self.view.window?.firstResponder !== self.searchField.currentEditor() {
                    self.view.window?.makeFirstResponder(self.searchField)
                }
                if !self.searchField.stringValue.isEmpty {
                    self.searchField.stringValue = String(self.searchField.stringValue.dropLast())
                    self.fetchItems(filter: self.searchField.stringValue)
                }
                return nil
            }

            let navKeys: Set<UInt16> = [125, 126, 116, 121, 115, 119, 123, 124]
            if !navKeys.contains(event.keyCode),
               !event.modifierFlags.contains(.command),
               let chars = event.characters, !chars.isEmpty,
               chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
                self.view.window?.makeFirstResponder(self.searchField)
                self.searchField.stringValue += chars
                self.fetchItems(filter: self.searchField.stringValue)
                return nil
            }

            return event
        }
    }

    // MARK: - Preview

    private func showPreview(for item: ClipboardItem) {
        if item.contentType == "image", let data = item.imageData {
            previewScrollView.isHidden = true
            previewImageView.isHidden = false
            previewImageView.image = NSImage(data: data)
        } else {
            previewScrollView.isHidden = false
            previewImageView.isHidden = true
            previewTextView.string = item.content ?? ""
        }

        if !isPreviewVisible {
            isPreviewVisible = true
            guard let window = view.window else { return }
            let frame = window.frame
            let newWidth = listWidth + previewWidth
            window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y,
                                   width: newWidth, height: frame.height), display: true)
            previewWidthConstraint.constant = previewWidth
            view.layoutSubtreeIfNeeded()
        }
    }

    private func hidePreview() {
        guard isPreviewVisible else { return }
        isPreviewVisible = false
        previewTextView.string = ""
        previewImageView.image = nil

        guard let window = view.window else { return }
        let frame = window.frame
        previewWidthConstraint.constant = 0
        window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y,
                               width: listWidth, height: frame.height), display: true)
        view.layoutSubtreeIfNeeded()
    }

    // MARK: - Public

    func refresh() {
        searchField.stringValue = ""
        hidePreview()
        fetchItems()
    }

    func focusOnList() {
        view.window?.makeFirstResponder(tableView)
        if tableView.numberOfRows > 0 && tableView.selectedRow < 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Data

    private func fetchItems(filter: String = "") {
        items = repository.fetchItems(filter: filter)
        tableView.reloadData()

        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateSelection(for: 0)
        } else {
            metaLabel.stringValue = ""
            hidePreview()
        }
    }

    private func updateSelection(for row: Int) {
        guard row >= 0, row < items.count else {
            metaLabel.stringValue = ""
            hidePreview()
            return
        }

        let item = items[row]
        var parts: [String] = []
        if let content = item.content {
            let words = content.split(separator: " ").count
            parts.append("\(words) words; \(content.count) chars")
        } else if item.contentType == "image", let data = item.imageData {
            let kb = Double(data.count) / 1024.0
            parts.append(kb > 1024 ? String(format: "%.1f MB", kb / 1024.0) : String(format: "%.0f KB", kb))
        }
        if let date = item.createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            parts.append("Copied Today \(formatter.string(from: date))")
        }
        metaLabel.stringValue = parts.joined(separator: "  ")

        let hasPreview = (item.contentType == "image" && item.imageData != nil)
            || (item.content != nil && (item.content?.count ?? 0) > 50)
        if hasPreview {
            showPreview(for: item)
        } else {
            hidePreview()
        }
    }

    // MARK: - Actions

    @objc private func pasteSelected() {
        pasteItem(at: tableView.selectedRow)
    }

    private func pasteItem(at index: Int) {
        guard index >= 0, index < items.count else { return }
        let item = items[index]

        view.window?.orderOut(nil)
        actionService.pasteFromPasteboard(item: item)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < items.count else { return nil }
        let item = items[row]

        let identifier = NSUserInterfaceItemIdentifier("FloatingClipCell")
        let cellView: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            cellView = reused
        } else {
            cellView = makeClipCell(identifier: identifier)
        }

        if let imageView = cellView.imageView {
            if item.contentType == "image", let data = item.imageData, let thumb = NSImage(data: data) {
                thumb.size = NSSize(width: 22, height: 22)
                imageView.image = thumb
            } else {
                imageView.image = item.sourceAppIcon
                    ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
                imageView.image?.size = NSSize(width: 22, height: 22)
            }
        }

        cellView.textField?.stringValue = item.displayTitle
        cellView.textField?.textColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)
        cellView.textField?.font = item.isPinned
            ? .boldSystemFont(ofSize: 15)
            : .systemFont(ofSize: 15)

        let shortcutLabel = cellView.viewWithTag(100) as? NSTextField
        if row < 9 {
            shortcutLabel?.stringValue = "\u{2318}\(row + 1)"
            shortcutLabel?.isHidden = false
        } else {
            shortcutLabel?.isHidden = true
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ClipTableRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateSelection(for: tableView.selectedRow)
    }

    // MARK: - Cell Factory

    private func makeClipCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)
        cell.imageView = icon

        let title = NSTextField(labelWithString: "")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.lineBreakMode = .byTruncatingTail
        title.drawsBackground = false
        cell.addSubview(title)
        cell.textField = title

        let shortcut = NSTextField(labelWithString: "")
        shortcut.translatesAutoresizingMaskIntoConstraints = false
        shortcut.textColor = NSColor(calibratedWhite: 0.45, alpha: 1.0)
        shortcut.alignment = .right
        shortcut.drawsBackground = false
        shortcut.tag = 100
        cell.addSubview(shortcut)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            title.trailingAnchor.constraint(equalTo: shortcut.leadingAnchor, constant: -8),

            shortcut.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            shortcut.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            shortcut.widthAnchor.constraint(equalToConstant: 36)
        ])

        return cell
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        fetchItems(filter: searchField.stringValue)
    }
}

final class ClipTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.65, alpha: 0.9).setFill()
            bounds.fill()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
    }
}
