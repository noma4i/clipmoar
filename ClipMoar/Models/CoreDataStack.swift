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

        let fingerprint = NSAttributeDescription()
        fingerprint.name = "fingerprint"
        fingerprint.attributeType = .stringAttributeType
        fingerprint.isOptional = true

        let appliedRule = NSAttributeDescription()
        appliedRule.name = "appliedRule"
        appliedRule.attributeType = .stringAttributeType
        appliedRule.isOptional = true

        entity.properties = [uuid, content, contentType, imageData, createdAt, isPinned, sourceAppBundleId, fingerprint, appliedRule]

        let statEntity = NSEntityDescription()
        statEntity.name = "StatEvent"
        statEntity.managedObjectClassName = "StatEvent"

        let statKind = NSAttributeDescription()
        statKind.name = "kind"
        statKind.attributeType = .stringAttributeType
        statKind.isOptional = true
        statKind.defaultValue = ""

        let statDate = NSAttributeDescription()
        statDate.name = "date"
        statDate.attributeType = .dateAttributeType
        statDate.isOptional = true

        statEntity.properties = [statKind, statDate]

        model.entities = [entity, statEntity]

        return model
    }()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ClipMoar", managedObjectModel: managedObjectModel)
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        container.loadPersistentStores { _, error in
            if let error = error {
                NSLog("CoreData failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func save() throws {
        let context = viewContext
        guard context.hasChanges else { return }
        try context.save()
    }

    func saveIfNeeded() {
        do {
            try save()
        } catch {
            NSLog("CoreData save failed: \(error)")
        }
    }
}
