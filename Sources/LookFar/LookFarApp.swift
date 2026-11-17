import AppKit
import SwiftUI
import LookFarCore

@main
struct LookFarApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Menu bar only: no Dock icon, even when run outside the .app bundle.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.isPaused ? "eye.slash" : "eye")
        }
    }
}

extension AppModel {
    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(statusLine)

        Divider()

        switch model.state {
        case .paused:
            Button("Resume") { model.resume() }
        default:
            Menu("Pause") {
                Button("For 30 minutes") { model.pause(for: 30 * 60) }
                Button("For 1 hour") { model.pause(for: 60 * 60) }
                Button("For 2 hours") { model.pause(for: 2 * 60 * 60) }
                Button("Until I resume") { model.pause(for: nil) }
            }
        }

        Menu("Take a break now") {
            ForEach(model.settings.breaks.filter(\.isEnabled)) { kind in
                Button(kind.name) { model.startBreakNow(kind) }
            }
        }

        Divider()

        Button("Settings…") { SettingsWindow.show(model: model) }
            .keyboardShortcut(",")
        Button("Quit LookFar") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLine: String {
        switch model.state {
        case .paused(let until):
            guard let until else { return "Paused" }
            return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        case .onBreak(let kind, _, _):
            return "On a \(kind.name.lowercased()) break"
        case .working:
            guard let next = model.next else { return "No breaks enabled" }
            return "\(next.kind.name) in \(Format.duration(next.remaining))"
        }
    }
}

enum Format {
    /// "45 s", "12 min", "1 h 05 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        if s < 60 { return "\(s) s" }
        let minutes = (s + 59) / 60
        if minutes < 60 { return "\(minutes) min" }
        return String(format: "%d h %02d min", minutes / 60, minutes % 60)
    }

    /// "0:20", "4:59".
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
