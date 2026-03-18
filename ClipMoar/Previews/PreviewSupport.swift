#if DEBUG
    import AppKit
    import CoreData
    import SwiftUI

    final class PreviewSettingsStore: SettingsStore {
        // Mutable settings snapshot used by previews instead of UserDefaults.
        var showInDock = true
        var showInMenuBar = true
        var maxHistorySize = 500
        var hotkeyKeyCode = 9
        var hotkeyModifiers: UInt32 = .init(NSEvent.ModifierFlags.command.rawValue)
        var storeText = true
        var storeImages = true
        var textRetentionHours = TextRetention.oneWeek.rawValue
        var imageRetentionHours = ImageRetention.oneWeek.rawValue
        var panelPositionX = 0.5
        var panelPositionY = 0.65
        var panelScreenMode = PanelScreenMode.defaultScreen.rawValue
        var largeTypeEnabled = true
        var panelFontSize = 15
        var panelTheme = PanelTheme.dark.rawValue
        var panelAccentColor = 0
        var panelFontName = ""
        var panelAccentHex = "2672B5"
        var panelCornerRadius = 14
        var panelPaddingH = 12
        var panelPaddingV = 4
        var panelMargin = 10
        var panelFontWeight = 0
        var panelIconSize = 22
        var panelVisibleRows = 9
        var panelTextColorHex = "E6E6E6"
        var previewFontName = ""
        var previewFontSize = 11
        var previewPadding = 10
        var previewTextColorHex = "D9D9D9"
        var previewBgColorHex = "1A1A1A"
        var searchFontName = ""
        var searchFontSize = 16
        var searchTextColorHex = "E6E6E6"
        var searchPlaceholderColorHex = "666666"
        var metaFontSize = 10
        var largeTypeFontSize = 48
        var compressImages = false
        var imageMaxWidth = 0
        var imageMaxHeight = 0
        var imageQuality = 80

        init(theme: PanelTheme = .dark) {
            applyTheme(theme)
        }

        func registerDefaults() {}

        func applyTheme(_ theme: PanelTheme) {
            panelTheme = theme.rawValue
            switch theme {
            case .dark:
                panelAccentHex = "2672B5"
                panelTextColorHex = "E6E6E6"
                previewTextColorHex = "D9D9D9"
                previewBgColorHex = "1A1A1A"
                searchTextColorHex = "E6E6E6"
                searchPlaceholderColorHex = "666666"
            case .light:
                panelAccentHex = "3A78C2"
                panelTextColorHex = "202020"
                previewTextColorHex = "202020"
                previewBgColorHex = "F2F2F2"
                searchTextColorHex = "202020"
                searchPlaceholderColorHex = "8A8A8A"
            }
        }
    }

    final class PreviewClipboardActionService: ClipboardActionServicing {
        func writeToPasteboard(item _: ClipboardItem) {}
        func pasteFromPasteboard(item _: ClipboardItem, previousApp _: NSRunningApplication?) {}
    }

    final class PreviewClipboardRepository: ClipboardRepository {
        private(set) var items: [ClipboardItem]

        init(items: [ClipboardItem]) {
            self.items = items.sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned && !$1.isPinned
                }
                return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
        }

        func fetchItems(filter: String) -> [ClipboardItem] {
            guard !filter.isEmpty else { return items }
            let lower = filter.lowercased()

            return items.filter { item in
                if item.content?.localizedCaseInsensitiveContains(filter) == true {
                    return true
                }
                if lower.hasPrefix("image"), item.isImage {
                    return true
                }
                if lower.hasPrefix("file") || lower.hasPrefix("files"), item.isFile {
                    return true
                }
                return item.displayTitle.localizedCaseInsensitiveContains(filter)
            }
        }

        func isDuplicate(fingerprint _: String) -> Bool {
            false
        }

        @discardableResult
        func insertText(_ text: String, sourceAppBundleId: String?, fingerprint _: String, appliedRule: String?) -> UUID {
            let item = PreviewFixtures.makeTextItem(
                context: items.first?.managedObjectContext ?? PreviewFixtures.makeInMemoryContext(),
                text: text,
                sourceAppBundleId: sourceAppBundleId,
                appliedRule: appliedRule
            )
            items.insert(item, at: 0)
            return item.uuid ?? UUID()
        }

        @discardableResult
        func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint _: String) -> UUID {
            let item = PreviewFixtures.makeImageItem(
                context: items.first?.managedObjectContext ?? PreviewFixtures.makeInMemoryContext(),
                data: data,
                sourceAppBundleId: sourceAppBundleId
            )
            items.insert(item, at: 0)
            return item.uuid ?? UUID()
        }

        @discardableResult
        func insertFile(_ paths: String, sourceAppBundleId: String?, fingerprint _: String) -> UUID {
            let item = PreviewFixtures.makeFileItem(
                context: items.first?.managedObjectContext ?? PreviewFixtures.makeInMemoryContext(),
                paths: paths,
                sourceAppBundleId: sourceAppBundleId
            )
            items.insert(item, at: 0)
            return item.uuid ?? UUID()
        }

        func removeItem(uuid: UUID) {
            items.removeAll { $0.uuid == uuid }
        }

        func trimHistory(maxSize: Int) {
            guard items.count > maxSize else { return }
            items = Array(items.prefix(maxSize))
        }

        func removeOlderThan(hours _: Int, contentType _: String?) {}

        func storageStats() -> StorageStats {
            var stats = StorageStats()
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
            return stats
        }

        func clearAll(contentType: String?) {
            guard let contentType else {
                items.removeAll { !$0.isPinned }
                return
            }
            items.removeAll { !$0.isPinned && $0.contentType == contentType }
        }
    }

    enum PanelPreviewScenario {
        case empty
        case list
        case textPreview
        case imagePreview

        var wantsExpandedPreview: Bool {
            switch self {
            case .textPreview, .imagePreview:
                return true
            case .empty, .list:
                return false
            }
        }
    }

    enum LargeTypePreviewScenario {
        case text
        case image
    }

    enum PreviewFixtures {
        static func makeSettings(theme: PanelTheme = .dark) -> PreviewSettingsStore {
            PreviewSettingsStore(theme: theme)
        }

        static func makeHotkeyRecorder(settings: SettingsStore) -> HotkeyRecorder {
            HotkeyRecorder(settings: settings, onSuspend: {}, onResume: {}, onHotkeyChange: {})
        }

        static func makeRegexStore() -> RegexStore {
            let suiteName = "clipmoar.preview.regex.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let store = RegexStore(defaults: defaults)
            store.patterns = [
                SavedRegex(name: "Trim Prompt", pattern: #"^\$\s*"#, replacement: ""),
                SavedRegex(name: "Normalize Spaces", pattern: #"\s+"#, replacement: " "),
            ]
            return store
        }

        static func makeRulesModel() -> RulesSettingsModel {
            let defaultRule = ClipboardRule(
                name: "Shell Cleanup",
                transforms: [
                    ClipboardTransform(type: .stripShellPrompts),
                    ClipboardTransform(type: .trimWhitespace),
                ]
            )
            let urlRule = ClipboardRule(
                name: "Repair URLs",
                appBundleId: "com.apple.Safari",
                transforms: [
                    ClipboardTransform(type: .repairWrappedURL),
                ]
            )
            let store = InMemoryRuleStore(rules: [defaultRule, urlRule])
            return RulesSettingsModel(engine: ClipboardRuleEngine(store: store))
        }

        static func makeInMemoryContext() -> NSManagedObjectContext {
            let model = CoreDataStack.shared.persistentContainer.managedObjectModel
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            _ = try? coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            return context
        }

        static func makePanelRepository(scenario: PanelPreviewScenario) -> PreviewClipboardRepository {
            let context = makeInMemoryContext()
            let items: [ClipboardItem]

            switch scenario {
            case .empty:
                items = []
            case .list:
                items = [
                    makeTextItem(context: context, text: "brew upgrade clipmoar", sourceAppBundleId: "com.apple.Terminal"),
                    makeFileItem(context: context, paths: "/Users/noma4i/Desktop/Release Notes.md", sourceAppBundleId: "com.apple.finder"),
                    makeTextItem(context: context, text: "Short note from Messages", sourceAppBundleId: "com.apple.MobileSMS", pinned: true),
                ]
            case .textPreview:
                items = [
                    makeTextItem(
                        context: context,
                        text: """
                        curl https://example.com/api \
                          -H 'Authorization: Bearer preview-token' \
                          -d '{\"mode\":\"preview\"}'
                        """,
                        sourceAppBundleId: "com.apple.Terminal",
                        appliedRule: "Shell Cleanup"
                    ),
                    makeTextItem(context: context, text: "Follow-up plain text item", sourceAppBundleId: "com.apple.Notes"),
                ]
            case .imagePreview:
                items = [
                    makeImageItem(context: context, data: makePreviewImageData(), sourceAppBundleId: "com.apple.Preview"),
                    makeTextItem(context: context, text: "Screenshot annotation notes", sourceAppBundleId: "com.apple.TextEdit"),
                ]
            }

            try? context.save()
            return PreviewClipboardRepository(items: items)
        }

        static func makeHistoryContext() -> NSManagedObjectContext {
            let context = makeInMemoryContext()
            _ = makeTextItem(context: context, text: "Pinned release summary", sourceAppBundleId: "com.apple.TextEdit", pinned: true)
            _ = makeImageItem(context: context, data: makePreviewImageData(), sourceAppBundleId: "com.apple.Preview")
            _ = makeFileItem(context: context, paths: "/Users/noma4i/Downloads/Design Spec.pdf", sourceAppBundleId: "com.apple.finder")
            _ = makeTextItem(context: context, text: "Long clipboard entry that demonstrates truncation in history rows", sourceAppBundleId: "com.apple.Notes")
            try? context.save()
            return context
        }

        static func makeTextItem(
            context: NSManagedObjectContext,
            text: String,
            sourceAppBundleId: String?,
            appliedRule: String? = nil,
            pinned: Bool = false
        ) -> ClipboardItem {
            let item = ClipboardItem(context: context)
            item.uuid = UUID()
            item.content = text
            item.contentType = ClipboardItemType.text.rawValue
            item.createdAt = Date()
            item.isPinned = pinned
            item.sourceAppBundleId = sourceAppBundleId
            item.appliedRule = appliedRule
            item.fingerprint = UUID().uuidString
            return item
        }

        static func makeImageItem(context: NSManagedObjectContext, data: Data, sourceAppBundleId: String?) -> ClipboardItem {
            let item = ClipboardItem(context: context)
            item.uuid = UUID()
            item.contentType = ClipboardItemType.image.rawValue
            item.imageData = data
            item.createdAt = Date()
            item.isPinned = false
            item.sourceAppBundleId = sourceAppBundleId
            item.fingerprint = UUID().uuidString
            return item
        }

        static func makeFileItem(context: NSManagedObjectContext, paths: String, sourceAppBundleId: String?, pinned: Bool = false) -> ClipboardItem {
            let item = ClipboardItem(context: context)
            item.uuid = UUID()
            item.content = paths
            item.contentType = ClipboardItemType.file.rawValue
            item.createdAt = Date()
            item.isPinned = pinned
            item.sourceAppBundleId = sourceAppBundleId
            item.fingerprint = UUID().uuidString
            return item
        }

        static func makePreviewImageData(size: NSSize = NSSize(width: 320, height: 180)) -> Data {
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor(calibratedRed: 0.16, green: 0.40, blue: 0.72, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

            let circleRect = NSRect(x: 18, y: 18, width: 90, height: 90)
            NSColor(calibratedRed: 0.93, green: 0.82, blue: 0.38, alpha: 1).setFill()
            NSBezierPath(ovalIn: circleRect).fill()

            let headline = NSAttributedString(
                string: "Preview",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
                    .foregroundColor: NSColor.white,
                ]
            )
            headline.draw(at: NSPoint(x: 128, y: 108))

            let caption = NSAttributedString(
                string: "Sample image fixture",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.85),
                ]
            )
            caption.draw(at: NSPoint(x: 128, y: 76))
            image.unlockFocus()

            return image.tiffRepresentation ?? Data()
        }
    }
#endif
