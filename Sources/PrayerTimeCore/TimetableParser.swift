import Foundation
import SwiftSoup

public enum TimetableError: LocalizedError, Sendable {
    case changedPage, badResponse, invalidDate
    public var errorDescription: String? {
        switch self {
        case .changedPage: "The website returned an unrecognised timetable. Please check the source or try again later."
        case .badResponse: "Salaah Times could not be reached. Please try again."
        case .invalidDate: "The website's timetable dates could not be verified."
        }
    }
}

public enum TimetableParser {
    public static func directory(_ html: String) throws -> [Mosque] {
        let document = try SwiftSoup.parse(html)
        var mosques: [Int: Mosque] = [:]
        for link in try document.select("#jamaat-times a[href^=/Mosque/Details/]") {
            let path = try link.attr("href")
            guard let id = Int(path.split(separator: "/").last ?? ""), id > 0 else { continue }
            let name = try link.text()
            guard !name.isEmpty else { continue }
            mosques[id] = Mosque(id: id, name: name)
        }
        guard !mosques.isEmpty else { throw TimetableError.changedPage }
        return mosques.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func schedule(_ html: String, mosque: Mosque, fetchedAt: Date = .now) throws -> MosqueSchedule {
        let document = try SwiftSoup.parse(html)
        let jamaat = try table(document, selector: "#jamaat-times", fetchedAt: fetchedAt)
        // Some mosques publish jamaat only. Missing beginning tables are permitted,
        // but an existing, unrecognised table is an error rather than fabricated data.
        let beginning: [PrayerDay]
        if try document.select("#beginning-times tr td").isEmpty() {
            beginning = []
        } else {
            beginning = try table(document, selector: "#beginning-times", fetchedAt: fetchedAt)
        }
        let days = jamaat.map { day in
            PrayerDay(date: day.date, jamaat: day.jamaat,
                      beginning: beginning.first { $0.date == day.date }?.jamaat ?? [:])
        }

        var entries: [JummahEntry] = []
        for heading in try document.select("h3") {
            guard try heading.text().lowercased().contains("jumu") else { continue }
            var sibling = try heading.nextElementSibling()
            while let element = sibling, element.tagName() != "h3" {
                if element.tagName() == "p" {
                    let label = try element.select("b, strong").text()
                    let full = try element.text()
                    let value = label.isEmpty ? full : String(full.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        entries.append(JummahEntry(label: label.isEmpty ? "Jummah" : label, value: value, id: entries.count))
                    }
                }
                sibling = try element.nextElementSibling()
            }
        }

        func field(_ key: String) throws -> String {
            guard let label = try document.select("label[for=\(key)]").first(), let parent = label.parent() else { return "" }
            let title = try label.text()
            return String(try parent.text().dropFirst(title.count)).trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{00a0}")))
        }
        let address = try [field("Address"), field("Post_Code")].filter { !$0.isEmpty }.joined(separator: ", ")
        return MosqueSchedule(mosque: mosque, fetchedAt: fetchedAt, days: days, jummah: entries,
                              address: address, notes: try field("Notes"))
    }

    private static func table(_ document: Document, selector: String, fetchedAt: Date) throws -> [PrayerDay] {
        let rows = try document.select("\(selector) tr")
        guard let header = rows.first() else { throw TimetableError.changedPage }
        let headers = try header.select("th").array().map { try $0.text() }
        guard headers.first?.lowercased() == "date", headers.count >= 6 else { throw TimetableError.changedPage }
        let prayers = headers.dropFirst().map(Prayer.sourceHeader)
        guard prayers.allSatisfy({ $0 != nil }), Set(prayers.compactMap { $0 }).count == prayers.count else {
            throw TimetableError.changedPage
        }
        var days: [PrayerDay] = []
        for row in rows.dropFirst() {
            let cells = try row.select("td").array()
            guard !cells.isEmpty else { continue }
            guard cells.count == headers.count else { throw TimetableError.changedPage }
            let date = try parseDate(cells[0].text(), fetchedAt: fetchedAt)
            var times: [Prayer: ClockTime] = [:]
            for (index, prayer) in prayers.enumerated() {
                let text = try cells[index + 1].text().trimmingCharacters(in: .whitespacesAndNewlines)
                if let clock = ClockTime(text), let prayer { times[prayer] = clock }
                else if !text.isEmpty && text != "-" && text != "--" && text != "—" { throw TimetableError.changedPage }
            }
            days.append(PrayerDay(date: date, jamaat: times, beginning: [:]))
        }
        guard !days.isEmpty, Set(days.map(\.date)).count == days.count else { throw TimetableError.changedPage }
        return days.sorted { $0.date < $1.date }
    }

    private static func parseDate(_ label: String, fetchedAt: Date) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = UKClock.calendar
        formatter.timeZone = UKClock.timeZone
        formatter.dateFormat = "EEE d MMM yyyy"
        formatter.isLenient = false
        let year = UKClock.calendar.component(.year, from: fetchedAt)
        let candidates = (year - 1...year + 1).compactMap { candidate -> Date? in
            guard let date = formatter.date(from: "\(label) \(candidate)"),
                  formatter.string(from: date) == "\(label) \(candidate)",
                  abs(date.timeIntervalSince(fetchedAt)) < 62 * 86_400 else { return nil }
            return date
        }
        guard let date = candidates.min(by: { abs($0.timeIntervalSince(fetchedAt)) < abs($1.timeIntervalSince(fetchedAt)) }) else {
            throw TimetableError.invalidDate
        }
        return date
    }
}
