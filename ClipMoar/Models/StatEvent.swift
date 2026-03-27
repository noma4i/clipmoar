import CoreData

@objc(StatEvent)
final class StatEvent: NSManagedObject {
    @NSManaged var kind: String
    @NSManaged var date: Date
}

enum StatEventKind: String {
    case launch
    case panelOpen
    case paste
    case search
    case copy
}

final class StatsService {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func record(_ kind: StatEventKind) {
        guard let entity = NSEntityDescription.entity(forEntityName: "StatEvent", in: context) else {
            NSLog("[ClipMoar] StatEvent entity not found in Core Data model")
            return
        }
        let event = StatEvent(entity: entity, insertInto: context)
        event.kind = kind.rawValue
        event.date = Date()
        do {
            try context.save()
        } catch {
            NSLog("[ClipMoar] Failed to save stat event: %@", error.localizedDescription)
        }
    }

    func totalCount(for kind: StatEventKind) -> Int {
        let request = NSFetchRequest<StatEvent>(entityName: "StatEvent")
        request.predicate = NSPredicate(format: "kind == %@", kind.rawValue)
        return (try? context.count(for: request)) ?? 0
    }

    func firstEventDate() -> Date? {
        let request = NSFetchRequest<StatEvent>(entityName: "StatEvent")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first?.date
    }

    func dailyCounts(for kind: StatEventKind, days: Int = 14) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let request = NSFetchRequest<StatEvent>(entityName: "StatEvent")
        request.predicate = NSPredicate(format: "kind == %@ AND date >= %@", kind.rawValue, startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        guard let events = try? context.fetch(request) else { return [] }

        var buckets: [Date: Int] = [:]
        for i in 0 ..< days {
            if let d = calendar.date(byAdding: .day, value: i, to: startDate) {
                buckets[calendar.startOfDay(for: d)] = 0
            }
        }
        for event in events {
            let day = calendar.startOfDay(for: event.date)
            buckets[day, default: 0] += 1
        }

        return buckets.sorted { $0.key < $1.key }.map { (date: $0.key, count: $0.value) }
    }

    func resetAll() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "StatEvent")
        let batch = NSBatchDeleteRequest(fetchRequest: request)
        _ = try? context.execute(batch)
        try? context.save()
    }
}
