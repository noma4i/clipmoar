import Cocoa
import CoreData

final class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let repository: ClipboardRepository
    private let actionService: ClipboardActionServicing
    private let context: NSManagedObjectContext
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var fetchedResultsController: NSFetchedResultsController<ClipboardItem>?

    init(repository: ClipboardRepository, actionService: ClipboardActionServicing, context: NSManagedObjectContext) {
        self.repository = repository
        self.actionService = actionService
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
        setupTableView()
    }

    private func setupTableView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        column.title = "Clipboard History"
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(copySelectedItem)
    }

    private func setupFetchedResultsController() {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false),
        ]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: CoreDataStack.shared.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        try? fetchedResultsController?.performFetch()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidChange),
            name: .NSManagedObjectContextObjectsDidChange,
            object: CoreDataStack.shared.viewContext
        )
    }

    @objc private func contextDidChange(_: Notification) {
        try? fetchedResultsController?.performFetch()
        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in _: NSTableView) -> Int {
        fetchedResultsController?.fetchedObjects?.count ?? 0
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard let items = fetchedResultsController?.fetchedObjects, row < items.count else { return nil }
        let item = items[row]

        let identifier = NSUserInterfaceItemIdentifier("ClipCell")
        let cellView = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
            ?? NSTableCellView()
        cellView.identifier = identifier

        if cellView.textField == nil {
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cellView.addSubview(textField)
            cellView.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])
        }

        if item.contentType == "image" {
            cellView.textField?.stringValue = "[Image]"
        } else {
            cellView.textField?.stringValue = item.content ?? ""
        }

        if item.isPinned {
            cellView.textField?.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        } else {
            cellView.textField?.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }

        return cellView
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        28
    }

    // MARK: - Actions

    @objc private func copySelectedItem() {
        let row = tableView.selectedRow
        guard row >= 0,
              let items = fetchedResultsController?.fetchedObjects,
              row < items.count else { return }

        let item = items[row]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.contentType == "image", let data = item.imageData {
            pasteboard.setData(data, forType: .tiff)
        } else if let content = item.content {
            pasteboard.setString(content, forType: .string)
        }
    }
}
