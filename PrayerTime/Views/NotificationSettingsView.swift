import SwiftUI
import UIKit
import PrayerTimeCore

struct NotificationSettingsView: View {
    @Environment(PrayerStore.self) private var store
    @Environment(\.scenePhase) private var phase
    private var reminders: ReminderSettings { store.reminders }

    var body: some View {
        List {
            Section {
                if reminders.isAuthorized {
                    Label("Notifications allowed", systemImage: "bell.badge")
                } else if reminders.authorization == .denied {
                    Button("Open notification settings", systemImage: "arrow.up.forward.app") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } else {
                    Button("Allow notifications", systemImage: "bell") { Task { await reminders.requestPermission() } }
                }
            } footer: { Text("Set beginning and jamaat reminders separately for each prayer. Delivery follows your iPhone's notification and Focus settings.") }

            Section("Your prayers") {
                ForEach(Prayer.daily) { prayer in
                    NavigationLink { PrayerReminderView(prayer: prayer) } label: {
                        LabeledContent {
                            Text(summary(prayer)).foregroundStyle(.secondary)
                        } label: { Label(prayer.title, systemImage: prayer.symbol).labelStyle(PrayerLabelStyle()) }
                    }
                }
            }
            Section("Scheduled reminders") {
                LabeledContent("Upcoming", value: "\(reminders.pendingCount)")
                if let date = reminders.scheduledThrough {
                    LabeledContent("Scheduled through", value: UKClock.timestampLabel(date))
                }
                if store.selected == nil {
                    Text("Choose a mosque to schedule reminders.").foregroundStyle(.secondary)
                } else if reminders.isAuthorized && reminders.rules.contains(where: \.enabled) && reminders.pendingCount == 0 {
                    Text("No upcoming published times match your reminders. Refresh your mosque's timetable.").foregroundStyle(.secondary)
                }
                if let error = reminders.error { Text(error).foregroundStyle(.secondary) }
            } footer: {
                Text("iOS limits pending reminders. The nearest 63 are scheduled, using your mosque's published times. Open the app regularly to refill them and load each new month's timetable. Missing times never generate reminders.")
            }
        }
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .task { await reminders.refreshAuthorization(); reminders.use(store.schedule) }
        .onChange(of: phase) { _, phase in
            if phase == .active { Task { await reminders.refreshAuthorization(); reminders.use(store.schedule) } }
        }
    }

    private func summary(_ prayer: Prayer) -> String {
        let enabled = reminders.rules.filter { $0.prayer == prayer && $0.enabled }
        return enabled.isEmpty ? "Off" : enabled.map { "\($0.kind.title) · \($0.minutesBefore)m" }.joined(separator: ", ")
    }
}

private struct PrayerReminderView: View {
    let prayer: Prayer
    @Environment(PrayerStore.self) private var store
    var body: some View {
        Form {
            ForEach(ReminderKind.allCases) { kind in
                if let rule = store.reminders.rules.first(where: { $0.prayer == prayer && $0.kind == kind }) {
                    Section(kind.title) {
                        Toggle("Remind me", isOn: Binding(get: { rule.enabled }, set: {
                            var updated = rule; updated.enabled = $0; store.reminders.update(updated)
                        }))
                        if rule.enabled {
                            LabeledContent("Minutes before") {
                                TextField("Minutes", value: Binding(get: { rule.minutesBefore }, set: {
                                    var updated = rule; updated.minutesBefore = $0; store.reminders.update(updated)
                                }), format: .number)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                .accessibilityLabel("Minutes before \(kind.title)")
                            }
                            Text(rule.minutesBefore == 0 ? "Notify at the published time." : "Notify \(rule.minutesBefore) minutes before \(prayer.title) \(kind.title.lowercased()).")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(prayer.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
        }
    }
}
