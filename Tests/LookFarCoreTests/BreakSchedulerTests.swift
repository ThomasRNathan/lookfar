import XCTest
@testable import LookFarCore

final class BreakSchedulerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private var now: Date!
    private var scheduler: BreakScheduler!

    private let micro = BreakKind(id: "m", name: "Micro", interval: 60, duration: 10, prompt: "")
    private let long = BreakKind(id: "l", name: "Long", interval: 180, duration: 60, prompt: "")

    override func setUp() {
        now = start
        scheduler = BreakScheduler(settings: Preferences(breaks: [micro, long], idleThreshold: 5, postponeDuration: 20))
        scheduler.tick(now: now, idleSeconds: 0)
    }

    /// Advance the clock one second at a time, collecting events.
    @discardableResult
    private func run(_ seconds: Int, idle: (Int) -> TimeInterval = { _ in 0 }) -> [BreakScheduler.Event] {
        var events: [BreakScheduler.Event] = []
        for i in 1...seconds {
            now = now.addingTimeInterval(1)
            events += scheduler.tick(now: now, idleSeconds: idle(i))
        }
        return events
    }

    func testMicroBreakStartsAfterInterval() {
        XCTAssertTrue(run(59).isEmpty)
        let events = run(1)
        XCTAssertEqual(events, [.breakStarted(micro, endsAt: now.addingTimeInterval(10))])
    }

    func testBreakCompletesAfterDuration() {
        run(60)
        let events = run(10)
        XCTAssertEqual(events, [.breakEnded(micro, .completed)])
        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.timeRemaining(for: micro), 60)
    }

    func testTimeOnBreakDoesNotCountAsWork() {
        run(60)  // micro starts
        run(10)  // micro completes
        // Long break needed 180s of work; only 60 counted so far.
        XCTAssertEqual(scheduler.timeRemaining(for: long), 120)
    }

    func testLongBreakWinsWhenBothDue() {
        scheduler.update(settings: Preferences(breaks: [
            BreakKind(id: "m", name: "Micro", interval: 60, duration: 10, prompt: ""),
            BreakKind(id: "l", name: "Long", interval: 60, duration: 60, prompt: ""),
        ], idleThreshold: 5))
        let events = run(60)
        guard case .breakStarted(let kind, _)? = events.last else { return XCTFail("no break") }
        XCTAssertEqual(kind.id, "l")
        run(60)
        // Finishing the long break resets the micro too.
        XCTAssertEqual(scheduler.timeRemaining(for: micro), 60)
    }

    func testIdleTimeDoesNotCountAndBecomesNaturalBreak() {
        run(30)
        // Away for 12 seconds: idle counter climbs past the 5s threshold and the 10s micro duration.
        let events = run(12) { TimeInterval($0) }
        XCTAssertEqual(events, [.naturalBreak(micro)])
        XCTAssertEqual(scheduler.timeRemaining(for: micro), 60)
        // Long break kept the 30s plus the first idle seconds below threshold.
        XCTAssertLessThan(scheduler.timeRemaining(for: long), 150 + 1)
        XCTAssertGreaterThan(scheduler.timeRemaining(for: long), 140)
    }

    func testSleepGapCountsAsTimeAway() {
        run(30)
        now = now.addingTimeInterval(120)  // lid closed for two minutes
        let events = scheduler.tick(now: now, idleSeconds: 0)
        XCTAssertEqual(Set(events.map(\.description)), ["natural:m", "natural:l"])
        XCTAssertEqual(scheduler.timeRemaining(for: long), 180)
    }

    func testPostponePushesBreakBack() {
        run(60)
        XCTAssertEqual(scheduler.postpone(), [.breakEnded(micro, .postponed)])
        XCTAssertEqual(scheduler.timeRemaining(for: micro), 20)
        XCTAssertTrue(run(19).isEmpty)
        guard case .breakStarted? = run(1).first else { return XCTFail("break did not return") }
    }

    func testSkipResetsCounter() {
        run(60)
        XCTAssertEqual(scheduler.skip(), [.breakEnded(micro, .skipped)])
        XCTAssertEqual(scheduler.timeRemaining(for: micro), 60)
    }

    func testPauseAndAutoResume() {
        scheduler.pause(until: now.addingTimeInterval(100))
        XCTAssertTrue(run(99).isEmpty)
        XCTAssertEqual(run(1), [.resumed])
        // Paused time did not count as work.
        XCTAssertEqual(scheduler.timeRemaining(for: micro), 60)
    }

    func testDisabledBreakNeverStarts() {
        var settings = scheduler.settings
        settings.breaks[0].isEnabled = false
        scheduler.update(settings: settings)
        let events = run(179)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(scheduler.nextBreak()?.kind.id, "l")
    }
}

private extension BreakScheduler.Event {
    var description: String {
        switch self {
        case .breakStarted(let k, _): return "start:\(k.id)"
        case .breakEnded(let k, let r): return "end:\(k.id):\(r.rawValue)"
        case .naturalBreak(let k): return "natural:\(k.id)"
        case .resumed: return "resumed"
        }
    }
}
