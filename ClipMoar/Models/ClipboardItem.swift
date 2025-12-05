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

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    var displayTitle: String {
        switch ClipboardItemType.from(contentType) {
        case .image:
            guard let data = imageData else { return "Image" }
            let sizeStr: String
            let kb = Double(data.count) / 1024.0
            if kb > 1024 {
                sizeStr = String(format: "%.1f MB", kb / 1024.0)
            } else {
                sizeStr = String(format: "%.0f KB", kb)
            }
            if let img = NSImage(data: data) {
                let w = Int(img.representations.first?.pixelsWide ?? Int(img.size.width))
                let h = Int(img.representations.first?.pixelsHigh ?? Int(img.size.height))
                return "Image: \(w)x\(h) (\(sizeStr))"
            }
            return "Image (\(sizeStr))"
        default:
            return content?.components(separatedBy: .newlines).first ?? ""
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
