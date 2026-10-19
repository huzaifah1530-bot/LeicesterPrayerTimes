import SwiftUI
import PrayerTimeCore

struct PrayerDetailView: View {
    let prayer: Prayer
    let day: PrayerDay
    var body: some View {
        List {
            Section(UKClock.dayLabel(day.date)) {
                LabeledContent("Beginning", value: day.effectiveBeginning[prayer]?.description ?? "Not published")
                if prayer == .maghrib && day.usesMaghribJamaatForBeginning {
                    Text("Uses the published jamaat time because no separate Maghrib beginning time is available.").font(.footnote).foregroundStyle(.secondary)
                }
                if Prayer.daily.contains(prayer) {
                    LabeledContent("Jamaat", value: day.jamaat[prayer]?.description ?? "Not published")
                }
            }
            if prayer == .asr || prayer == .isha {
                let alternative: Prayer = prayer == .asr ? .asrShafi : .ishaShafi
                Section("Shafi beginning time") {
                    LabeledContent(alternative.title, value: day.beginning[alternative]?.description ?? "Not published")
                }
            }
            Section {
                Text(prayer == .sunrise ? "Sunrise marks the end of the Fajr prayer period." : "Beginning is the start of the prayer period. Jamaat is when the congregation prays at your mosque.")
                    .foregroundStyle(.secondary)
            } footer: { Text("Published mosque times · Europe/London") }
        }.navigationTitle(prayer.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct JummahView: View {
    @Environment(PrayerStore.self) private var store
    var body: some View {
        List {
            if let schedule = store.schedule {
                Section {
                    Text(schedule.mosque.name).font(.headline)
                    Text("Friday congregation").foregroundStyle(.secondary)
                }
                if schedule.jummah.isEmpty {
                    Section {
                        StatusRow(symbol: "person.3", title: "No Jummah times published", message: "Check with your mosque for its Friday programme.")
                    }
                } else {
                    Section("Published programme") {
                        ForEach(schedule.jummah) { entry in
                            if entry.value.isEmpty {
                                Text(entry.label).font(.headline).padding(.top, 4)
                                    .accessibilityAddTraits(.isHeader)
                            } else {
                                LabeledContent(entry.label, value: entry.value).monospacedDigit()
                            }
                        }
                    }
                }
                Section {
                    Link("Check mosque source", destination: schedule.mosque.sourceURL)
                    Text("Retrieved \(UKClock.timestampLabel(schedule.fetchedAt))")
                        .font(.footnote).foregroundStyle(.secondary)
                } footer: {
                    Text("Shown exactly as published, including multiple services where available. Programmes can change; check your mosque's latest announcement. All programme times are UK local time.")
                }
            }
        }.navigationTitle("Jummah").navigationBarTitleDisplayMode(.inline)
    }
}

struct MonthlyTimetableView: View {
    @Environment(PrayerStore.self) private var store
    @State private var mode: TimeMode = .jamaat
    @State private var selectedDate = Date.now

    var body: some View {
        List {
            if let schedule = store.schedule, let first = schedule.days.first, let last = schedule.days.last {
                let range = first.date...last.date
                let date = min(max(UKClock.calendar.startOfDay(for: selectedDate), range.lowerBound), range.upperBound)
                Section {
                    DatePicker("Choose a day", selection: Binding(get: { date }, set: { selectedDate = $0 }),
                               in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, UKClock.calendar)
                        .environment(\.timeZone, UKClock.timeZone)
                        .labelsHidden()
                } header: { Text(schedule.mosque.name) }

            Section {
                Picker("Times", selection: $mode) {
                    ForEach(TimeMode.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            } footer: { Text("Choose a day to see all its published times. Dates follow Europe/London.") }

            if let day = schedule.day(on: date) {
              Section(UKClock.dayLabel(day.date)) {
                ForEach(mode == .jamaat ? Prayer.daily : Prayer.allCases) { prayer in
                    let times = mode == .jamaat ? day.jamaat : day.effectiveBeginning
                    LabeledContent {
                        Text(times[prayer]?.description ?? "—").monospacedDigit()
                    } label: { Label(prayer.title, systemImage: prayer.symbol).labelStyle(PrayerLabelStyle()) }
                }
              }
            } else {
                Section { Text("No times were published for this day.").foregroundStyle(.secondary) }
            }
          }
        }.navigationTitle("Monthly timetable").navigationBarTitleDisplayMode(.inline)
    }
}

struct MosqueDetailView: View {
    let mosque: Mosque
    @Environment(PrayerStore.self) private var store
    private var schedule: MosqueSchedule? { store.schedule?.mosque.id == mosque.id ? store.schedule : nil }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.tint).accessibilityHidden(true)
                    Text(mosque.name).font(.title2.bold())
                    Text("Leicester, United Kingdom").foregroundStyle(.secondary)
                }.padding(.vertical, 10)
            }
            if let schedule, !schedule.address.isEmpty {
                Section("Address") {
                    Text(schedule.address).textSelection(.enabled)
                    if let url = URL(string: "https://maps.apple.com/?q=\((mosque.name + ", " + schedule.address).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Leicester")") {
                        Link(destination: url) { Label("Open in Maps", systemImage: "map") }
                    }
                }
            }
            if let schedule, !schedule.notes.isEmpty {
                Section("Mosque notes") { Text(schedule.notes) }
            }
            Section {
                Link(destination: mosque.sourceURL) { Label("Mosque on Salaah Times", systemImage: "safari") }
                Button("Choose another mosque", systemImage: "building.2") { store.showMosquePicker = true }
            }
        }.navigationTitle("Your mosque").navigationBarTitleDisplayMode(.inline)
    }
}
