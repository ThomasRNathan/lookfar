# LookFar

A small macOS menu bar app that reminds you to rest your eyes and move.

- **Look far** — every 20 minutes of activity, a 20-second break to look at something far away (the 20-20-20 rule).
- **Stretch** — every hour, a 5-minute break to stand up and move.
- Time away from the keyboard counts as a break, and so does sleep or a closed lid.
- Break screen on every display, with Postpone, Skip and (for long breaks) "I'm done".
- Pause for 30 min, 1 h, 2 h or until you resume. Start any break by hand.
- Settings: intervals, lengths, postpone time, idle threshold, open at login.

Requires macOS 13 Ventura or later.

## Get the app

Every push builds the app on GitHub Actions. Open the latest **Build** run under the
Actions tab and download the `LookFar` artifact, unzip it and move `LookFar.app` to
Applications. The build is ad-hoc signed, so the first time, right-click the app and
choose **Open**.

## Build it yourself

Needs Xcode 15 or later (or the Swift 5.9+ toolchain) on a Mac.

```sh
swift test               # run the scheduler tests
swift run LookFar        # run from the terminal (no Dock icon; look in the menu bar)
scripts/bundle.sh        # build build/LookFar.app
```

## Layout

- `Sources/LookFarCore` — the break scheduler, a pure state machine with no UI code.
- `Sources/LookFar` — the menu bar app (SwiftUI and AppKit): menu, settings window, break overlay.
- `Tests/LookFarCoreTests` — scheduler tests.
