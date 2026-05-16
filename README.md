# Twilight

A tiny macOS menu-bar utility that automatically switches the system between
Light and Dark mode at sunrise and sunset. NightOwl-style override holds your
manual choice until the next sun event.

- macOS 13 (Ventura) or later
- No third-party dependencies
- Open source, MIT

## Install

Via Homebrew (builds from source — requires Xcode):

```sh
brew tap thegoatsmith/twilight
brew install --build-from-source twilight
ln -sfn "$(brew --prefix)/opt/twilight/Twilight.app" /Applications/Twilight.app
open -a Twilight
```

After the symlink, Twilight shows up in Spotlight, Launchpad, and the Dock like
any other app. (A `twilight` command is also on your `PATH` if you prefer the
terminal.)

## Build

```sh
brew install xcodegen
xcodegen generate
open Twilight.xcodeproj
```

Then press ⌘R in Xcode. On first run, grant Location and Automation
permissions when prompted.

## Permissions

- **Location** — used to compute your local sunrise/sunset. You can decline and
  enter a city manually in Preferences.
- **Automation (System Events)** — required to toggle Light/Dark mode. macOS
  has no public API for this, so Twilight uses an AppleScript snippet.

## How it works

`AppearanceController` runs a small state machine. In Auto mode it computes
today's sunrise and sunset via a vendored NOAA algorithm and schedules a
single `DispatchSourceTimer` for the next transition. When you manually
override, the override expires at the next sun event so Auto resumes
naturally.

## License

MIT
