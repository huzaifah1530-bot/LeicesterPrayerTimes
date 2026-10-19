import SwiftUI
import PrayerTimeCore

struct SettingsView: View {
    @Environment(PrayerStore.self) private var store

    var body: some View {
        List {
            Section("Your mosque") {
                NavigationLink { MosquePickerView() } label: {
                    LabeledContent {
                        Text(store.selected?.name ?? "Choose a mosque").foregroundStyle(.secondary)
                    } label: { Label("Mosque", systemImage: "building.2") }
                }
                if let mosque = store.selected {
                    NavigationLink { MosqueDetailView(mosque: mosque) } label: {
                        Label("Mosque details", systemImage: "info.circle")
                    }
                }
            }
            Section("Preferences") {
                NavigationLink { AppearanceView() } label: { Label("Appearance", systemImage: "paintpalette") }
            }
            Section("About") {
                NavigationLink { DataInformationView() } label: { Label("Prayer time data", systemImage: "clock.badge.checkmark") }
                NavigationLink { AboutView() } label: { Label("About Prayer Time", systemImage: "info.circle") }
            }
        }
        .navigationTitle("Settings")
    }
}

struct MosquePickerView: View {
    var isSheet = false
    @Environment(PrayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [Mosque] {
        search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? store.mosques : store.mosques.filter {
            $0.name.localizedStandardContains(search)
        }
    }

    var body: some View {
        List {
            if let error = store.directoryError {
                Section {
                    StatusRow(symbol: "wifi.exclamationmark", title: store.mosques.isEmpty ? "Couldn't load mosques" : "Showing saved mosque list", message: error)
                    Button("Try again") { Task { await store.loadDirectory() } }.disabled(store.isLoadingDirectory)
                }
            }
            Section {
                ForEach(filtered) { mosque in
                    Button {
                        store.select(mosque)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Text(mosque.name).foregroundStyle(.primary)
                            Spacer()
                            if store.selected?.id == mosque.id {
                                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint)
                            }
                        }.padding(.vertical, 5).contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(store.selected?.id == mosque.id ? [.isSelected] : [])
                }
            } header: { Text("Leicester") } footer: {
                if !filtered.isEmpty { Text("\(filtered.count) mosques · Salaah Times Leicester") }
            }
        }
        .overlay {
            if store.mosques.isEmpty && store.isLoadingDirectory {
                ProgressView("Loading mosques…")
            } else if filtered.isEmpty && !store.mosques.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .navigationTitle("Choose a mosque")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search mosques")
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
        }
        .refreshable { await store.loadDirectory() }
        .task { if store.mosques.isEmpty { await store.loadDirectory() } }
    }
}

struct AppearanceView: View {
    @AppStorage("appearance") private var appearance = "system"
    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    Label("Automatic", systemImage: "circle.lefthalf.filled").tag("system")
                    Label("Light", systemImage: "sun.max").tag("light")
                    Label("Dark", systemImage: "moon").tag("dark")
                }.pickerStyle(.inline).labelsHidden()
            } footer: { Text("Automatic follows your iPhone or iPad's appearance. Text size, contrast and glass effects follow your system accessibility settings.") }
        }.navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline)
    }
}

struct DataInformationView: View {
    var body: some View {
        List {
            Section("Source") {
                Text("Prayer Time reads the public mosque directory and mosque-specific timetables on Salaah Times Leicester.")
                Link("Open Salaah Times", destination: URL(string: "https://www.salaahtimes.co.uk/Timetable/TodaysTimes")!)
            }
            Section("Understanding your times") {
                explanation("Jamaat", "The published congregation time at your selected mosque.")
                explanation("Beginning", "The start of the prayer period, as published by your mosque. Dawn is also labelled Sehri End on the source.")
                explanation("Dhuhr & Isha", "The source uses the spellings Zohar and Eisha. These are shown as Dhuhr and Isha in the app.")
                explanation("Shafi times", "Shown separately when your mosque publishes them. The app does not calculate or substitute times.")
                explanation("Jummah", "Bayaan, Azaan and Khutba are separate stages, shown with the labels and values published by your mosque.")
            }
            Section("Updates & offline access") {
                Text("Times refresh when you open the app, return to it, or pull down on Home. The app checks again after 15 minutes while open. Your last successful timetable stays on this device for offline access.")
                Text("A dash means that the mosque has not published a time. If today's date is outside the saved timetable, the app asks you to refresh. It never reuses another day's times.")
            }
            Section("Time zone") { Text("All dates and times follow Europe/London, including British Summer Time. Times use the 24-hour clock wherever you travel.") }
            Section("Privacy") { Text("Your selected mosque and saved timetable are stored on your device. No account, location access or analytics are used. Requests to the source website expose the usual network information, including your IP address, to that website.") }
        }.navigationTitle("Prayer time data").navigationBarTitleDisplayMode(.inline)
    }

    private func explanation(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }.padding(.vertical, 3)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image("MosqueMark").resizable().scaledToFit().frame(width: 64, height: 64).accessibilityHidden(true)
                    Text("Prayer Time").font(.title2.bold())
                    Text("A little closer to your mosque.").font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
            }
            Section {
                Link("Project on GitHub", destination: URL(string: "https://github.com/huzaifah1530-bot/LeicesterPrayerTimes")!)
                Link("Timetables by Salaah Times Leicester", destination: URL(string: "https://www.salaahtimes.co.uk")!)
            } footer: { Text("An independent app. Not affiliated with Salaah Times Leicester or the listed mosques.") }
            Section("Open source") {
                Text("HTML parsing uses SwiftSoup, © 2016–2025 Nicola D'Elia, distributed under the MIT License.")
                NavigationLink("Third-party licence") { LicenceView() }
            }
        }.navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenceView: View {
    var body: some View {
        ScrollView {
            Text(licence)
                .font(.footnote).textSelection(.enabled).padding()
        }.navigationTitle("SwiftSoup licence").navigationBarTitleDisplayMode(.inline)
    }
    private var licence: String {
        guard let url = Bundle.main.url(forResource: "SwiftSoup-LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "SwiftSoup — MIT License. See the repository for the full licence." }
        return text
    }
}
