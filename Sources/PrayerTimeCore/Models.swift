import Foundation

public enum UKClock {
    public static let timeZone = TimeZone(identifier: "Europe/London")!
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }

    public static func timeLabel(_ date: Date) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    public static func timestampLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMM yyyy, HH:mm z"
        return formatter.string(from: date)
    }
}

public struct Mosque: Identifiable, Hashable, Codable, Sendable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) { self.id = id; self.name = name }
    public var sourceURL: URL { URL(string: "https://www.salaahtimes.co.uk/Mosque/Details/\(id)")! }
}

public struct ClockTime: Hashable, Codable, Sendable, CustomStringConvertible {
    public let hour: Int
    public let minute: Int

    public init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public func on(_ day: Date) -> Date? {
        UKClock.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

public enum Prayer: String, Codable, CaseIterable, Identifiable, Sendable {
    case fajr, sunrise, dhuhr, asrShafi, asr, maghrib, ishaShafi, isha
    public var id: String { rawValue }
    public static let daily: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
    public var title: String {
        switch self {
        case .fajr: "Fajr"
        case .sunrise: "Sunrise"
        case .dhuhr: "Dhuhr"
        case .asrShafi: "Asr · Shafi"
        case .asr: "Asr"
        case .maghrib: "Maghrib"
        case .ishaShafi: "Isha · Shafi"
        case .isha: "Isha"
        }
    }
    public var symbol: String {
        switch self {
        case .fajr: "sun.haze"
        case .sunrise: "sunrise"
        case .dhuhr: "sun.max"
        case .asr, .asrShafi: "sun.haze"
        case .maghrib: "sunset"
        case .isha, .ishaShafi: "moon.stars"
        }
    }

    static func sourceHeader(_ text: String) -> Prayer? {
        let header = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if header.contains("dawn") || header == "fajr" { return .fajr }
        if header == "sunrise" { return .sunrise }
        if header == "zohar" || header == "dhuhr" { return .dhuhr }
        if header == "shafi asr" { return .asrShafi }
        if header == "asr" { return .asr }
        if header == "maghrib" { return .maghrib }
        if header == "shafi eisha" { return .ishaShafi }
        if header == "eisha" || header == "isha" { return .isha }
        return nil
    }
}

public struct PrayerDay: Identifiable, Codable, Sendable {
    public let date: Date
    public var jamaat: [Prayer: ClockTime]
    public var beginning: [Prayer: ClockTime]
    public var id: Date { date }

    public var usesMaghribJamaatForBeginning: Bool { beginning[.maghrib] == nil && jamaat[.maghrib] != nil }
    /// Preserve published data separately from the user-requested Maghrib fallback.
    public var effectiveBeginning: [Prayer: ClockTime] {
        var times = beginning
        if times[.maghrib] == nil { times[.maghrib] = jamaat[.maghrib] }
        return times
    }
}

public struct JummahEntry: Identifiable, Codable, Sendable {
    public let label: String
    public let value: String
    public let id: Int
}

public struct NextJamaat: Sendable {
    public let prayer: Prayer
    public let date: Date
    public init(prayer: Prayer, date: Date) { self.prayer = prayer; self.date = date }
}

public struct MosqueSchedule: Codable, Sendable {
    public let mosque: Mosque
    public let fetchedAt: Date
    public let days: [PrayerDay]
    public let jummah: [JummahEntry]
    public let address: String
    public let notes: String

    public func day(on date: Date) -> PrayerDay? {
        days.first { UKClock.calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func nextJamaat(after now: Date) -> NextJamaat? {
        days.flatMap { day in
            Prayer.daily.compactMap { prayer -> NextJamaat? in
                guard let clock = day.jamaat[prayer], let date = clock.on(day.date), date > now else { return nil }
                return NextJamaat(prayer: prayer, date: date)
            }
        }.min { $0.date < $1.date }
    }
}
