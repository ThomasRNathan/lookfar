import AppKit
import Combine
import CoreGraphics
import LookFarCore

/// Owns the scheduler, ticks it once a second and drives the break overlay.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: BreakScheduler.State = .working
    @Published private(set) var next: (kind: BreakKind, remaining: TimeInterval)?
    @Published var settings: Preferences {
        didSet {
            scheduler.update(settings: settings)
            SettingsStore.save(settings)
            refresh()
        }
    }

    private let scheduler: BreakScheduler
    private let overlay = OverlayController()
    private var timer: Timer?

    init() {
        let settings = SettingsStore.load()
        self.settings = settings
        self.scheduler = BreakScheduler(settings: settings)
        overlay.onPostpone = { [weak self] in self?.apply(self?.scheduler.postpone() ?? []) }
        overlay.onSkip = { [weak self] in self?.apply(self?.scheduler.skip() ?? []) }
        overlay.onEndEarly = { [weak self] in self?.apply(self?.scheduler.endEarly() ?? []) }

        tick()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Menu commands

    func startBreakNow(_ kind: BreakKind) {
        apply(scheduler.startBreak(kind, now: Date()))
    }

    func pause(for duration: TimeInterval?) {
        apply(scheduler.pause(until: duration.map { Date().addingTimeInterval($0) }))
    }

    func resume() {
        apply(scheduler.resume(now: Date()))
    }

    // MARK: - Ticking

    private func tick() {
        apply(scheduler.tick(now: Date(), idleSeconds: Self.idleSeconds()))
    }

    private func apply(_ events: [BreakScheduler.Event]) {
        for event in events {
            switch event {
            case .breakStarted(let kind, let endsAt):
                overlay.show(kind: kind, endsAt: endsAt, controlsDelay: settings.controlsDelay)
            case .breakEnded:
                overlay.hide()
            case .naturalBreak, .resumed:
                break
            }
        }
        refresh()
    }

    private func refresh() {
        state = scheduler.state
        next = scheduler.nextBreak()
    }

    /// Seconds since the last keyboard, mouse or trackpad input, system-wide.
    /// Reading this needs no special permission.
    private static func idleSeconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
