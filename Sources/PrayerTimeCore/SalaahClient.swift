import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Network and DOM parsing run on this actor, away from SwiftUI's main actor.
public actor SalaahClient {
    public init() {}

    public func mosques() async throws -> [Mosque] {
        let html = try await fetch(URL(string: "https://www.salaahtimes.co.uk/Timetable/TodaysTimes")!)
        return try TimetableParser.directory(html)
    }

    public func schedule(for mosque: Mosque) async throws -> MosqueSchedule {
        let html = try await fetch(mosque.sourceURL)
        try Task.checkCancellation()
        return try TimetableParser.schedule(html, mosque: mosque)
    }

    private func fetch(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("PrayerTime/1.0 (iOS; public timetable reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode),
              response.url?.host == "www.salaahtimes.co.uk", data.count < 5_000_000,
              let html = String(data: data, encoding: .utf8) else { throw TimetableError.badResponse }
        return html
    }
}
