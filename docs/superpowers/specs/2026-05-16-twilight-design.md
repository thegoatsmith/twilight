# Twilight — Design Spec

**Date:** 2026-05-16
**Status:** Approved for planning

## Overview

Twilight is a macOS menu-bar utility that automatically toggles the system
appearance between Light and Dark mode based on local sunrise and sunset. The
user can manually override the current theme; the override holds until the next
sun event, then auto switching resumes. It is a NightOwl-style clone, open
source, targeting macOS 13 (Ventura) and later.

- **App name:** Twilight
- **Bundle ID:** `com.apisak-w.twilight`
- **Min macOS:** 13.0
- **Distribution:** Open source on GitHub. No App Store, no notarization in v1.

## Goals

- Switch system appearance at exact sunrise and exact sunset automatically.
- Let the user manually override Light/Dark from the menu bar; resume auto at
  the next sun event.
- Detect location via CoreLocation; fall back to a manual city picker if
  permission is denied.
- Persist preferences and override state across app restarts and sleep cycles.
- Launch at login (default on, user-toggleable).
- Stay minimal: under ~800 lines of Swift, no third-party dependencies.

## Non-goals (v1)

- Sunrise/sunset offsets, civil twilight, or custom fixed times.
- Per-app theme overrides.
- Wallpaper switching, accent color, or any preference beyond appearance.
- iCloud sync of preferences.
- App Store distribution / sandboxing.

## Critical platform constraint

macOS has **no public API** to programmatically set the system appearance.
Every menu-bar dark-mode app (NightOwl, Gray, etc.) drives it via an AppleScript
snippet against System Events:

```applescript
tell application "System Events"
  tell appearance preferences
    set dark mode to true
  end tell
end tell
```

This requires the user to grant **Automation** permission for Twilight to
control System Events on first run. We handle this with a one-time alert + deep
link to System Settings → Privacy & Security → Automation. All AppleScript
execution is centralized in one file (`ThemeApplier.swift`) to keep that
permission surface tiny and testable.

## Architecture

SwiftUI-first app using `MenuBarExtra(.window)` (macOS 13+). No AppKit shim
unless needed. Pure-Swift NOAA sunrise/sunset algorithm vendored as a single
file — no network, no dependencies.

```
Twilight.app
├── TwilightApp.swift              @main, App scene + MenuBarExtra + Settings
├── Core
│   ├── AppearanceController.swift   Owns state, schedules transitions, applies theme
│   ├── ThemeApplier.swift           Wraps NSAppleScript; only place that talks to System Events
│   ├── SolarCalculator.swift        Pure math: (lat, lng, date) -> (sunrise, sunset)
│   └── ScheduleStore.swift          Computes next transition, holds override state
├── Location
│   ├── LocationProvider.swift       CoreLocation auto, manual fallback
│   └── CityResolver.swift           MKLocalSearchCompleter for city autocomplete
├── Persistence
│   └── Preferences.swift            @AppStorage-backed settings model
├── Launch
│   └── LoginItemManager.swift       SMAppService wrapper
└── UI
    ├── MenuBarView.swift            Dropdown content
    ├── MenuBarIcon.swift            Sun/moon SF Symbol that swaps with mode
    └── SettingsView.swift           Preferences window
```

### Module boundaries

- `AppearanceController` is the **only writer** of mode state. UI observes via
  `@Observable`; never mutates directly.
- `ThemeApplier` is the **only** caller of `NSAppleScript` in the entire app.
- `SolarCalculator` is pure: takes a `Date` parameter, does no I/O, never
  reads `Date.now`. Trivially unit-testable.
- `LocationProvider` exposes a `Location` value type (`{ lat, lng, name? }`),
  not `CLLocation`, so the rest of the app does not depend on CoreLocation.

## Data model

```swift
enum Mode: String, Codable {
    case auto
    case manualLight
    case manualDark
}

struct Location: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let displayName: String?    // "Bangkok, Thailand" — best effort
}

struct SunTimes: Equatable {
    let sunrise: Date           // nil-able via Optional<SunTimes> at call site (polar)
    let sunset: Date
}

@Observable final class AppState {
    var mode: Mode = .auto
    var location: Location?
    var todaySun: SunTimes?
    var nextTransition: Date?
    var hasAutomationPermission: Bool = true   // false after first failed apply
}
```

