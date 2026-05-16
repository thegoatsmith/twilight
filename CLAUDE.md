# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Twilight is a macOS 13+ menu-bar utility (SwiftUI, Swift 5.9, no third-party deps) that switches the system between Light and Dark mode at sunrise/sunset. A NightOwl-style manual override holds until the next sun event, then Auto resumes.

## Build / run / test

The Xcode project is **generated** — `Twilight.xcodeproj/` is gitignored. After any change to `project.yml`, regenerate:

```sh
brew install xcodegen   # one-time
xcodegen generate
```

Build & run from Xcode (⌘R), or from CLI:

```sh
# Build
xcodebuild -project Twilight.xcodeproj -scheme Twilight -configuration Debug build

# Run all tests (headless)
xcodebuild test -project Twilight.xcodeproj -scheme Twilight -destination 'platform=macOS'

# Run a single test class or method
xcodebuild test -project Twilight.xcodeproj -scheme Twilight -destination 'platform=macOS' \
  -only-testing:TwilightTests/ScheduleStoreTests
xcodebuild test -project Twilight.xcodeproj -scheme Twilight -destination 'platform=macOS' \
  -only-testing:TwilightTests/ScheduleStoreTests/test_auto_beforeSunrise_isDark
```

First run prompts for **Location** and **Automation (System Events)** permissions — both are required for normal operation but the app degrades gracefully if denied (manual city entry; in-app warning that links to System Settings).

## Architecture

The app is intentionally split into small, protocol-fronted units so `AppearanceController` — the only stateful piece — can be driven entirely from tests with no system side effects.

### State machine: `AppearanceController` (`Twilight/Core/AppearanceController.swift`)

Owns three published values the UI binds to: `mode`, `todaySun`, `nextEventAt`. It is the *only* place that mutates appearance or schedules timers. `reevaluate()` is the single re-entry point — called on start, location updates, wake from sleep, time-zone change, external appearance change (someone else flipped Dark mode), and timer fire. Each call:

1. Expires the override if `prefs.overrideExpiresAt <= now`.
2. Asks `SolarCalculator` for today's sun times at the current `Location`.
3. Asks `ScheduleStore.desired(...)` what appearance *should* be applied now, and applies via `ThemeApplier` only if it differs from the current system appearance.
4. Asks `ScheduleStore.nextTransition(...)` (Auto) or reads `prefs.overrideExpiresAt` (manual) for the next fire date, and arms a single `DispatchSourceTimer` for it.

There is at most one timer at a time. Wake/timezone notifications cause re-evaluation rather than maintaining a long-running poll loop.

### Pure scheduling rules: `ScheduleStore` (`Twilight/Core/ScheduleStore.swift`)

All "what should we do, when" logic lives here as pure static functions on `(Mode, now, today, tomorrow)`. The override-expiry rule — *override ends the next time Auto would disagree with it* — means `manualLight` expires at the next sunset and `manualDark` at the next sunrise. Keep new scheduling logic in this file; do not push branches into the controller.

### Solar math: `SolarCalculator` (`Twilight/Core/SolarCalculator.swift`)

Vendored NOAA algorithm. **Returns UTC `Date`s.** Returns `nil` for polar day/night — callers must handle this (the controller falls back to the applier's current system appearance). Use `tomorrowSunTimes` in `AppearanceController` as the reference for computing the next day: anchor off today's *sunset + 86_400s*, not sunrise + 24h, because in far-from-UTC timezones today's sunrise can sit in the previous UTC day and adding 24h would land back on the same civil day.

### Testability seams

Every dependency the controller touches is a protocol with a fake/spy in `TwilightTests/TestDoubles.swift`:

- `Clock` (`SystemClock` / `FakeClock`) — never call `Date()` directly inside the controller; use the injected clock.
- `ThemeApplier` (`AppleScriptThemeApplier` / `SpyThemeApplier`) — production impl uses `NSAppleScript` against System Events; treats AppleScript errors `-1743 / -600 / -609` as `automationDenied` and surfaces that to the UI.
- `LocationProvider` (`CoreLocationProvider` / `StubLocationProvider`) — Combine publisher of `Location?`; one-shot updates (we stop updating after the first fix).
- `PreferencesStore` — thin `UserDefaults` wrapper; tests construct it with a per-test suite (`UserDefaults(suiteName: …UUID…)`) to avoid cross-test pollution.

When adding a new system dependency, follow the same pattern: protocol + production class + test double.

### UI

`TwilightApp` declares two scenes: `MenuBarExtra` (the only window normally visible — `LSUIElement` is true) and `Settings` (location source, launch-at-login, permission status). Views observe the controller and call its `switchToLight()` / `switchToDark()` / `resumeAuto()` actions — they do not compute appearance themselves. `MenuBarIcon` is the one exception: it asks `ScheduleStore.desired(...)` to decide between sun/moon glyph, so the icon stays in sync even when the system appearance hasn't been applied yet.

### Persistence

All state lives in `UserDefaults` via `PreferencesStore`. Keys are centralized in `PreferencesKey`. `Location` is JSON-encoded. There is no other on-disk storage.

## Conventions worth knowing

- Core types (`Mode`, `Location`, `SunTimes`, `Appearance`, `Clock`, `ScheduleStore`, etc.) are `public` so `TwilightTests` can use `@testable import Twilight` and call them directly.
- Sun times and all internal `Date`s are UTC; only the UI formats to local time.
- The app uses `LSUIElement = true` (set in `project.yml`, not Info.plist directly) — there is no Dock icon and no main window beyond MenuBarExtra/Settings.
- Code signing is set to ad-hoc (`CODE_SIGN_IDENTITY: "-"`) for local dev; do not change without reason.
- Commit atomically: one logical change per commit, using the `<type>: <summary>` style of existing commits (`feat:`, `fix:`, `docs:`, …). Don't bundle unrelated edits — split them.
- Behavior changes ship with tests: add or update an `XCTestCase` in `TwilightTests/` for any change under `Core/`, `Location/`, or `Persistence/`, using the protocol fakes in `TestDoubles.swift`. Pure UI tweaks (styling, SF Symbol swaps) are exempt.
