import Cocoa
import CoreData

@objc(ClipboardItem)
public class ClipboardItem: NSManagedObject, @unchecked Sendable {
    @NSManaged public var uuid: UUID?
    @NSManaged public var content: String?
    @NSManaged public var contentType: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var isPinned: Bool
    @NSManaged public var sourceAppBundleId: String?
    @NSManaged public var fingerprint: String?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    var displayTitle: String {
        switch ClipboardItemType.from(contentType) {
        case .image:
            return "Image"
        default:
            guard let text = content else { return "" }
            let firstLine = text.components(separatedBy: .newlines)
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                ?? ""
            return firstLine.trimmingCharacters(in: .whitespaces)
        }
    }

    var itemType: ClipboardItemType { ClipboardItemType.from(contentType) }
    var isImage: Bool { itemType == .image }
    var isText: Bool { itemType == .text }

    var sourceAppIcon: NSImage? {
        guard let bundleId = sourceAppBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
