import Foundation
import Testing
@testable import PrayerTimeCore

struct FridayWidgetTests {
    func schedule(_ fixture: String = "multiple-jummah") throws -> MosqueSchedule {
        let url = Bundle.module.url(forResource: fixture, withExtension: "html", subdirectory: "Fixtures")!
        return try TimetableParser.schedule(String(contentsOf: url, encoding: .utf8), mosque: Mosque(id: 29, name: "Test mosque"),
            fetchedAt: ISO8601DateFormatter().date(from: "2026-10-19T12:00:00Z")!)
    }
    @Test func fridayReplacesDhuhrWithAllThreePublishedServices() throws {
        let schedule = try schedule()
        let friday = try #require(schedule.days.first { UKClock.calendar.component(.weekday, from: $0.date) == 6 })
        let rows = schedule.widgetRows(for: friday, jamaat: true)
        #expect(rows.count == 7)
        #expect(!rows.contains { $0.title == "Dhuhr" })
        let jummah = rows.filter { $0.slot == .dhuhr }
        #expect(jummah.map(\.title) == ["Jummah 1", "Jummah 2", "Jummah 3"])
        #expect(jummah.map { $0.time?.description } == ["13:30", "14:30", "15:30"])
        #expect(jummah.allSatisfy { $0.detail == "Khutba" })
        #expect(schedule.widgetRows(for: friday, jamaat: false).contains { $0.title == "Dhuhr" })
    }
    @Test func countdownMovesToSecondServiceRatherThanFridayDhuhr() throws {
        let schedule = try schedule()
        let now = ISO8601DateFormatter().date(from: "2026-10-02T12:45:00Z")!
        let next = try #require(schedule.nextWidgetPrayer(after: now, jamaat: true))
        #expect(next.row.title == "Jummah 2")
        #expect(next.row.detail == "Khutba")
        #expect(next.row.time?.description == "14:30")
    }
    @Test func weekdaysKeepDhuhrAndNoJummahIsInventedWhenMissing() throws {
        let schedule = try schedule()
        let thursday = try #require(schedule.days.first)
        #expect(schedule.widgetRows(for: thursday, jamaat: true).contains { $0.title == "Dhuhr" })
        let missing = try self.schedule("musalla")
        let friday = try #require(missing.days.first { UKClock.calendar.component(.weekday, from: $0.date) == 6 })
        let row = try #require(missing.widgetRows(for: friday, jamaat: true).first { $0.slot == .dhuhr })
        #expect(row.title == "Jummah")
        #expect(row.time == nil)
        #expect(row.detail == "Not published")
    }
    @Test func maghribFallbackNeverOverridesAPublishedBeginningTime() throws {
        let day = try #require(schedule("aisha").days.first)
        #expect(day.beginning[.maghrib] == nil)
        #expect(day.usesMaghribJamaatForBeginning)
        #expect(day.effectiveBeginning[.maghrib] == day.jamaat[.maghrib])
        var published = day
        published.beginning[.maghrib] = ClockTime("18:30")
        #expect(!published.usesMaghribJamaatForBeginning)
        #expect(published.effectiveBeginning[.maghrib]?.description == "18:30")
    }
}
