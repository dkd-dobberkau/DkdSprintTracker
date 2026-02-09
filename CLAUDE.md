# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS menu bar app (no Dock icon) that displays the current dkd sprint number and day. Single-file Swift app compiled with `swiftc` — no Xcode project, no Swift Package Manager.

## Build

```bash
./build.sh
```

This compiles a universal binary (arm64 + x86_64) targeting macOS 13+, creates the `dkd Sprint Tracker.app` bundle with Info.plist, and clears Gatekeeper quarantine attributes. Requires Xcode Command Line Tools.

Install to Applications:
```bash
cp -r "dkd Sprint Tracker.app" /Applications/
```

## Architecture

Everything lives in `DkdSprintTracker.swift` — there is no project structure beyond this single file.

**Sprint calculation**: Sprints are 2-week cycles (10 working days, Mon–Fri) starting from the first Monday of each year. `firstMondayOfYear()` computes the epoch, `workingDayInSprint()` converts calendar days to working days (1–10) and detects weekends, `calculateCurrentSprint()` returns a `SprintInfo` struct with sprint number, dates, working day, progress, and weekend status. Sprint numbering resets each year. If the current date is before the year's first Monday, it falls back to the previous year's epoch.

**UI**: `AppDelegate` manages an `NSStatusItem` with a text title (`🏃 Sprint N · Tag X/10` on weekdays, `🏃 Sprint N · 🎉 Wochenende` on weekends) and an `NSMenu` dropdown showing calendar weeks, date range, sprint week, remaining working days, and a progress bar. Refreshes every 60 minutes via `Timer`.

**App lifecycle**: The `main` section at the bottom instantiates `NSApplication`, sets activation policy to `.accessory` (menu-bar-only, no Dock icon), and calls `app.run()`.

## Key Customization Points

- Sprint epoch: `firstMondayOfYear()` — change to alter the sprint start reference
- Sprint length: 10 working days (Mon–Fri over 2 calendar weeks) in `calculateCurrentSprint()`
- Refresh interval: `3600` seconds in `applicationDidFinishLaunching`
