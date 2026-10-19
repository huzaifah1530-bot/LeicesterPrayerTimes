import SwiftUI
import PrayerTimeCore

struct WidgetSettingsView: View {
    @Environment(PrayerStore.self) private var store
    var body: some View {
        List {
            Section("Home Screen") {
                Label("Next prayer", systemImage: "clock")
                Text("Touch and hold your Home Screen, choose Edit, then Add Widget. Search for Prayer Time and choose a size. The medium and large widgets also show today's prayer times.")
            }
            Section("Lock Screen") {
                Label("Prayer at a glance", systemImage: "lock")
                Text("Touch and hold your Lock Screen, tap Customise, then tap the widget area. Choose Prayer Time for an inline, circular or rectangular next-prayer widget.")
            }
            Section("Your timetable") {
                Text("Touch and hold a widget, choose Edit Widget, then choose Mosque. Each widget can fetch its own mosque's timetable, even when shared app data is unavailable. You can also choose Beginning or Jamaat times.")
                Text("Widgets update at prayer changes and periodically check for a fresh timetable. iOS controls background refresh timing. If no current timetable is available, the widget asks you to open Prayer Time.")
                if store.widgetError != nil { Text("Automatic mosque sharing is unavailable on this installation. Choose the mosque in Edit Widget instead.").foregroundStyle(.secondary) }
            }
        }.navigationTitle("Widgets").navigationBarTitleDisplayMode(.inline)
    }
}
