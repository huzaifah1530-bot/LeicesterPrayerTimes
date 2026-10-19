import Foundation

public struct WidgetSnapshot: Codable, Sendable {
    public let mosque: Mosque
    public let schedule: MosqueSchedule?
    public init(mosque: Mosque, schedule: MosqueSchedule?) { self.mosque = mosque; self.schedule = schedule }
}

public enum WidgetData {
    public static let groupID = "group.uk.prayertime.app"
    #if os(iOS)
    private static var file: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appending(path: "widget-timetable.json")
    }
    public static func read() -> WidgetSnapshot? {
        guard let file, let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
    public static func save(_ snapshot: WidgetSnapshot) throws {
        guard let file else { throw CocoaError(.fileWriteNoPermission) }
        try JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
    }
    #endif
}
