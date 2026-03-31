import Foundation

struct TransformPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var icon: String
    var transformTypes: [ClipboardTransformType]
    var isBuiltIn: Bool
    var isQuick: Bool

    init(name: String, description: String, icon: String = "tray.2", transformTypes: [ClipboardTransformType], isBuiltIn: Bool = false, isQuick: Bool = true) {
        id = UUID()
        self.name = name
        self.description = description
        self.icon = icon
        self.transformTypes = transformTypes
        self.isBuiltIn = isBuiltIn
        self.isQuick = isQuick
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "tray.2"
        transformTypes = try container.decode([ClipboardTransformType].self, forKey: .transformTypes)
        isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
        isQuick = try container.decodeIfPresent(Bool.self, forKey: .isQuick) ?? true
    }
}
