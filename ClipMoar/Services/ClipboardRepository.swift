import CoreData
import Foundation

protocol ClipboardRepository: AnyObject {
    func fetchItems(filter: String) -> [ClipboardItem]
    func isDuplicate(fingerprint: String) -> Bool
    @discardableResult func insertText(_ text: String, sourceAppBundleId: String?, fingerprint: String, appliedRule: String?) -> UUID
    @discardableResult func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID
    @discardableResult func insertFile(_ paths: String, sourceAppBundleId: String?, fingerprint: String) -> UUID
    func moveToTop(uuid: UUID)
    func removeItem(uuid: UUID)
    func trimHistory(maxSize: Int)
    func removeOlderThan(hours: Int, contentType: String?)
    func storageStats() -> StorageStats
    func clearAll(contentType: String?)
    func releaseMemory()
}

struct StorageStats {
    var textCount: Int = 0
    var imageCount: Int = 0
    var fileCount: Int = 0
    var textBytes: Int64 = 0
    var imageBytes: Int64 = 0

    var totalBytes: Int64 {
        textBytes + imageBytes
    }

    func formatted(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

final class CoreDataClipboardRepository: ClipboardRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchItems(filter: String = "") -> [ClipboardItem] {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.fetchBatchSize = 50
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false),
        ]

        if !filter.isEmpty {
            let lower = filter.lowercased()
            let textPredicate = NSPredicate(format: "content CONTAINS[cd] %@", filter)
            var extraPredicates: [NSPredicate] = []

            if "image".hasPrefix(lower) {
                extraPredicates.append(NSPredicate(format: "contentType == %@", ClipboardItemType.image.rawValue))
            }
            if "file".hasPrefix(lower) || "files".hasPrefix(lower) {
                extraPredicates.append(NSPredicate(format: "contentType == %@", ClipboardItemType.file.rawValue))
            }

            if !extraPredicates.isEmpty {
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: extraPredicates + [textPredicate])
            } else {
                request.predicate = textPredicate
            }
        }

        return (try? context.fetch(request)) ?? []
    }

    func isDuplicate(fingerprint: String) -> Bool {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1
        guard let last = try? context.fetch(request).first else { return false }
        return last.fingerprint == fingerprint
    }

    @discardableResult
    func insertText(_ text: String, sourceAppBundleId: String?, fingerprint: String, appliedRule: String? = nil) -> UUID {
        createItem(sourceAppBundleId: sourceAppBundleId, fingerprint: fingerprint) {
            $0.content = text
            $0.contentType = ClipboardItemType.text.rawValue
            $0.appliedRule = appliedRule
        }
    }

    @discardableResult
    func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        createItem(sourceAppBundleId: sourceAppBundleId, fingerprint: fingerprint) {
            $0.contentType = ClipboardItemType.image.rawValue
            $0.imageData = data
        }
    }

    @discardableResult
    func insertFile(_ paths: String, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        createItem(sourceAppBundleId: sourceAppBundleId, fingerprint: fingerprint) {
            $0.content = paths
            $0.contentType = ClipboardItemType.file.rawValue
        }
    }

    private func createItem(sourceAppBundleId: String?, fingerprint: String, configure: (ClipboardItem) -> Void) -> UUID {
        let id = UUID()
        let item = ClipboardItem(context: context)
        item.uuid = id
        item.createdAt = Date()
        item.isPinned = false
        item.sourceAppBundleId = sourceAppBundleId
        item.fingerprint = fingerprint
        configure(item)
        CoreDataStack.shared.saveIfNeeded()
        context.refresh(item, mergeChanges: false)
        return id
    }

    func moveToTop(uuid: UUID) {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        request.fetchLimit = 1

        guard let item = try? context.fetch(request).first else { return }
        item.createdAt = Date()
        CoreDataStack.shared.saveIfNeeded()
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
        request.fetchOffset = maxSize
        request.fetchBatchSize = 100
        request.includesPropertyValues = false

        guard let items = try? context.fetch(request), !items.isEmpty else { return }

        for item in items {
            context.delete(item)
        }

        CoreDataStack.shared.saveIfNeeded()
        context.refreshAllObjects()
    }

    func removeOlderThan(hours: Int, contentType: String?) {
        guard hours > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItem")

        if let contentType = contentType {
            request.predicate = NSPredicate(format: "isPinned == NO AND createdAt < %@ AND contentType == %@", cutoff as CVarArg, contentType)
        } else {
            request.predicate = NSPredicate(format: "isPinned == NO AND createdAt < %@", cutoff as CVarArg)
        }

        executeBatchDelete(request)
    }

    func storageStats() -> StorageStats {
        var stats = StorageStats()
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.fetchBatchSize = 50

        guard let items = try? context.fetch(request) else { return stats }

        for item in items {
            switch ClipboardItemType.from(item.contentType) {
            case .text:
                stats.textCount += 1
                stats.textBytes += Int64(item.content?.utf8.count ?? 0)
            case .image:
                stats.imageCount += 1
                stats.imageBytes += Int64(item.imageData?.count ?? 0)
            case .file:
                stats.fileCount += 1
                stats.textBytes += Int64(item.content?.utf8.count ?? 0)
            }
        }
        context.refreshAllObjects()
        return stats
    }

    func clearAll(contentType: String?) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItem")
        if let contentType = contentType {
            request.predicate = NSPredicate(format: "isPinned == NO AND contentType == %@", contentType)
        } else {
            request.predicate = NSPredicate(format: "isPinned == NO")
        }

        executeBatchDelete(request)
    }

    func releaseMemory() {
        context.refreshAllObjects()
    }

    private func executeBatchDelete(_ request: NSFetchRequest<NSFetchRequestResult>) {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs

        guard let result = try? context.execute(deleteRequest) as? NSBatchDeleteResult,
              let objectIDs = result.result as? [NSManagedObjectID],
              !objectIDs.isEmpty else { return }

        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
            into: [context]
        )
    }
}
