import SwiftUI
import WidgetKit
import AppIntents
import PrayerTimeCore

enum WidgetTimes: String, AppEnum {
    case jamaat, beginning
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Prayer times" }
    static var caseDisplayRepresentations: [WidgetTimes: DisplayRepresentation] {
        [.jamaat: "Jamaat", .beginning: "Beginning"]
    }
}

struct PrayerWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Prayer Time" }
    static var description: IntentDescription { "Show beginning or jamaat times for your selected mosque." }
    @Parameter(title: "Times", default: .jamaat) var times: WidgetTimes
    @Parameter(title: "Mosque") var mosque: WidgetMosque?
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let times: WidgetTimes
    var schedule: MosqueSchedule? { snapshot?.schedule }
    var next: WidgetPrayerEvent? {
        guard let schedule, schedule.day(on: date) != nil else { return nil }
        return schedule.nextWidgetPrayer(after: date, jamaat: times == .jamaat)
    }
    var rows: [WidgetPrayerTime] {
        guard let schedule, let day = schedule.day(on: date) else { return [] }
        return schedule.widgetRows(for: day, jamaat: times == .jamaat)
    }
}

struct PrayerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry { PrayerEntry(date: .now, snapshot: nil, times: .jamaat) }

    func snapshot(for configuration: PrayerWidgetConfiguration, in context: Context) async -> PrayerEntry {
        let snapshot = await loadSnapshot(configuration)
        return PrayerEntry(date: .now, snapshot: snapshot, times: configuration.times)
    }

    private func loadSnapshot(_ configuration: PrayerWidgetConfiguration) async -> WidgetSnapshot? {
        var snapshot = selectedSnapshot(configuration)
        let needsRefresh = snapshot?.schedule.map { Date.now.timeIntervalSince($0.fetchedAt) > 1800 || $0.day(on: .now) == nil } ?? true
        if let current = snapshot, needsRefresh {
            if let fresh = try? await SalaahClient().schedule(for: current.mosque) {
                let updated = WidgetSnapshot(mosque: current.mosque, schedule: fresh)
                WidgetLocalCache.save(fresh)
                if WidgetData.read()?.mosque.id == current.mosque.id { try? WidgetData.save(updated) }
                snapshot = updated
            }
        }
        // Re-read so a mosque changed while networking never gets replaced by old data.
        if configuration.mosque == nil {
            if let shared = WidgetData.read(), shared.mosque.id != snapshot?.mosque.id { snapshot = shared }
        }
        return snapshot
    }

    func timeline(for configuration: PrayerWidgetConfiguration, in context: Context) async -> Timeline<PrayerEntry> {
        let snapshot = await loadSnapshot(configuration)
        let now = Date.now
        let horizon = now.addingTimeInterval(86_400)
        var dates = [now]
        if let schedule = snapshot?.schedule {
            for day in schedule.days {
                for row in schedule.widgetRows(for: day, jamaat: configuration.times == .jamaat) {
                    if let date = row.time?.on(day.date), date > now, date < horizon {
                        dates.append(date.addingTimeInterval(1))
                    }
                }
            }
        }
        if let midnight = UKClock.calendar.date(byAdding: .day, value: 1, to: UKClock.calendar.startOfDay(for: now)) {
            dates.append(midnight)
        }
        let entries = Set(dates).sorted().map { PrayerEntry(date: $0, snapshot: snapshot, times: configuration.times) }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(1800)))
    }

    private func selectedSnapshot(_ configuration: PrayerWidgetConfiguration) -> WidgetSnapshot? {
        if let mosque = configuration.mosque?.mosque {
            let shared = WidgetData.read()
            let local = WidgetLocalCache.read(mosque)
            let schedule = [shared?.schedule, local].compactMap { $0 }
                .filter { $0.mosque.id == mosque.id }.max { $0.fetchedAt < $1.fetchedAt }
            return WidgetSnapshot(mosque: mosque, schedule: schedule)
        }
        return WidgetData.read()
    }
}

