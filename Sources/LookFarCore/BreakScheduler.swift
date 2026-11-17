import Foundation

/// Decides when breaks start and end.
///
/// The scheduler is a plain state machine. It never reads the clock or the
/// keyboard itself: the app calls `tick(now:idleSeconds:)` about once a second
/// and reacts to the events it returns. That keeps it deterministic and testable.
public final class BreakScheduler {
    public enum State: Equatable {
        case working
        case onBreak(kind: BreakKind, startedAt: Date, endsAt: Date)
        case paused(until: Date?)
    }

    public enum EndReason: String, Codable, Equatable {
        case completed, skipped, postponed, endedEarly
    }

    public enum Event: Equatable {
        case breakStarted(BreakKind, endsAt: Date)
        case breakEnded(BreakKind, EndReason)
        /// You were away long enough that this break counts as taken.
        case naturalBreak(BreakKind)
        case resumed
    }

    /// A gap between ticks longer than this is treated as time away (sleep, lid closed).
    public static let sleepGap: TimeInterval = 60

    public private(set) var settings: Preferences
    public private(set) var state: State = .working

    /// Active work time accumulated toward each break, by break id.
    public private(set) var worked: [String: TimeInterval] = [:]
    /// Break ids already credited as natural breaks during the current idle stretch.
    private var naturalCredited: Set<String> = []
    private var lastTick: Date?

    public init(settings: Preferences = .default) {
        self.settings = settings
    }

    public var enabledBreaks: [BreakKind] { settings.breaks.filter(\.isEnabled) }

    public func update(settings: Preferences) {
        self.settings = settings
        let ids = Set(settings.breaks.map(\.id))
        worked = worked.filter { ids.contains($0.key) }
    }

    /// Seconds of active work left before `kind` is due.
    public func timeRemaining(for kind: BreakKind) -> TimeInterval {
        max(0, kind.interval - (worked[kind.id] ?? 0))
    }

    /// The enabled break that comes next, with the time left before it.
    public func nextBreak() -> (kind: BreakKind, remaining: TimeInterval)? {
        enabledBreaks
            .map { ($0, timeRemaining(for: $0)) }
            .min { $0.1 < $1.1 }
            .map { (kind: $0.0, remaining: $0.1) }
    }

    // MARK: - Ticking

    @discardableResult
    public func tick(now: Date, idleSeconds: TimeInterval) -> [Event] {
        let delta = lastTick.map { max(0, now.timeIntervalSince($0)) } ?? 0
        lastTick = now

        switch state {
        case .paused(let until):
            if let until, now >= until {
                state = .working
                return [.resumed]
            }
            return []

        case .onBreak(let kind, _, let endsAt):
            if now >= endsAt {
                return finishBreak(kind, reason: .completed)
            }
            return []

        case .working:
            var events: [Event] = []
            // A long gap between ticks means the Mac slept: treat it as time away.
            let away = delta > Self.sleepGap ? max(idleSeconds, delta) : idleSeconds

            if away >= settings.idleThreshold {
                events += creditNaturalBreaks(awayFor: away)
            } else {
                naturalCredited.removeAll()
                for kind in enabledBreaks {
                    worked[kind.id, default: 0] += delta
                }
            }

            if let due = dueBreak() {
                events += startBreak(due, now: now)
            }
            return events
        }
    }

    private func creditNaturalBreaks(awayFor away: TimeInterval) -> [Event] {
        var events: [Event] = []
        for kind in enabledBreaks where away >= kind.duration && !naturalCredited.contains(kind.id) {
            naturalCredited.insert(kind.id)
            if (worked[kind.id] ?? 0) > 0 {
                worked[kind.id] = 0
                events.append(.naturalBreak(kind))
            }
        }
        return events
    }

    /// When several breaks are due at once, the longest one wins.
    private func dueBreak() -> BreakKind? {
        enabledBreaks
            .filter { (worked[$0.id] ?? 0) >= $0.interval }
            .max { $0.duration < $1.duration }
    }

    // MARK: - Actions

    @discardableResult
    public func startBreak(_ kind: BreakKind, now: Date) -> [Event] {
        let endsAt = now.addingTimeInterval(kind.duration)
        state = .onBreak(kind: kind, startedAt: now, endsAt: endsAt)
        lastTick = now
        return [.breakStarted(kind, endsAt: endsAt)]
    }

    @discardableResult
    public func skip() -> [Event] {
        guard case .onBreak(let kind, _, _) = state else { return [] }
        return finishBreak(kind, reason: .skipped)
    }

    @discardableResult
    public func endEarly() -> [Event] {
        guard case .onBreak(let kind, _, _) = state else { return [] }
        return finishBreak(kind, reason: .endedEarly)
    }

    @discardableResult
    public func postpone() -> [Event] {
        guard case .onBreak(let kind, _, _) = state else { return [] }
        state = .working
        worked[kind.id] = max(0, kind.interval - settings.postponeDuration)
        return [.breakEnded(kind, .postponed)]
    }

    /// Pause reminders. `nil` pauses until `resume()`.
    @discardableResult
    public func pause(until: Date?) -> [Event] {
        var events: [Event] = []
        if case .onBreak(let kind, _, _) = state {
            events.append(.breakEnded(kind, .skipped))
        }
        state = .paused(until: until)
        return events
    }

    @discardableResult
    public func resume(now: Date) -> [Event] {
        guard case .paused = state else { return [] }
        state = .working
        lastTick = now
        return [.resumed]
    }

    private func finishBreak(_ kind: BreakKind, reason: EndReason) -> [Event] {
        state = .working
        // Taking (or skipping) a break also covers every shorter break.
        for other in enabledBreaks where other.duration <= kind.duration {
            worked[other.id] = 0
        }
        return [.breakEnded(kind, reason)]
    }
}
