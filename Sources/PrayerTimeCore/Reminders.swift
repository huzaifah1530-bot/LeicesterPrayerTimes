import Foundation

public enum ReminderKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case beginning, jamaat
    public var id: String { rawValue }
    public var title: String { self == .beginning ? "Beginning" : "Jamaat" }
}

public struct ReminderRule: Codable, Hashable, Identifiable, Sendable {
    public let prayer: Prayer
    public let kind: ReminderKind
    public var enabled: Bool
    public var minutesBefore: Int
    public var id: String { "\(prayer.rawValue).\(kind.rawValue)" }
    public init(prayer: Prayer, kind: ReminderKind, enabled: Bool = false, minutesBefore: Int = 10) {
        self.prayer = prayer; self.kind = kind; self.enabled = enabled; self.minutesBefore = minutesBefore
    }
    public static var defaults: [ReminderRule] {
        Prayer.daily.flatMap { prayer in ReminderKind.allCases.map { ReminderRule(prayer: prayer, kind: $0) } }
    }
}

public struct PlannedReminder: Sendable {
    public let id: String
    public let prayer: Prayer
    public let kind: ReminderKind
    public let eventDate: Date
    public let fireDate: Date
    public let minutesBefore: Int
}

public enum ReminderPlanner {
    /// iOS has a finite pending-request allowance. Always keep the nearest events.
    public static func plan(schedule: MosqueSchedule, rules: [ReminderRule], now: Date = .now, limit: Int = 63) -> [PlannedReminder] {
        var reminders: [PlannedReminder] = []
        for day in schedule.days {
            for rule in rules where rule.enabled {
                let times = rule.kind == .beginning ? day.beginning : day.jamaat
                guard let time = times[rule.prayer], let event = time.on(day.date) else { continue }
                let minutes = max(0, min(rule.minutesBefore, 1_000_000))
                let fire = event.addingTimeInterval(-Double(minutes) * 60)
                guard fire > now else { continue }
                let id = "prayer.\(schedule.mosque.id).\(Int(event.timeIntervalSince1970)).\(rule.id)"
                reminders.append(PlannedReminder(id: id, prayer: rule.prayer, kind: rule.kind,
                                                eventDate: event, fireDate: fire, minutesBefore: minutes))
            }
        }
        reminders.sort {
            $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate
        }
        return Array(reminders.prefix(max(0, limit)))
    }
}
