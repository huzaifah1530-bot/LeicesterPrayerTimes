import Foundation
import Testing
@testable import PrayerTimeCore

struct ParserTests {
    let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-19T12:00:00Z")!

    func fixture(_ name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func realDirectoryPreservesIDsAndEntities() throws {
        let mosques = try TimetableParser.directory(fixture("directory"))
        #expect(mosques.count > 40)
        #expect(mosques.contains(Mosque(id: 1, name: "Masjid Aisha")))
        #expect(mosques.contains { $0.name.contains("Da'wah") })
        #expect(Set(mosques.map(\.id)).count == mosques.count)
    }

    @Test func realMonthKeepsBeginningAndJamaatSeparate() throws {
        let schedule = try TimetableParser.schedule(fixture("aisha"), mosque: Mosque(id: 1, name: "Masjid Aisha"), fetchedAt: fetchedAt)
        #expect(schedule.days.count == 31)
        let first = try #require(schedule.days.first)
        #expect(first.jamaat[.fajr]?.description == "06:20")
        #expect(first.beginning[.fajr]?.description == "05:11")
        #expect(first.beginning[.sunrise]?.description == "07:06")
        #expect(first.beginning[.asrShafi]?.description == "15:59")
        #expect(schedule.jummah.map(\.label) == ["Bayaan", "Azaan", "Khutba"])
        #expect(schedule.address == "22-28 Cork Street, LE5 5AN")
    }

    @Test func noInventedTimesAndNoSilentSchemaChanges() throws {
        #expect(ClockTime("--") == nil)
        #expect(ClockTime("24:01") == nil)
        #expect(ClockTime("13:60") == nil)
        #expect(throws: (any Error).self) { try TimetableParser.directory("<html>Maintenance</html>") }
        #expect(throws: (any Error).self) {
            try TimetableParser.schedule("<html>Maintenance</html>", mosque: Mosque(id: 1, name: "A"), fetchedAt: fetchedAt)
        }
    }

    @Test func nextPrayerUsesLondonAndStopsAtEndOfMonth() throws {
        let schedule = try TimetableParser.schedule(fixture("aisha"), mosque: Mosque(id: 1, name: "Masjid Aisha"), fetchedAt: fetchedAt)
        let date = ISO8601DateFormatter().date(from: "2026-10-01T04:00:00Z")!
        let next = try #require(schedule.nextJamaat(after: date))
        #expect(next.prayer == .fajr)
        #expect(next.date == ISO8601DateFormatter().date(from: "2026-10-01T05:20:00Z"))
        let end = ISO8601DateFormatter().date(from: "2026-10-31T23:59:00Z")!
        #expect(schedule.nextJamaat(after: end) == nil)
    }

    @Test func clockConversionHonoursDST() throws {
        let clock = try #require(ClockTime("13:30"))
        let summer = ISO8601DateFormatter().date(from: "2026-10-24T00:00:00Z")!
        let winter = ISO8601DateFormatter().date(from: "2026-10-26T00:00:00Z")!
        #expect(clock.on(summer) == ISO8601DateFormatter().date(from: "2026-10-24T12:30:00Z"))
        #expect(clock.on(winter) == ISO8601DateFormatter().date(from: "2026-10-26T13:30:00Z"))
    }
}
