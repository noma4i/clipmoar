import Foundation

struct TransformPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var transformTypes: [ClipboardTransformType]
    var isBuiltIn: Bool

    init(name: String, description: String, transformTypes: [ClipboardTransformType], isBuiltIn: Bool = false) {
        id = UUID()
        self.name = name
        self.description = description
        self.transformTypes = transformTypes
        self.isBuiltIn = isBuiltIn
    }
}
