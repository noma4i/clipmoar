import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    private lazy var managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "ClipboardItem"
        entity.managedObjectClassName = "ClipboardItem"

        let uuid = NSAttributeDescription()
        uuid.name = "uuid"
        uuid.attributeType = .UUIDAttributeType
        uuid.isOptional = true

        let content = NSAttributeDescription()
        content.name = "content"
        content.attributeType = .stringAttributeType
        content.isOptional = true

        let contentType = NSAttributeDescription()
        contentType.name = "contentType"
        contentType.attributeType = .stringAttributeType
        contentType.isOptional = true
        contentType.defaultValue = "text"

        let imageData = NSAttributeDescription()
        imageData.name = "imageData"
        imageData.attributeType = .binaryDataAttributeType
        imageData.isOptional = true
        imageData.allowsExternalBinaryDataStorage = true

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = true

        let isPinned = NSAttributeDescription()
        isPinned.name = "isPinned"
        isPinned.attributeType = .booleanAttributeType
        isPinned.isOptional = true
        isPinned.defaultValue = false

        let sourceAppBundleId = NSAttributeDescription()
        sourceAppBundleId.name = "sourceAppBundleId"
        sourceAppBundleId.attributeType = .stringAttributeType
        sourceAppBundleId.isOptional = true

        entity.properties = [uuid, content, contentType, imageData, createdAt, isPinned, sourceAppBundleId]
        model.entities = [entity]

        return model
    }()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ClipMoar", managedObjectModel: managedObjectModel)
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        try? context.save()
    }
}
