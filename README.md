# dkd Sprint Tracker

macOS menu bar app that displays the current dkd sprint number and working day.

![Menu Bar](https://img.shields.io/badge/macOS-Menu%20Bar%20App-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![macOS](https://img.shields.io/badge/macOS-13%2B-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- Shows the current sprint in the menu bar: `🏃 Sprint 3 · Tag 5/10`
- Counts only working days (Mon–Fri), 10 per sprint
- Shows `🎉 Wochenende` on Saturday and Sunday
- Dropdown menu with details: calendar weeks, date range, sprint week, remaining working days, progress bar
- Auto-refreshes every hour
- Runs as a pure menu bar app (no Dock icon)

## Sprint Logic

- Sprint 1 starts on the first Monday of each year
- Each sprint spans 2 calendar weeks = 10 working days (Mon–Fri)
- Sprint numbering resets each year

## Install with Homebrew

```bash
brew tap dkd-dobberkau/tap
brew install dkd-sprint-tracker
```

After installation, start the app:

```bash
open "/Applications/dkd Sprint Tracker.app"
```

## Build from Source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/dkd-dobberkau/DkdSprintTracker.git
cd DkdSprintTracker
./build.sh
cp -r "dkd Sprint Tracker.app" /Applications/
```

## Autostart

System Settings → General → Login Items → `+` → select "dkd Sprint Tracker"

## Customization

Edit `DkdSprintTracker.swift`:

- **Sprint epoch**: `firstMondayOfYear()` — change the sprint start reference
- **Sprint length**: 10 working days in `calculateCurrentSprint()`
- **Refresh interval**: `3600` seconds in `applicationDidFinishLaunching`

## License

[MIT](LICENSE)
