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
    @NSManaged public var appliedRule: String?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    var displayTitle: String {
        switch ClipboardItemType.from(contentType) {
        case .image:
            return imageDisplayTitle
        case .file:
            guard let paths = content else { return "File" }
            let files = paths.components(separatedBy: "\n")
            if files.count == 1 {
                return (files[0] as NSString).lastPathComponent
            }
            return "\(files.count) files"
        case .text:
            guard let text = content else { return "" }
            let firstLine = text.components(separatedBy: .newlines)
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                ?? ""
            return firstLine.trimmingCharacters(in: .whitespaces)
        }
    }

    private var imageDisplayTitle: String {
        guard let data = imageData else { return "Image" }
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        if let image = NSImage(data: data) {
            let rep = image.representations.first
            let w = rep?.pixelsWide ?? Int(image.size.width)
            let h = rep?.pixelsHigh ?? Int(image.size.height)
            return "Image \(w)x\(h) - \(sizeStr)"
        }
        return "Image - \(sizeStr)"
    }

    var itemType: ClipboardItemType {
        ClipboardItemType.from(contentType)
    }

    var isImage: Bool {
        itemType == .image
    }

    var isText: Bool {
        itemType == .text
    }

    var isFile: Bool {
        itemType == .file
    }

    var fileURLs: [URL]? {
        guard isFile, let paths = content else { return nil }
        return paths.components(separatedBy: "\n").map { URL(fileURLWithPath: $0) }
    }

    var sourceAppIcon: NSImage? {
        guard let bundleId = sourceAppBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
