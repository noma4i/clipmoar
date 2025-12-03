import Cocoa
import CoreData

final class ClipboardService {
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let context = CoreDataStack.shared.viewContext

        let hasText = pasteboard.string(forType: .string) != nil
        let hasImage = pasteboard.data(forType: .tiff) != nil || pasteboard.data(forType: .png) != nil
        let isEmpty = (pasteboard.pasteboardItems ?? []).isEmpty || (!hasText && !hasImage)

        if isEmpty {
            removeLastUnpinnedItem(in: context)
            return
        }

        let frontmostBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            if !isDuplicate(text: string, in: context) {
                saveTextItem(string, sourceApp: frontmostBundleId, in: context)
            }
        } else if UserDefaults.standard.bool(forKey: Settings.storeImages),
                  let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            saveImageItem(imageData, sourceApp: frontmostBundleId, in: context)
        }

        trimHistory(in: context)
    }

    private func removeLastUnpinnedItem(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1

        guard let item = try? context.fetch(request).first else { return }
        context.delete(item)
        CoreDataStack.shared.save()
    }

    private func isDuplicate(text: String, in context: NSManagedObjectContext) -> Bool {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "content == %@ AND contentType == %@", text, "text")
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        guard let existing = try? context.fetch(request).first else { return false }

        existing.createdAt = Date()
        CoreDataStack.shared.save()
        return true
    }

    private func saveTextItem(_ text: String, sourceApp: String?, in context: NSManagedObjectContext) {
        let item = ClipboardItem(context: context)
        item.uuid = UUID()
        item.content = text
        item.contentType = "text"
        item.createdAt = Date()
        item.isPinned = false
        item.sourceAppBundleId = sourceApp
        CoreDataStack.shared.save()
    }

    private func saveImageItem(_ data: Data, sourceApp: String?, in context: NSManagedObjectContext) {
        let item = ClipboardItem(context: context)
        item.uuid = UUID()
        item.contentType = "image"
        item.imageData = data
        item.createdAt = Date()
        item.isPinned = false
        item.sourceAppBundleId = sourceApp
        CoreDataStack.shared.save()
    }

    private func trimHistory(in context: NSManagedObjectContext) {
        let maxSize = UserDefaults.standard.integer(forKey: Settings.maxHistorySize)
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        guard let items = try? context.fetch(request), items.count > maxSize else { return }

        for item in items[maxSize...] {
            context.delete(item)
        }
        CoreDataStack.shared.save()
    }
}
