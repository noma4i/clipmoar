import Foundation

enum ClipboardItemType: String {
    case text
    case image

    static func from(_ rawValue: String?) -> ClipboardItemType {
        guard let rawValue else { return .text }
        return ClipboardItemType(rawValue: rawValue) ?? .text
    }
}
