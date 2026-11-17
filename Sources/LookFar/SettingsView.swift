import AppKit
import ServiceManagement
import SwiftUI
import LookFarCore

/// A plain AppKit window hosting the SwiftUI settings form. Used instead of the
/// SwiftUI `Settings` scene, which is unreliable to open from a menu bar–only app.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(model: AppModel) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "LookFar Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private static let durationChoices: [TimeInterval] = [10, 20, 30, 45, 60, 120, 180, 300, 600, 900, 1200]

    var body: some View {
        Form {
            ForEach($model.settings.breaks) { $kind in
                Section {
                    Toggle("Enabled", isOn: $kind.isEnabled)
                    Stepper(value: minutes($kind.interval), in: 1...240) {
                        Text("Every \(Int(kind.interval / 60)) min of activity")
                    }
                    .disabled(!kind.isEnabled)
                    Picker("Lasts", selection: $kind.duration) {
                        ForEach(Self.choices(including: kind.duration), id: \.self) { value in
                            Text(Format.duration(value)).tag(value)
                        }
                    }
                    .disabled(!kind.isEnabled)
                } header: {
                    Text(kind.name).font(.headline)
                }
            }

            Section {
                Stepper(value: minutes($model.settings.postponeDuration), in: 1...60) {
                    Text("Postpone by \(Int(model.settings.postponeDuration / 60)) min")
                }
                Stepper(value: $model.settings.idleThreshold, in: 10...300, step: 10) {
                    Text("Count me as away after \(Int(model.settings.idleThreshold)) s without input")
                }
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin, perform: setLaunchAtLogin)
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("General").font(.headline)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func minutes(_ seconds: Binding<TimeInterval>) -> Binding<Int> {
        Binding(
            get: { Int(seconds.wrappedValue / 60) },
            set: { seconds.wrappedValue = TimeInterval($0 * 60) }
        )
    }

    private static func choices(including value: TimeInterval) -> [TimeInterval] {
        durationChoices.contains(value) ? durationChoices : (durationChoices + [value]).sorted()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            // Fails when running outside a .app bundle (e.g. `swift run`).
            loginError = "Couldn't change this: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
