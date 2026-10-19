import Foundation
import Observation
import UserNotifications
import PrayerTimeCore

@MainActor @Observable
final class ReminderSettings {
    private(set) var rules: [ReminderRule]
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var pendingCount = 0
    private(set) var scheduledThrough: Date?
    private(set) var error: String?
    private var schedule: MosqueSchedule?
    private var revision = 0
    private var worker: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()

    init() {
        let saved = UserDefaults.standard.data(forKey: "prayerReminders")
            .flatMap { try? JSONDecoder().decode([ReminderRule].self, from: $0) } ?? []
        rules = ReminderRule.defaults.map { rule in saved.first { $0.id == rule.id } ?? rule }
    }

    var isAuthorized: Bool { authorization == .authorized || authorization == .provisional || authorization == .ephemeral }

    func refreshAuthorization() async {
        let previous = authorization
        authorization = await center.notificationSettings().authorizationStatus
        if authorization != previous { queueRebuild() }
    }

    func requestPermission() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
        catch { self.error = error.localizedDescription }
        await refreshAuthorization()
        queueRebuild()
    }

    func update(_ rule: ReminderRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var validated = rule
        validated.minutesBefore = max(0, min(rule.minutesBefore, 1_000_000))
        rules[index] = validated
        UserDefaults.standard.set(try? JSONEncoder().encode(rules), forKey: "prayerReminders")
        queueRebuild()
    }

    func use(_ schedule: MosqueSchedule?) {
        self.schedule = schedule
        queueRebuild()
    }

    private func queueRebuild() {
        revision += 1
        guard worker == nil else { return }
        // One worker serialises notification-centre mutations. A changed mosque or
        // preference invalidates the current pass and is applied before it exits.
        worker = Task {
            while true {
                let version = revision
                await rebuild(version: version)
                if version == revision { break }
            }
            worker = nil
        }
    }

    private func rebuild(version: Int) async {
        let requests = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix("prayer.") })
        pendingCount = 0
        scheduledThrough = nil
        error = nil
        await refreshAuthorization()
        guard version == revision, isAuthorized, let schedule else { return }
        let plan = ReminderPlanner.plan(schedule: schedule, rules: rules)
        for event in plan {
            guard version == revision else { return }
            let content = UNMutableNotificationContent()
            content.title = "\(event.prayer.title) · \(event.kind.title)"
            let when = event.minutesBefore == 0 ? "Now" : "In \(event.minutesBefore) minutes"
            content.body = "\(when) at \(schedule.mosque.name) · \(UKClock.timeLabel(event.eventDate)) UK time"
            content.sound = .default
            content.threadIdentifier = "prayer-times"
            let trigger = UNCalendarNotificationTrigger(dateMatching: event.triggerComponents, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: event.id, content: content, trigger: trigger))
                pendingCount += 1
                scheduledThrough = event.fireDate
            } catch {
                self.error = "Some reminders could not be scheduled. \(error.localizedDescription)"
                break
            }
        }
    }
}