## State machine

The decision rule, run on every trigger:

```
if mode == .manualLight  -> apply Light, no scheduled transition
if mode == .manualDark   -> apply Dark,  no scheduled transition
if mode == .auto:
    desired = (now is between sunrise and sunset) ? Light : Dark
    apply(desired) if different from currentSystemAppearance
    schedule wakeup at next sun event (today's remaining, else tomorrow's)
```

### Override expiry

When the user clicks _Switch to Light_ / _Switch to Dark_:

1. Set `mode = .manualLight` (or `.manualDark`).
2. Apply that appearance immediately.
3. Arm a one-shot `DispatchSourceTimer` for the next sun event in the opposite
   direction:
   - `manualLight` → expires at next sunset
   - `manualDark`  → expires at next sunrise
4. At expiry, set `mode = .auto` and re-run the decision rule.

_Resume Auto_ in the menu does the same as expiry, immediately.

### Triggers

| Trigger | Action |
|---|---|
| App launch | Restore mode/override-expiry from `@AppStorage`. Resolve location. Compute today's sun. Run decision rule. |
| User clicks Switch Light/Dark | Set manual mode, apply, arm override-expiry timer. |
| User clicks Resume Auto | Set `.auto`, cancel override timer, run decision rule. |
| Scheduled transition fires (auto mode) | Run decision rule. |
| Override-expiry fires | Set `.auto`, run decision rule. |
| Location changes | Recompute today's sun, re-arm. |
| `NSWorkspace.didWakeNotification` | Run decision rule (catches missed transitions during sleep). |
| Midnight rollover | Recompute next day's sun, re-arm. |
| `NSSystemTimeZoneDidChange` | Recompute sun times, re-arm. |
| `AppleInterfaceThemeChangedNotification` (distributed) | If auto mode and external change disagrees, re-apply (auto wins). In manual mode, no-op. |

### Timer choice

`DispatchSourceTimer` on the main queue, scheduled for the exact next event.
Not a polling `Timer.scheduledTimer(every: 60s)` — wasteful and unreliable
across sleep. The wake-from-sleep notification is what catches drift.

## Persistence

`@AppStorage` (UserDefaults) keys:

- `mode` — current `Mode` (auto / manualLight / manualDark)
- `overrideExpiresAt` — `Date?` for surviving restart mid-override
- `useAutoLocation` — `Bool`; if false, use `manualLocation`
- `manualLocation` — JSON-encoded `Location?`
- `lastKnownLocation` — JSON-encoded `Location?` (cache of last CoreLocation result)
- `launchAtLogin` — `Bool`, default `true`

On launch, if `overrideExpiresAt` is in the past, the override is treated as
already expired and we boot in `.auto`.

## UI

### Menu bar icon

`MenuBarIcon` shows an SF Symbol that swaps with the currently-applied
appearance:

- Light applied → `sun.max`
- Dark applied → `moon.stars`

Template-rendered so it adapts to the menu bar's own appearance.

### Menu bar dropdown (`MenuBarView`)

```
● Auto Mode
  Switches to Light at 06:42

  ☀  Switch to Light
  ☾  Switch to Dark
  ↻  Resume Auto

  Preferences…
  Quit
```

- Header line shows current mode (`Auto`, `Manual: Light`, `Manual: Dark`).
- Subline shows the next transition time (in auto mode) or override expiry (in
  manual mode).
- _Resume Auto_ is dimmed when already in auto.
- The active manual choice (e.g. _Switch to Light_ while in `.manualLight`) is
  dimmed.

### Preferences (`SettingsView`)

Single tab. Form-style layout.

- **Location** — radio: "Use my location (CoreLocation)" / "Manual". When
  Manual, show a `MKLocalSearchCompleter`-backed city autocomplete and the
  resolved coordinates.
