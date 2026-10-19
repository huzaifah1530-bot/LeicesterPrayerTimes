import Foundation
import Testing
@testable import PrayerTimeCore

struct ReminderTests {
    private func schedule() throws -> MosqueSchedule {
        let url = Bundle.module.url(forResource: "aisha", withExtension: "html", subdirectory: "Fixtures")!
        return try TimetableParser.schedule(String(contentsOf: url, encoding: .utf8), mosque: Mosque(id: 1, name: "Masjid Aisha"),
            fetchedAt: ISO8601DateFormatter().date(from: "2026-10-19T12:00:00Z")!)
    }

    @Test func beginningAndJamaatHaveIndependentOffsetsAndIDs() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")!
        let rules = [ReminderRule(prayer: .fajr, kind: .beginning, enabled: true, minutesBefore: 25),
                     ReminderRule(prayer: .fajr, kind: .jamaat, enabled: true, minutesBefore: 5)]
        let result = ReminderPlanner.plan(schedule: try schedule(), rules: rules, now: now)
        #expect(result.count == 62)
        #expect(result[0].fireDate == ISO8601DateFormatter().date(from: "2026-10-01T03:46:00Z"))
        #expect(result[1].fireDate == ISO8601DateFormatter().date(from: "2026-10-01T05:15:00Z"))
        #expect(Set(result.map(\.id)).count == result.count)
    }

    @Test func disabledOrUnpublishedTimesNeverGenerateReminders() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")!
        let rules = [ReminderRule(prayer: .fajr, kind: .jamaat),
                     ReminderRule(prayer: .maghrib, kind: .beginning, enabled: true)]
        #expect(ReminderPlanner.plan(schedule: try schedule(), rules: rules, now: now).isEmpty)
    }

    @Test func queueIsBoundedChronologicalAndContainsNoPastTriggers() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-19T15:00:00Z")!
        var rules = ReminderRule.defaults
        for index in rules.indices { rules[index].enabled = true; rules[index].minutesBefore = 0 }
        let result = ReminderPlanner.plan(schedule: try schedule(), rules: rules, now: now)
        #expect(result.count == 63)
        #expect(result.allSatisfy { $0.fireDate > now && $0.fireDate == $0.eventDate })
        #expect(result.map(\.fireDate) == result.map(\.fireDate).sorted())
    }
}
