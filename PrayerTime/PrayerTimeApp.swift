import SwiftUI
import PrayerTimeCore

@main
struct PrayerTimeApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    @State private var store = PrayerStore()
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(appearance == "system" ? nil : (appearance == "dark" ? .dark : .light))
                .task { await store.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refreshIfNeeded() } }
                }
        }
    }
}

struct RootView: View {
    @State private var selection = 0
    @Environment(PrayerStore.self) private var store

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: 0) {
                NavigationStack { HomeView() }
            }
            Tab("Settings", systemImage: "gearshape", value: 1) {
                NavigationStack { SettingsView() }
            }
        }
        .onOpenURL { url in
            if url.scheme == "prayertime" { selection = 0 }
        }
        .sheet(isPresented: Binding(get: { store.showMosquePicker }, set: { store.showMosquePicker = $0 })) {
            NavigationStack { MosquePickerView(isSheet: true) }
        }
    }
}
