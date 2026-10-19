import Foundation

public struct WidgetSnapshot: Codable, Sendable {
    public let mosque: Mosque
    public let schedule: MosqueSchedule?
    public init(mosque: Mosque, schedule: MosqueSchedule?) { self.mosque = mosque; self.schedule = schedule }
}

public enum WidgetData {
    public static let groupID = "group.uk.prayertime.app"
    #if os(iOS)
    private static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }
    public static func read() -> WidgetSnapshot? {
        guard let folder,
              let data = try? Data(contentsOf: folder.appending(path: "selected-mosque.json")),
              let mosque = try? JSONDecoder().decode(Mosque.self, from: data) else { return nil }
        let schedule = (try? Data(contentsOf: folder.appending(path: "mosque-\(mosque.id).json")))
            .flatMap { try? JSONDecoder().decode(MosqueSchedule.self, from: $0) }
        return WidgetSnapshot(mosque: mosque, schedule: schedule?.mosque.id == mosque.id ? schedule : nil)
    }
    /// Only the containing app changes selection. Widget refreshes write per-mosque
    /// timetables, so an in-flight refresh can never switch the selected mosque back.
    public static func select(_ mosque: Mosque) throws {
        guard let folder else { throw CocoaError(.fileWriteNoPermission) }
        try JSONEncoder().encode(mosque).write(to: folder.appending(path: "selected-mosque.json"), options: .atomic)
    }
    public static func save(_ snapshot: WidgetSnapshot) throws {
        guard let folder else { throw CocoaError(.fileWriteNoPermission) }
        guard let schedule = snapshot.schedule, schedule.mosque.id == snapshot.mosque.id else { return }
        try JSONEncoder().encode(schedule).write(to: folder.appending(path: "mosque-\(snapshot.mosque.id).json"), options: .atomic)
    }
    #endif
}
