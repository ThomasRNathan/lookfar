import Foundation

/// A kind of break, such as the short "look far" break or the longer stretch break.
public struct BreakKind: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var name: String
    /// Active (non-idle) work time between two breaks of this kind.
    public var interval: TimeInterval
    /// How long the break lasts.
    public var duration: TimeInterval
    /// The line shown on the break screen.
    public var prompt: String
    public var isEnabled: Bool

    public init(
        id: String,
        name: String,
        interval: TimeInterval,
        duration: TimeInterval,
        prompt: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.interval = interval
        self.duration = duration
        self.prompt = prompt
        self.isEnabled = isEnabled
    }

    /// 20-20-20: every 20 minutes, look about 20 feet (6 m) away for 20 seconds.
    public static let lookFar = BreakKind(
        id: "lookfar",
        name: "Look far",
        interval: 20 * 60,
        duration: 20,
        prompt: "Look at something far away"
    )

    /// A longer break to stand up and move.
    public static let stretch = BreakKind(
        id: "stretch",
        name: "Stretch",
        interval: 60 * 60,
        duration: 5 * 60,
        prompt: "Stand up, stretch, walk around"
    )
}

public struct Preferences: Codable, Equatable {
    public var breaks: [BreakKind]
    /// Seconds without keyboard or mouse input before you count as away.
    public var idleThreshold: TimeInterval
    /// How much "Postpone" pushes a break back.
    public var postponeDuration: TimeInterval
    /// Seconds at the start of a break during which Skip and Postpone are disabled.
    public var controlsDelay: TimeInterval

    public init(
        breaks: [BreakKind] = [.lookFar, .stretch],
        idleThreshold: TimeInterval = 30,
        postponeDuration: TimeInterval = 5 * 60,
        controlsDelay: TimeInterval = 3
    ) {
        self.breaks = breaks
        self.idleThreshold = idleThreshold
        self.postponeDuration = postponeDuration
        self.controlsDelay = controlsDelay
    }

    public static let `default` = Preferences()
}