struct PrayerWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let next = entry.next {
                    Label("\(next.row.title) \(next.row.detail) \(UKClock.timeLabel(next.date))", systemImage: next.row.symbol)
                } else { Text("Edit widget to choose mosque") }
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: entry.next?.row.symbol ?? "building.2")
                    Text(entry.next?.row.title ?? "Edit widget").font(.caption2)
                    if let next = entry.next { Text(UKClock.timeLabel(next.date)).font(.caption2).monospacedDigit() }
                    if let next = entry.next, !next.row.detail.isEmpty { Text(next.row.detail).font(.system(size: 8)) }
                }.minimumScaleFactor(0.7)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 3) {
                    if let next = entry.next {
                        Label("\(next.row.title) · \(UKClock.timeLabel(next.date))", systemImage: next.row.symbol).font(.headline)
                        Text(entry.snapshot?.mosque.name ?? "Prayer Time").font(.caption).lineLimit(1)
                        Text(next.row.detail.isEmpty ? (entry.times == .jamaat ? "Jamaat" : "Beginning") : next.row.detail).font(.caption2)
                    } else {
                        Label("Prayer Time", systemImage: "building.2")
                        Text(entry.snapshot == nil ? "Edit widget to choose mosque" : "Tap to refresh times").font(.caption)
                    }
                }
            default:
                homeScreen
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "prayertime://home"))
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(entry.snapshot?.mosque.name ?? "Prayer Time", systemImage: "building.2")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            if let next = entry.next {
                if family == .systemSmall {
                    nextLabel(next)
                    Text(UKClock.timeLabel(next.date)).font(.largeTitle.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.7)
                } else {
                    HStack {
                        nextLabel(next)
                        Spacer()
                        Text(UKClock.timeLabel(next.date)).font(.title.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.7)
                    }
                }
                if family == .systemSmall {
                    Text(next.date, style: .relative).font(.caption).foregroundStyle(.secondary)
                } else if !entry.rows.isEmpty {
                    if family == .systemLarge {
                        Divider()
                        ForEach(entry.rows) { row in prayerRow(row) }
                    } else {
                        HStack {
                            ForEach(Prayer.daily) { prayer in
                                compactColumn(prayer)
                            }
                        }
                    }
                }
            } else {
                Spacer(minLength: 0)
                Image(systemName: "clock.badge.questionmark").font(.title2)
                Text(entry.snapshot == nil ? "Choose your mosque" : "Refresh prayer times").font(.headline)
                Text(entry.snapshot == nil ? "Touch and hold → Edit Widget → Mosque" : "Open Prayer Time to check your connection").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func nextLabel(_ next: WidgetPrayerEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(next.row.detail.isEmpty ? "NEXT \(entry.times == .jamaat ? "JAMAAT" : "BEGINNING")" : "NEXT · \(next.row.detail.uppercased())")
                .font(.caption2).foregroundStyle(.secondary)
            Label(next.row.title, systemImage: next.row.symbol).font(.headline).widgetAccentable()
        }
    }

    private func compactColumn(_ prayer: Prayer) -> some View {
        let rows = entry.rows.filter { $0.slot == prayer }
        let isJummah = rows.first?.id.hasPrefix("jummah") == true
        let details = Set(rows.map(\.detail))
        return VStack(alignment: .leading, spacing: 2) {
            Text(isJummah ? "Jummah" : prayer.title).font(.caption2).foregroundStyle(.secondary)
            ForEach(rows) { row in
                Text(row.time?.description ?? "—").font(.caption.weight(.medium)).monospacedDigit()
                    .accessibilityLabel("\(row.title), \(row.detail), \(row.time?.description ?? "not published")")
                if isJummah && details.count > 1 { Text(row.detail).font(.caption2).foregroundStyle(.secondary) }
            }
            if let detail = rows.first?.detail, !detail.isEmpty, details.count == 1 {
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func prayerRow(_ row: WidgetPrayerTime) -> some View {
        HStack {
            Label(row.title, systemImage: row.symbol).font(.subheadline)
            Spacer()
            if !row.detail.isEmpty { Text(row.detail).font(.caption2).foregroundStyle(.secondary) }
            Text(row.time?.description ?? "—").font(.subheadline.weight(.medium)).monospacedDigit()
        }
    }
}

@main
struct PrayerTimeWidgets: Widget {
    let kind = "PrayerTimeWidgets"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PrayerWidgetConfiguration.self, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer Time")
        .description("The next prayer and your selected mosque's published times.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