- **Launch at login** — toggle, wired to `SMAppService`.
- **Permissions** — read-only status rows for CoreLocation and Automation. Each
  has a "Open System Settings" button if denied.
- **About** — version, GitHub link.

## Error handling

| Failure | Handling |
|---|---|
| CoreLocation permission denied | Fall back to manual picker; surface in Prefs. Do not re-prompt. |
| Automation permission denied | One-time alert with deep link to Privacy & Security → Automation. Switching disabled; menu shows ⚠️ state until granted. |
| AppleScript execution fails otherwise | Log, surface non-blocking error in the menu, retry on next trigger. Do not crash. |
| Polar day / night (no sunrise or sunset on a date) | `SolarCalculator` returns `nil` for the missing event. Treat day as continuation of yesterday's last direction. Menu shows "No sunset today" or equivalent. |
| No network | Not a concern — sun calculation is local. Reverse geocoding for display name is best-effort. |
| Wake from long sleep | `didWakeNotification` runs decision rule and rearms timer. |
| External appearance change while in auto mode | Distributed `AppleInterfaceThemeChangedNotification` observed; auto re-applies its preferred value. |
| Clock or timezone change | `NSSystemTimeZoneDidChange` recomputes and rearms. |

## Testing

### Unit tests

- **`SolarCalculator`** — table-driven against NOAA reference values for ~6
  locations and dates, including DST boundaries and a polar case.
- **`ScheduleStore.nextTransition(from:in:)`** — pure function on
  `(now, mode, sun)`. Cases: before sunrise / between / after sunset; all
  three modes; override-expiry math.
- **`AppearanceController`** — injected `ThemeApplier` protocol + injected
  clock. Verify state-machine transitions for each trigger. Spy on
  `apply(_:)` calls.
- **`LocationProvider`** — protocol-wrapped; stub for tests.

### Out of CI

- `ThemeApplier`'s actual AppleScript call is smoke-tested manually only;
  cannot grant Automation permission in CI.

### Manual QA checklist

- Fresh install: CoreLocation prompt, Automation prompt on first switch.
- Override to Light at 14:00 → verify auto returns at sunset.
- Override to Dark at 22:00 → verify auto returns at next sunrise.
- Sleep laptop overnight → wake → verify correct theme applied.
- Change location via Prefs → verify next transition time updates.
- Toggle launch-at-login → verify Login Items in System Settings.
- Deny Automation → verify alert and disabled state.

## Technology choices

| Concern | Choice | Reason |
|---|---|---|
| App framework | SwiftUI + `MenuBarExtra(.window)` | macOS 13+ native, minimal code |
| Theme apply | `NSAppleScript` against System Events | Only viable path; centralized |
| Sunrise/sunset | Vendored NOAA Swift port (~100 lines) | No deps, offline |
| Location | `CLLocationManager` + `MKLocalSearchCompleter` | Apple-native, no API keys |
| Persistence | `@AppStorage` over UserDefaults | Sufficient; small data set |
| Launch at login | `SMAppService` (macOS 13+) | Modern, no helper-app contortions |
| Timer | `DispatchSourceTimer` for next event | Precise; not polling |
| Build | Xcode project (`Twilight.xcodeproj`) | Standard for open-source macOS |
| Tests | XCTest, no third-party | Standard |

## File / line budget estimate

| Module | Approx LOC |
|---|---|
| TwilightApp.swift | 60 |
| AppearanceController | 180 |
| ThemeApplier | 60 |
| SolarCalculator | 120 |
| ScheduleStore | 90 |
| LocationProvider | 110 |
| CityResolver | 80 |
| Preferences | 50 |
| LoginItemManager | 40 |
| MenuBarView + MenuBarIcon | 120 |
| SettingsView | 140 |
| Tests | ~300 |
| **Total** | **~750 prod + 300 test** |

## Open questions (deferred to plan)

- Exact NOAA algorithm variant (Astronomical Almanac vs. NOAA Solar Calculator).
  Plan should pick one and cite reference values.
- Icon assets: SF Symbols for v1; custom icon optional later.
- App icon: placeholder for v1; design later.
