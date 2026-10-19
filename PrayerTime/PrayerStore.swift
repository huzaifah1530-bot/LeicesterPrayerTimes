import Foundation
import Observation
import PrayerTimeCore
import WidgetKit

@MainActor @Observable
final class PrayerStore {
    let reminders = ReminderSettings()
    private(set) var widgetError: String?
    private(set) var mosques: [Mosque] = []
    private(set) var selected: Mosque?
    private(set) var schedule: MosqueSchedule?
    private(set) var isLoading = false
    private(set) var isLoadingDirectory = false
    private(set) var error: String?
    private(set) var directoryError: String?
    private(set) var cacheError: String?
    private(set) var isSaved = false
    var showMosquePicker = false

    private let client = SalaahClient()
    private let cache = ScheduleCache()
    private var generation = UUID()
    private var loadTask: Task<Void, Never>?
    private var started = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "selectedMosque") {
            selected = try? JSONDecoder().decode(Mosque.self, from: data)
        }
    }

    func start() async {
        guard !started else { return }
        started = true
        await reminders.refreshAuthorization()
        if let selected {
            schedule = await cache.readSchedule(id: selected.id)
            isSaved = schedule != nil
            publishSchedule()
            await refresh()
        }
        await loadDirectory()
    }

    func loadDirectory() async {
        guard !isLoadingDirectory else { return }
        isLoadingDirectory = true
        directoryError = nil
        defer { isLoadingDirectory = false }
        if mosques.isEmpty { mosques = await cache.readDirectory() }
        do {
            let result = try await client.mosques()
            mosques = result
            try await cache.writeDirectory(result)
        } catch is CancellationError { }
        catch { directoryError = error.localizedDescription }
    }

    func select(_ mosque: Mosque) {
        guard selected != mosque else { showMosquePicker = false; return }
        loadTask?.cancel()
        generation = UUID()
        selected = mosque
        schedule = nil
        error = nil
        cacheError = nil
        isSaved = false
        isLoading = false
        UserDefaults.standard.set(try? JSONEncoder().encode(mosque), forKey: "selectedMosque")
        publishSchedule()
        showMosquePicker = false
        let token = generation
        loadTask = Task {
            let cached = await cache.readSchedule(id: mosque.id)
            guard token == generation, !Task.isCancelled else { return }
            schedule = cached
            isSaved = cached != nil
            publishSchedule()
            await refresh()
        }
    }

    func refreshIfNeeded() async {
        await reminders.refreshAuthorization()
        guard selected != nil else { return }
        if let schedule, Date.now.timeIntervalSince(schedule.fetchedAt) < 900,
           UKClock.calendar.isDateInToday(schedule.fetchedAt), schedule.day(on: .now) != nil { return }
        await refresh()
    }

    func refresh() async {
        guard let mosque = selected, !isLoading else { return }
        let token = generation
        isLoading = true
        error = nil
        defer { if token == generation { isLoading = false } }
        do {
            let fresh = try await client.schedule(for: mosque)
            guard token == generation, !Task.isCancelled else { return }
            schedule = fresh
            publishSchedule()
            isSaved = false
            cacheError = nil
            do { try await cache.writeSchedule(fresh) }
            catch { cacheError = "Times loaded, but this device could not save an offline copy." }
        } catch is CancellationError { }
        catch {
            guard token == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
            isSaved = schedule != nil
        }
    }

    private func publishSchedule() {
        reminders.use(schedule)
        guard let selected else { return }
        do {
            try WidgetData.select(selected)
            try WidgetData.save(WidgetSnapshot(mosque: selected, schedule: schedule))
            widgetError = nil
        } catch {
            widgetError = "Automatic mosque sharing is unavailable. Choose your mosque in Edit Widget instead."
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private actor ScheduleCache {
    private var folder: URL {
        URL.applicationSupportDirectory.appending(path: "PrayerTime", directoryHint: .isDirectory)
    }

    func readSchedule(id: Int) -> MosqueSchedule? {
        read(MosqueSchedule.self, name: "mosque-\(id).json")
    }
    func writeSchedule(_ schedule: MosqueSchedule) throws {
        try write(schedule, name: "mosque-\(schedule.mosque.id).json")
    }
    func readDirectory() -> [Mosque] { read([Mosque].self, name: "mosques.json") ?? [] }
    func writeDirectory(_ mosques: [Mosque]) throws { try write(mosques, name: "mosques.json") }

    private func read<T: Decodable>(_ type: T.Type, name: String) -> T? {
        guard let data = try? Data(contentsOf: folder.appending(path: name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private func write<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: folder.appending(path: name), options: .atomic)
    }
}
