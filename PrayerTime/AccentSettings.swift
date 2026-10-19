import SwiftUI
import UIKit
import Observation

enum AppAccent: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, yellow, green, teal
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var iconName: String? { self == .blue ? nil : "AppIcon-\(rawValue)" }
    var previewName: String { "IconPreview-\(rawValue)" }
    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        }
    }
}

@MainActor @Observable
final class AccentSettings {
    private(set) var selected = AppAccent(rawValue: UserDefaults.standard.string(forKey: "appAccent") ?? "blue") ?? .blue
    private(set) var isChanging = false
    private(set) var error: String?

    func choose(_ accent: AppAccent) async {
        guard !isChanging, selected != accent || UIApplication.shared.alternateIconName != accent.iconName else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            error = "This installation doesn't support alternate icons."
            return
        }
        isChanging = true
        error = nil
        defer { isChanging = false }
        do {
            try await UIApplication.shared.setAlternateIconName(accent.iconName)
            selected = accent
            UserDefaults.standard.set(accent.rawValue, forKey: "appAccent")
        } catch {
            self.error = "The icon couldn't be changed. \(error.localizedDescription)"
        }
    }
}
