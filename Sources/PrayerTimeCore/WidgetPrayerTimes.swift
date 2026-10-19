import Foundation

public struct WidgetPrayerTime: Identifiable, Sendable {
    public let id: String
    public let slot: Prayer
    public let title: String
    public let symbol: String
    public let time: ClockTime?
    public let detail: String
}

public struct WidgetPrayerEvent: Sendable {
    public let row: WidgetPrayerTime
    public let date: Date
}

extension MosqueSchedule {
    /// Friday affects the congregation display, not the Dhuhr beginning window.
    public func widgetRows(for day: PrayerDay, jamaat: Bool) -> [WidgetPrayerTime] {
        var rows: [WidgetPrayerTime] = []
        let friday = UKClock.calendar.component(.weekday, from: day.date) == 6
        for prayer in Prayer.daily {
            if jamaat && friday && prayer == .dhuhr {
                rows.append(contentsOf: jummahWidgetRows())
            } else {
                let time = jamaat ? day.jamaat[prayer] : day.effectiveBeginning[prayer]
                let fallback = !jamaat && prayer == .maghrib && day.usesMaghribJamaatForBeginning
                rows.append(WidgetPrayerTime(id: prayer.rawValue, slot: prayer, title: prayer.title,
                                            symbol: prayer.symbol, time: time, detail: fallback ? "Uses jamaat" : ""))
            }
        }
        return rows
    }

    public func nextWidgetPrayer(after now: Date, jamaat: Bool) -> WidgetPrayerEvent? {
        var next: WidgetPrayerEvent?
        for day in days {
            for row in widgetRows(for: day, jamaat: jamaat) {
                guard let date = row.time?.on(day.date), date > now else { continue }
                if let current = next, current.date <= date { continue }
                next = WidgetPrayerEvent(row: row, date: date)
            }
        }
        return next
    }

    private func jummahWidgetRows() -> [WidgetPrayerTime] {
        var services: [(String, [JummahEntry])] = []
        var name = "Jummah"
        var stages: [JummahEntry] = []
        for entry in jummah {
            if entry.value.isEmpty {
                if !stages.isEmpty { services.append((name, stages)); stages = [] }
                name = entry.label
            } else { stages.append(entry) }
        }
        if !stages.isEmpty { services.append((name, stages)) }
        guard !services.isEmpty else {
            return [WidgetPrayerTime(id: "jummah", slot: .dhuhr, title: "Jummah", symbol: "person.3", time: nil, detail: "Not published")]
        }
        return services.enumerated().map { index, service in
            let timed = service.1.filter { ClockTime($0.value) != nil }
            let chosen = timed.min { priority($0.label) < priority($1.label) }
            let title = services.count > 1 ? "Jummah \(index + 1)" : "Jummah"
            return WidgetPrayerTime(id: "jummah-\(index)", slot: .dhuhr, title: title, symbol: "person.3",
                                    time: chosen.flatMap { ClockTime($0.value) }, detail: chosen?.label ?? "Not published")
        }
    }

    private func priority(_ label: String) -> Int {
        let label = label.lowercased()
        if label.contains("jamaat") || label.contains("salaah") || label.contains("salah") || label == "prayer" || label == "jummah" { return 0 }
        if label.contains("khut") { return 1 }
        if label.contains("azaan") || label.contains("adhan") { return 2 }
        if label.contains("bayaan") || label.contains("bayan") { return 3 }
        return 4
    }
}
