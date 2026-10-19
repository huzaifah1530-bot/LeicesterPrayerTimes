import Foundation
import AppIntents
import PrayerTimeCore

struct WidgetMosque: AppEntity {
    let id: Int
    let name: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Mosque" }
    static var defaultQuery: MosqueQuery { MosqueQuery() }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    var mosque: Mosque { Mosque(id: id, name: name) }
    init(_ mosque: Mosque) { id = mosque.id; name = mosque.name }
}

struct MosqueQuery: EntityStringQuery {
    func entities(for identifiers: [Int]) async throws -> [WidgetMosque] {
        let mosques = try await WidgetDirectory.shared.mosques()
        return identifiers.compactMap { id in mosques.first { $0.id == id }.map(WidgetMosque.init) }
    }
    func suggestedEntities() async throws -> [WidgetMosque] {
        try await WidgetDirectory.shared.mosques().map(WidgetMosque.init)
    }
    func entities(matching string: String) async throws -> [WidgetMosque] {
        try await WidgetDirectory.shared.mosques().filter { $0.name.localizedStandardContains(string) }.map(WidgetMosque.init)
    }
    func defaultResult() async -> WidgetMosque? {
        WidgetData.read().map { WidgetMosque($0.mosque) }
    }
}

private actor WidgetDirectory {
    static let shared = WidgetDirectory()
    private var cached: [Mosque] = []
    func mosques() async throws -> [Mosque] {
        if !cached.isEmpty { return cached }
        if let data = try? Data(contentsOf: WidgetLocalCache.directoryURL),
           let mosques = try? JSONDecoder().decode([Mosque].self, from: data), !mosques.isEmpty {
            cached = mosques
            return mosques
        }
        let mosques = try await SalaahClient().mosques()
        cached = mosques
        try? JSONEncoder().encode(mosques).write(to: WidgetLocalCache.directoryURL, options: .atomic)
        return mosques
    }
}

/// Lives in the widget's own container, and works without App Group entitlements.
enum WidgetLocalCache {
    static var directoryURL: URL { URL.cachesDirectory.appending(path: "widget-mosques.json") }
    static func read(_ mosque: Mosque) -> MosqueSchedule? {
        let file = URL.cachesDirectory.appending(path: "widget-mosque-\(mosque.id).json")
        guard let data = try? Data(contentsOf: file), let schedule = try? JSONDecoder().decode(MosqueSchedule.self, from: data),
              schedule.mosque.id == mosque.id else { return nil }
        return schedule
    }
    static func save(_ schedule: MosqueSchedule) {
        let file = URL.cachesDirectory.appending(path: "widget-mosque-\(schedule.mosque.id).json")
        try? JSONEncoder().encode(schedule).write(to: file, options: .atomic)
    }
}
