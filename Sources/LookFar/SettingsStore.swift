import Foundation
import LookFarCore

enum SettingsStore {
    private static let key = "settings.v1"

    static func load() -> Preferences {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return .default }
        return settings
    }

    static func save(_ settings: Preferences) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
