import CoreData
import Foundation

protocol ClipboardRepository: AnyObject {
    func fetchItems(filter: String) -> [ClipboardItem]
    func duplicateTextItem(_ text: String) -> ClipboardItem?
    func updateCreatedAt(for item: ClipboardItem, date: Date)
    func insertText(_ text: String, sourceAppBundleId: String?)
    func insertImage(_ data: Data, sourceAppBundleId: String?)
    func trimHistory(maxSize: Int)
    func removeLastUnpinnedItem()
}

final class CoreDataClipboardRepository: ClipboardRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchItems(filter: String = "") -> [ClipboardItem] {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        if !filter.isEmpty {
            request.predicate = NSPredicate(format: "content CONTAINS[cd] %@", filter)
        }

        return (try? context.fetch(request)) ?? []
    }

    func duplicateTextItem(_ text: String) -> ClipboardItem? {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "content == %@ AND contentType == %@", text, ClipboardItemType.text.rawValue)
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try? context.fetch(request).first
    }

    func updateCreatedAt(for item: ClipboardItem, date: Date) {
        item.createdAt = date
        CoreDataStack.shared.saveIfNeeded()
    }

    func insertText(_ text: String, sourceAppBundleId: String?) {
        let item = ClipboardItem(context: context)
        item.uuid = UUID()
        item.content = text
        item.contentType = ClipboardItemType.text.rawValue
        item.createdAt = Date()
        item.isPinned = false
        item.sourceAppBundleId = sourceAppBundleId
        CoreDataStack.shared.saveIfNeeded()
    }

    func insertImage(_ data: Data, sourceAppBundleId: String?) {
        let item = ClipboardItem(context: context)
        item.uuid = UUID()
        item.contentType = ClipboardItemType.image.rawValue
        item.imageData = data
        item.createdAt = Date()
        item.isPinned = false
        item.sourceAppBundleId = sourceAppBundleId
        CoreDataStack.shared.saveIfNeeded()
    }

    func trimHistory(maxSize: Int) {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        guard let items = try? context.fetch(request), items.count > maxSize else { return }

        for item in items[maxSize...] {
            context.delete(item)
        }

        CoreDataStack.shared.saveIfNeeded()
    }

    func removeLastUnpinnedItem() {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1

        guard let item = try? context.fetch(request).first else { return }
        context.delete(item)
        CoreDataStack.shared.saveIfNeeded()
    }
}
