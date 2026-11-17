import AppKit
import SwiftUI
import LookFarCore

/// Shows the break screen on every display and hides it again.
@MainActor
final class OverlayController {
    var onPostpone: () -> Void = {}
    var onSkip: () -> Void = {}
    var onEndEarly: () -> Void = {}

    private var windows: [NSWindow] = []
    private static let fade: TimeInterval = 0.6

    func show(kind: BreakKind, endsAt: Date, controlsDelay: TimeInterval) {
        hideImmediately()
        let startedAt = Date()
        for screen in NSScreen.screens {
            let view = BreakView(
                kind: kind,
                startedAt: startedAt,
                endsAt: endsAt,
                controlsDelay: controlsDelay,
                showsControls: screen == NSScreen.main,
                onPostpone: { [weak self] in self?.onPostpone() },
                onSkip: { [weak self] in self?.onSkip() },
                onEndEarly: { [weak self] in self?.onEndEarly() }
            )
            let window = OverlayWindow(screen: screen, content: view)
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }
        windows.first(where: { $0.screen == NSScreen.main })?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fade
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func hide() {
        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fade
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }

    private func hideImmediately() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }
}

/// A borderless window that covers one display, above normal and full-screen apps.
private final class OverlayWindow: NSWindow {
    init<Content: View>(screen: NSScreen, content: Content) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: content)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Break screen

/// LookFar's break screen: a dusk horizon with a countdown ring.
struct BreakView: View {
    let kind: BreakKind
    let startedAt: Date
    let endsAt: Date
    let controlsDelay: TimeInterval
    let showsControls: Bool
    let onPostpone: () -> Void
    let onSkip: () -> Void
    let onEndEarly: () -> Void

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 0.25)) { context in
            let now = context.date
            let remaining = max(0, endsAt.timeIntervalSince(now))
            let progress = kind.duration > 0 ? 1 - remaining / kind.duration : 1
            let controlsReady = now.timeIntervalSince(startedAt) >= controlsDelay

            ZStack {
                Horizon()

                VStack(spacing: 28) {
                    Text(kind.name.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.6))

                    Text(kind.prompt)
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    CountdownRing(progress: progress, label: Format.clock(remaining))
                        .frame(width: 140, height: 140)

                    if showsControls {
                        HStack(spacing: 12) {
                            BreakButton(title: "Postpone", action: onPostpone)
                            BreakButton(title: "Skip", action: onSkip)
                            if kind.duration >= 60 {
                                BreakButton(title: "I'm done", action: onEndEarly)
                            }
                        }
                        .disabled(!controlsReady)
                        .opacity(controlsReady ? 1 : 0.35)
                        .animation(.easeOut(duration: 0.3), value: controlsReady)
                    }
                }
                .padding(48)
            }
        }
    }
}

/// Deep blue sky fading to a warm band at the horizon line, low on the screen.
private struct Horizon: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.05, green: 0.07, blue: 0.16), location: 0),
                    .init(color: Color(red: 0.12, green: 0.17, blue: 0.33), location: 0.55),
                    .init(color: Color(red: 0.55, green: 0.36, blue: 0.36), location: 0.78),
                    .init(color: Color(red: 0.93, green: 0.64, blue: 0.42), location: 0.82),
                    .init(color: Color(red: 0.09, green: 0.10, blue: 0.16), location: 0.83),
                    .init(color: Color(red: 0.04, green: 0.05, blue: 0.09), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .opacity(0.96)
        .ignoresSafeArea()
    }
}

private struct CountdownRing: View {
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(red: 0.98, green: 0.76, blue: 0.52), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)
            Text(label)
                .font(.system(size: 34, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}

private struct BreakButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.25)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
