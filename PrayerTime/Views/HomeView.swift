import SwiftUI
import PrayerTimeCore

struct HomeView: View {
    @Environment(PrayerStore.self) private var store
    @State private var mode: TimeMode = .jamaat

    var body: some View {
        Group {
            if let mosque = store.selected {
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    content(mosque: mosque, now: timeline.date)
                }
            } else {
                ContentUnavailableView {
                    Label("Your mosque. Your times.", systemImage: "building.2")
                } description: {
                    Text("Choose your Leicester mosque to see its prayer timetable and Jummah times.")
                } actions: {
                    Button("Choose a mosque", systemImage: "plus") { store.showMosquePicker = true }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("onboarding-choose-mosque")
                }
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Change mosque", systemImage: "building.2") { store.showMosquePicker = true }
                    Button("Refresh times", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                        .disabled(store.selected == nil || store.isLoading)
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Timetable options")
            }
        }
        .task {
            // Refresh at UK midnight even if the app stays open overnight.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
                await store.refreshIfNeeded()
            }
        }
    }

    private func content(mosque: Mosque, now: Date) -> some View {
        List {
            Section {
                NavigationLink { MosqueDetailView(mosque: mosque) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.largeTitle).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mosque.name).font(.headline)
                            Text("Leicester · United Kingdom").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
            }

            if let schedule = store.schedule {
                Section {
                    if let next = schedule.nextJamaat(after: now), schedule.day(on: now) != nil {
                        NextPrayerView(next: next, now: now)
                    } else {
                        Label("No upcoming jamaat available", systemImage: "clock.badge.questionmark")
                            .foregroundStyle(.secondary)
                    }
                } header: { Text(UKClock.dayLabel(now)) }

                if store.isSaved || store.error != nil || store.cacheError != nil {
                    Section {
                        StatusRow(symbol: "wifi.exclamationmark", title: store.isSaved ? "Showing saved times" : "Refresh unavailable",
                                  message: store.error ?? store.cacheError ?? "Pull down to check for updates.")
                        Button("Try again", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                            .disabled(store.isLoading)
                    }
                }

                if let day = schedule.day(on: now) {
                    Section {
                        Picker("Times", selection: $mode) {
                            ForEach(TimeMode.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).listRowSeparator(.hidden)

                        ForEach(mode == .jamaat ? Prayer.daily : Prayer.allCases) { prayer in
                            let time = mode == .jamaat ? day.jamaat[prayer] : day.beginning[prayer]
                            NavigationLink {
                                PrayerDetailView(prayer: prayer, day: day)
                            } label: {
                                HStack {
                                    Label(prayer.title, systemImage: prayer.symbol)
                                        .labelStyle(PrayerLabelStyle())
                                    Spacer()
                                    Text(time?.description ?? "—").monospacedDigit()
                                        .foregroundStyle(time == nil ? .secondary : .primary)
                                }.padding(.vertical, 5)
                            }
                        }
                    } header: { Text("Today's prayers") } footer: {
                        Text(mode == .jamaat ? "Jamaat is the congregation time at your mosque." : "Beginning times are published by your mosque. A dash means no time was supplied. Maghrib appears only when a separate beginning time is published.")
                    }
                } else {
                    Section {
                        StatusRow(symbol: "calendar.badge.exclamationmark", title: "Today's times aren't available",
                                  message: "The saved timetable does not cover today. Refresh or check your mosque's source.")
                    }
                }

                Section {
                    NavigationLink { JummahView() } label: { Label("Jummah", systemImage: "person.3") }
                        .accessibilityIdentifier("jummah")
                    NavigationLink { MonthlyTimetableView() } label: { Label("Monthly timetable", systemImage: "calendar") }
                        .accessibilityIdentifier("monthly-timetable")
                }
                Section {
                    HStack {
                        Label(store.isLoading ? "Updating…" : "Updated", systemImage: "arrow.clockwise")
                        Spacer()
                        Text(schedule.fetchedAt, style: .relative)
                    }.font(.footnote).foregroundStyle(.secondary)
                    Link("View on Salaah Times", destination: mosque.sourceURL).font(.footnote)
                } footer: { Text("All times are in Europe/London and use the 24-hour clock.") }
            } else if store.isLoading {
                Section { HStack { ProgressView(); Text("Loading your mosque's times…").foregroundStyle(.secondary) } }
            } else {
                Section {
                    StatusRow(symbol: "wifi.exclamationmark", title: "Couldn't load prayer times", message: store.error ?? "Pull down to try again.")
                    Button("Try again") { Task { await store.refresh() } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.refresh() }
    }
}

enum TimeMode: String, CaseIterable, Identifiable {
    case jamaat, beginning
    var id: String { rawValue }
    var title: String { self == .jamaat ? "Jamaat" : "Beginning" }
}

private struct NextPrayerView: View {
    let next: NextJamaat
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("NEXT JAMAAT", systemImage: next.prayer.symbol)
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(next.prayer.title).font(.largeTitle.bold())
                    Spacer(minLength: 24)
                    time.font(.largeTitle.weight(.medium))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(next.prayer.title).font(.title.bold())
                    time.font(.title)
                }
            }
            HStack {
                if !UKClock.calendar.isDate(next.date, inSameDayAs: now) { Text("Tomorrow ·") }
                Text("in \(remaining)")
            }.font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("next-prayer")
    }

    private var time: some View {
        Text(UKClock.timeLabel(next.date))
            .monospacedDigit().foregroundStyle(.tint)
    }
    private var remaining: String {
        let minutes = max(1, Int(ceil(next.date.timeIntervalSince(now) / 60)))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

struct PrayerLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon.foregroundStyle(.tint).frame(width: 25)
            configuration.title
        }
    }
}

struct StatusRow: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
