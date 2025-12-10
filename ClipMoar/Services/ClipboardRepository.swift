import CoreData
import Foundation

protocol ClipboardRepository: AnyObject {
    func fetchItems(filter: String) -> [ClipboardItem]
    func isDuplicate(fingerprint: String) -> Bool
    @discardableResult func insertText(_ text: String, sourceAppBundleId: String?, fingerprint: String) -> UUID
    @discardableResult func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID
    func removeItem(uuid: UUID)
    func trimHistory(maxSize: Int)
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

        if filter.lowercased() == "image" {
            request.predicate = NSPredicate(format: "contentType == %@", ClipboardItemType.image.rawValue)
        } else if !filter.isEmpty {
            request.predicate = NSPredicate(format: "content CONTAINS[cd] %@", filter)
        }

        return (try? context.fetch(request)) ?? []
    }

    func isDuplicate(fingerprint: String) -> Bool {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "fingerprint == %@", fingerprint)
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    @discardableResult
    func insertText(_ text: String, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        let id = UUID()
        let item = ClipboardItem(context: context)
        item.uuid = id
        item.content = text
        item.contentType = ClipboardItemType.text.rawValue
        item.createdAt = Date()
        item.isPinned = false
        item.sourceAppBundleId = sourceAppBundleId
        item.fingerprint = fingerprint
        CoreDataStack.shared.saveIfNeeded()
        return id
    }

    @discardableResult
    func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        let id = UUID()
        let item = ClipboardItem(context: context)
        item.uuid = id
        item.contentType = ClipboardItemType.image.rawValue
        item.imageData = data
        item.createdAt = Date()
        item.isPinned = false
        item.sourceAppBundleId = sourceAppBundleId
        item.fingerprint = fingerprint
        CoreDataStack.shared.saveIfNeeded()
        return id
    }

    func removeItem(uuid: UUID) {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        request.fetchLimit = 1

        guard let item = try? context.fetch(request).first else { return }
        context.delete(item)
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
}
