import Cocoa
import ServiceManagement

// MARK: - Flipped View

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Settings

class SprintSettings {
    static let shared = SprintSettings()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let sprintStartDate = "sprintStartDate"
        static let sprintWeeks = "sprintWeeks"
        static let workingWeekdays = "workingWeekdays"
        static let showEmoji = "showEmoji"
        static let showSprintNumber = "showSprintNumber"
        static let showDayCount = "showDayCount"
        static let nonWorkingDisplay = "nonWorkingDisplay"
        static let refreshInterval = "refreshInterval"
        static let launchAtLogin = "launchAtLogin"
    }

    init() {
        defaults.register(defaults: [
            Keys.sprintWeeks: 2,
            Keys.workingWeekdays: [1, 2, 3, 4, 5],
            Keys.showEmoji: true,
            Keys.showSprintNumber: true,
            Keys.showDayCount: true,
            Keys.nonWorkingDisplay: "frei",
            Keys.refreshInterval: 3600.0,
            Keys.launchAtLogin: false
        ])
    }

    var sprintStartDate: Date {
        get {
            if let date = defaults.object(forKey: Keys.sprintStartDate) as? Date {
                return date
            }
            return defaultSprintEpoch()
        }
        set { defaults.set(newValue, forKey: Keys.sprintStartDate) }
    }

    var sprintWeeks: Int {
        get { max(1, defaults.integer(forKey: Keys.sprintWeeks)) }
        set { defaults.set(newValue, forKey: Keys.sprintWeeks) }
    }

    var workingWeekdays: [Int] {
        get { defaults.array(forKey: Keys.workingWeekdays) as? [Int] ?? [1, 2, 3, 4, 5] }
        set { defaults.set(newValue, forKey: Keys.workingWeekdays) }
    }

    var showEmoji: Bool {
        get { defaults.bool(forKey: Keys.showEmoji) }
        set { defaults.set(newValue, forKey: Keys.showEmoji) }
    }

    var showSprintNumber: Bool {
        get { defaults.bool(forKey: Keys.showSprintNumber) }
        set { defaults.set(newValue, forKey: Keys.showSprintNumber) }
    }

    var showDayCount: Bool {
        get { defaults.bool(forKey: Keys.showDayCount) }
        set { defaults.set(newValue, forKey: Keys.showDayCount) }
    }

    var nonWorkingDisplay: String {
        get { defaults.string(forKey: Keys.nonWorkingDisplay) ?? "frei" }
        set { defaults.set(newValue, forKey: Keys.nonWorkingDisplay) }
    }

    var refreshInterval: TimeInterval {
        get {
            let val = defaults.double(forKey: Keys.refreshInterval)
            return val > 0 ? val : 3600
        }
        set { defaults.set(newValue, forKey: Keys.refreshInterval) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    func defaultSprintEpoch() -> Date {
        let calendar = Calendar(identifier: .iso8601)
        let year = calendar.component(.year, from: Date())
        return firstMondayOfYear(year)
    }

    func resetAll() {
        let keys = [Keys.sprintStartDate, Keys.sprintWeeks, Keys.workingWeekdays,
                    Keys.showEmoji, Keys.showSprintNumber, Keys.showDayCount,
                    Keys.nonWorkingDisplay, Keys.refreshInterval, Keys.launchAtLogin]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Sprint Calculator

struct SprintInfo {
    let number: Int
    let startDate: Date
    let endDate: Date
    let currentDay: Int
    let totalDays: Int
    let isNonWorkingDay: Bool
    let workingDaysPerWeek: Int

    var weekInSprint: Int {
        return ((currentDay - 1) / max(1, workingDaysPerWeek)) + 1
    }

    var totalWeeks: Int {
        return totalDays / max(1, workingDaysPerWeek)
    }

    var progress: Double {
        return Double(currentDay) / Double(max(1, totalDays))
    }

    var remainingDays: Int {
        return totalDays - currentDay
    }

    /// Sprint-Label im dkd-Format: "2026-KW05-KW06"
    var label: String {
        let calendar = Calendar(identifier: .iso8601)
        let isoYear = calendar.component(.yearForWeekOfYear, from: startDate)
        let kwStart = calendar.component(.weekOfYear, from: startDate)
        let kwEnd = calendar.component(.weekOfYear, from: endDate)
        return String(format: "%d-KW%02d-KW%02d", isoYear, kwStart, kwEnd)
    }
}

func firstMondayOfYear(_ year: Int) -> Date {
    let calendar = Calendar(identifier: .iso8601)
    var components = DateComponents()
    components.yearForWeekOfYear = year
    components.weekOfYear = 1
    components.weekday = 2  // Montag
    return calendar.date(from: components)!
}

func snapToMonday(_ date: Date) -> Date {
    let calendar = Calendar(identifier: .iso8601)
    let weekday = calendar.component(.weekday, from: date)
    let isoWeekday = weekday == 1 ? 7 : weekday - 1
    if isoWeekday == 1 { return date }
    return calendar.date(byAdding: .day, value: -(isoWeekday - 1), to: date)!
}

func lastWorkingDayOffset(calendarDays: Int, isoStartWeekday: Int, workingWeekdays: Set<Int>) -> Int {
    for offset in stride(from: calendarDays - 1, through: 0, by: -1) {
        let isoWeekday = ((isoStartWeekday - 1 + offset) % 7) + 1
        if workingWeekdays.contains(isoWeekday) {
            return offset
        }
    }
    return calendarDays - 1
}

func calculateCurrentSprint() -> SprintInfo {
    let settings = SprintSettings.shared
    let calendar = Calendar(identifier: .iso8601)
    let now = Date()

    let epoch = calendar.startOfDay(for: settings.sprintStartDate)
    let today = calendar.startOfDay(for: now)
    let workingSet = Set(settings.workingWeekdays)
    let workingDaysPerWeek = max(1, workingSet.count)
    let calendarDaysPerSprint = settings.sprintWeeks * 7
    let totalWorkingDays = settings.sprintWeeks * workingDaysPerWeek

    var daysSinceEpoch = calendar.dateComponents([.day], from: epoch, to: today).day ?? 0
    daysSinceEpoch = max(0, daysSinceEpoch)

    let sprintIndex = daysSinceEpoch / calendarDaysPerSprint
    let calendarDayInSprint = daysSinceEpoch % calendarDaysPerSprint

    let sprintStart = calendar.date(byAdding: .day, value: sprintIndex * calendarDaysPerSprint, to: epoch)!
    let startWeekday = calendar.component(.weekday, from: sprintStart)
    let isoStartWeekday = startWeekday == 1 ? 7 : startWeekday - 1

    // Letzten Arbeitstag im Sprint als Enddatum
    let endOffset = lastWorkingDayOffset(calendarDays: calendarDaysPerSprint,
                                         isoStartWeekday: isoStartWeekday,
                                         workingWeekdays: workingSet)
    let sprintEnd = calendar.date(byAdding: .day, value: endOffset, to: sprintStart)!

    // Arbeitstag berechnen
    let completeWeeks = calendarDayInSprint / 7
    let dayInWeek = calendarDayInSprint % 7

    var workDay = completeWeeks * workingDaysPerWeek
    for d in 0...dayInWeek {
        let isoWeekday = ((isoStartWeekday - 1 + d) % 7) + 1
        if workingSet.contains(isoWeekday) {
            workDay += 1
        }
    }
    workDay = max(1, min(workDay, totalWorkingDays))

    let currentIsoWeekday = ((isoStartWeekday - 1 + calendarDayInSprint) % 7) + 1
    let isNonWorkingDay = !workingSet.contains(currentIsoWeekday)

    return SprintInfo(
        number: sprintIndex + 1,
        startDate: sprintStart,
        endDate: sprintEnd,
        currentDay: workDay,
        totalDays: totalWorkingDays,
        isNonWorkingDay: isNonWorkingDay,
        workingDaysPerWeek: workingDaysPerWeek
    )
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM."
    return formatter.string(from: date)
}

func isActualWeekend() -> Bool {
    let calendar = Calendar(identifier: .iso8601)
    let weekday = calendar.component(.weekday, from: Date())
    return weekday == 1 || weekday == 7
}

// MARK: - About Window

class AboutWindowController: NSObject {
    var window: NSWindow?

    func showWindow() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 290),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Über dkd Sprint Tracker"
        w.center()
        w.isReleasedWhenClosed = false

        let contentView = FlippedView(frame: w.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        w.contentView = contentView

        // App-Icon
        let iconView = NSImageView(frame: NSRect(x: 120, y: 20, width: 80, height: 80))
        if let appIcon = NSApp.applicationIconImage {
            iconView.image = appIcon
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // Titel
        let titleLabel = NSTextField(labelWithString: "dkd Sprint Tracker")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 110, width: 280, height: 25)
        contentView.addSubview(titleLabel)

        // Version
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 20, y: 138, width: 280, height: 18)
        contentView.addSubview(versionLabel)

        // Beschreibung
        let descLabel = NSTextField(labelWithString: "Zeigt den aktuellen dkd Sprint\nin der macOS Menüleiste")
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.alignment = .center
        descLabel.maximumNumberOfLines = 2
        descLabel.frame = NSRect(x: 20, y: 168, width: 280, height: 36)
        contentView.addSubview(descLabel)

        // GitHub-Link
        let linkButton = NSButton(frame: NSRect(x: 80, y: 215, width: 160, height: 22))
        linkButton.isBordered = false
        linkButton.target = self
        linkButton.action = #selector(openGitHub)
        let linkAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.linkColor,
            .font: NSFont.systemFont(ofSize: 12),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        linkButton.attributedTitle = NSAttributedString(string: "GitHub Repository →", attributes: linkAttrs)
        contentView.addSubview(linkButton)

        // Lizenz
        let licenseLabel = NSTextField(labelWithString: "MIT License · © 2025 dkd Internet Service GmbH")
        licenseLabel.font = NSFont.systemFont(ofSize: 10)
        licenseLabel.textColor = .tertiaryLabelColor
        licenseLabel.alignment = .center
        licenseLabel.frame = NSRect(x: 20, y: 252, width: 280, height: 15)
        contentView.addSubview(licenseLabel)

        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openGitHub() {
        if let url = URL(string: "https://github.com/dkd-dobberkau/DkdSprintTracker") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Settings Window

class SettingsWindowController: NSObject {
    var window: NSWindow?
    var onSettingsChanged: (() -> Void)?

    private var datePicker: NSDatePicker!
    private var weeksField: NSTextField!
    private var weeksStepper: NSStepper!
    private var weekdayCheckboxes: [NSButton] = []
    private var emojiCheckbox: NSButton!
    private var sprintNumberCheckbox: NSButton!
    private var dayCountCheckbox: NSButton!
    private var nonWorkingPopup: NSPopUpButton!
    private var refreshPopup: NSPopUpButton!
    private var loginCheckbox: NSButton!

    func showWindow() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Einstellungen"
        w.center()
        w.isReleasedWhenClosed = false

        let contentView = FlippedView(frame: w.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        w.contentView = contentView

        let labelX: CGFloat = 20
        let controlX: CGFloat = 175
        let labelWidth: CGFloat = 145
        let rowHeight: CGFloat = 28

        // ── Sprint ──
        var y: CGFloat = 15
        let sprintHeader = NSTextField(labelWithString: "Sprint")
        sprintHeader.font = NSFont.boldSystemFont(ofSize: 13)
        sprintHeader.frame = NSRect(x: labelX, y: y, width: 200, height: 20)
        contentView.addSubview(sprintHeader)

        y += 28

        // Sprint-Startdatum
        let dateLabel = NSTextField(labelWithString: "Sprint-Startdatum:")
        dateLabel.alignment = .right
        dateLabel.frame = NSRect(x: labelX, y: y, width: labelWidth, height: rowHeight)
        contentView.addSubview(dateLabel)

        datePicker = NSDatePicker(frame: NSRect(x: controlX, y: y, width: 140, height: 24))
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = .yearMonthDay
        datePicker.target = self
        datePicker.action = #selector(dateChanged)
        contentView.addSubview(datePicker)

        let dateHint = NSTextField(labelWithString: "(Montag der Woche)")
        dateHint.font = NSFont.systemFont(ofSize: 10)
        dateHint.textColor = .secondaryLabelColor
        dateHint.frame = NSRect(x: 320, y: y + 3, width: 130, height: 16)
        contentView.addSubview(dateHint)

        y += 32

        // Sprint-Dauer
        let weeksLabel = NSTextField(labelWithString: "Sprint-Dauer:")
        weeksLabel.alignment = .right
        weeksLabel.frame = NSRect(x: labelX, y: y, width: labelWidth, height: rowHeight)
        contentView.addSubview(weeksLabel)

        weeksField = NSTextField(frame: NSRect(x: controlX, y: y, width: 40, height: 24))
        weeksField.isEditable = false
        weeksField.alignment = .center
        contentView.addSubview(weeksField)

        weeksStepper = NSStepper(frame: NSRect(x: controlX + 44, y: y, width: 19, height: 24))
        weeksStepper.minValue = 1
        weeksStepper.maxValue = 4
        weeksStepper.increment = 1
        weeksStepper.valueWraps = false
        weeksStepper.target = self
        weeksStepper.action = #selector(weeksStepperChanged)
        contentView.addSubview(weeksStepper)

        let weeksUnit = NSTextField(labelWithString: "Wochen")
        weeksUnit.frame = NSRect(x: controlX + 68, y: y, width: 80, height: rowHeight)
        contentView.addSubview(weeksUnit)

        y += 32

        // Arbeitstage
        let daysLabel = NSTextField(labelWithString: "Arbeitstage:")
        daysLabel.alignment = .right
        daysLabel.frame = NSRect(x: labelX, y: y, width: labelWidth, height: rowHeight)
        contentView.addSubview(daysLabel)

        let weekdayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        let isoValues = [1, 2, 3, 4, 5, 6, 7]
        weekdayCheckboxes = []
        for (i, name) in weekdayNames.enumerated() {
            let cb = NSButton(checkboxWithTitle: name, target: self, action: #selector(weekdayToggled))
            cb.frame = NSRect(x: controlX + CGFloat(i) * 37, y: y + 2, width: 38, height: 20)
            cb.tag = isoValues[i]
            weekdayCheckboxes.append(cb)
            contentView.addSubview(cb)
        }

        y += 38

        // Separator
        let sep1 = NSBox(frame: NSRect(x: 20, y: y, width: 420, height: 1))
        sep1.boxType = .separator
        contentView.addSubview(sep1)

        y += 15

        // ── Anzeige ──
        let displayHeader = NSTextField(labelWithString: "Anzeige")
        displayHeader.font = NSFont.boldSystemFont(ofSize: 13)
        displayHeader.frame = NSRect(x: labelX, y: y, width: 200, height: 20)
        contentView.addSubview(displayHeader)

        y += 28

        emojiCheckbox = NSButton(checkboxWithTitle: "Emoji anzeigen (🏃)", target: self, action: #selector(checkboxChanged))
        emojiCheckbox.frame = NSRect(x: controlX, y: y, width: 250, height: 20)
        contentView.addSubview(emojiCheckbox)

        y += 26

        sprintNumberCheckbox = NSButton(checkboxWithTitle: "Sprint-Nummer anzeigen", target: self, action: #selector(checkboxChanged))
        sprintNumberCheckbox.frame = NSRect(x: controlX, y: y, width: 250, height: 20)
        contentView.addSubview(sprintNumberCheckbox)

        y += 26

        dayCountCheckbox = NSButton(checkboxWithTitle: "Tag-Anzeige", target: self, action: #selector(checkboxChanged))
        dayCountCheckbox.frame = NSRect(x: controlX, y: y, width: 250, height: 20)
        contentView.addSubview(dayCountCheckbox)

        y += 30

        let nonWorkLabel = NSTextField(labelWithString: "An freien Tagen:")
        nonWorkLabel.alignment = .right
        nonWorkLabel.frame = NSRect(x: labelX, y: y, width: labelWidth, height: rowHeight)
        contentView.addSubview(nonWorkLabel)

        nonWorkingPopup = NSPopUpButton(frame: NSRect(x: controlX, y: y - 2, width: 200, height: 26))
        nonWorkingPopup.addItems(withTitles: ["\"Frei\" anzeigen", "Letzten Arbeitstag", "Nächsten Arbeitstag"])
        nonWorkingPopup.target = self
        nonWorkingPopup.action = #selector(nonWorkingDisplayChanged)
        contentView.addSubview(nonWorkingPopup)

        y += 38

        // Separator
        let sep2 = NSBox(frame: NSRect(x: 20, y: y, width: 420, height: 1))
        sep2.boxType = .separator
        contentView.addSubview(sep2)

        y += 15

        // ── System ──
        let systemHeader = NSTextField(labelWithString: "System")
        systemHeader.font = NSFont.boldSystemFont(ofSize: 13)
        systemHeader.frame = NSRect(x: labelX, y: y, width: 200, height: 20)
        contentView.addSubview(systemHeader)

        y += 28

        let refreshLabel = NSTextField(labelWithString: "Aktualisierung:")
        refreshLabel.alignment = .right
        refreshLabel.frame = NSRect(x: labelX, y: y, width: labelWidth, height: rowHeight)
        contentView.addSubview(refreshLabel)

        refreshPopup = NSPopUpButton(frame: NSRect(x: controlX, y: y - 2, width: 140, height: 26))
        refreshPopup.addItems(withTitles: ["15 Minuten", "30 Minuten", "60 Minuten"])
        refreshPopup.target = self
        refreshPopup.action = #selector(refreshIntervalChanged)
        contentView.addSubview(refreshPopup)

        y += 32

        loginCheckbox = NSButton(checkboxWithTitle: "Bei Anmeldung starten", target: self, action: #selector(loginToggled))
        loginCheckbox.frame = NSRect(x: controlX, y: y, width: 250, height: 20)
        contentView.addSubview(loginCheckbox)

        y += 38

        // Separator
        let sep3 = NSBox(frame: NSRect(x: 20, y: y, width: 420, height: 1))
        sep3.boxType = .separator
        contentView.addSubview(sep3)

        y += 15

        // Standardwerte-Button
        let resetButton = NSButton(title: "Standardwerte", target: self, action: #selector(resetDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 20, y: y, width: 130, height: 28)
        contentView.addSubview(resetButton)

        window = w
        loadSettings()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func loadSettings() {
        let settings = SprintSettings.shared

        datePicker.dateValue = settings.sprintStartDate
        weeksField.integerValue = settings.sprintWeeks
        weeksStepper.integerValue = settings.sprintWeeks

        let workingSet = Set(settings.workingWeekdays)
        for cb in weekdayCheckboxes {
            cb.state = workingSet.contains(cb.tag) ? .on : .off
        }

        emojiCheckbox.state = settings.showEmoji ? .on : .off
        sprintNumberCheckbox.state = settings.showSprintNumber ? .on : .off
        dayCountCheckbox.state = settings.showDayCount ? .on : .off

        let displayOptions = ["frei", "letzter", "naechster"]
        if let idx = displayOptions.firstIndex(of: settings.nonWorkingDisplay) {
            nonWorkingPopup.selectItem(at: idx)
        }

        let intervals: [TimeInterval] = [900, 1800, 3600]
        if let idx = intervals.firstIndex(of: settings.refreshInterval) {
            refreshPopup.selectItem(at: idx)
        } else {
            refreshPopup.selectItem(at: 2)
        }

        loginCheckbox.state = settings.launchAtLogin ? .on : .off
    }

    @objc func dateChanged(_ sender: NSDatePicker) {
        let monday = snapToMonday(sender.dateValue)
        sender.dateValue = monday
        SprintSettings.shared.sprintStartDate = monday
        onSettingsChanged?()
    }

    @objc func weeksStepperChanged(_ sender: NSStepper) {
        weeksField.integerValue = sender.integerValue
        SprintSettings.shared.sprintWeeks = sender.integerValue
        onSettingsChanged?()
    }

    @objc func weekdayToggled(_ sender: NSButton) {
        var weekdays: [Int] = []
        for cb in weekdayCheckboxes {
            if cb.state == .on {
                weekdays.append(cb.tag)
            }
        }
        // Mindestens 1 Arbeitstag
        if weekdays.isEmpty {
            sender.state = .on
            weekdays.append(sender.tag)
        }
        SprintSettings.shared.workingWeekdays = weekdays
        onSettingsChanged?()
    }

    @objc func checkboxChanged(_ sender: NSButton) {
        SprintSettings.shared.showEmoji = emojiCheckbox.state == .on
        SprintSettings.shared.showSprintNumber = sprintNumberCheckbox.state == .on
        SprintSettings.shared.showDayCount = dayCountCheckbox.state == .on
        onSettingsChanged?()
    }

    @objc func nonWorkingDisplayChanged(_ sender: NSPopUpButton) {
        let options = ["frei", "letzter", "naechster"]
        let idx = sender.indexOfSelectedItem
        SprintSettings.shared.nonWorkingDisplay = options[idx]
        onSettingsChanged?()
    }

    @objc func refreshIntervalChanged(_ sender: NSPopUpButton) {
        let intervals: [TimeInterval] = [900, 1800, 3600]
        let idx = sender.indexOfSelectedItem
        SprintSettings.shared.refreshInterval = intervals[idx]
        onSettingsChanged?()
    }

    @objc func loginToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        SprintSettings.shared.launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Autostart-Registrierung fehlgeschlagen — Checkbox zurücksetzen
            sender.state = enabled ? .off : .on
            SprintSettings.shared.launchAtLogin = !enabled
        }
    }

    @objc func resetDefaults() {
        SprintSettings.shared.resetAll()
        loadSettings()
        onSettingsChanged?()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    let aboutController = AboutWindowController()
    let settingsController = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        settingsController.onSettingsChanged = { [weak self] in
            self?.settingsDidChange()
        }

        updateDisplay()
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        let interval = SprintSettings.shared.refreshInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
    }

    func settingsDidChange() {
        updateDisplay()
        startTimer()
    }

    func updateDisplay() {
        let sprint = calculateCurrentSprint()
        statusItem.button?.title = menuBarTitle(sprint: sprint)
        statusItem.button?.toolTip = "dkd \(sprint.label)\n\(formatDate(sprint.startDate))–\(formatDate(sprint.endDate))\nNoch \(sprint.remainingDays) Arbeitstage"

        setupMenu(sprint: sprint)
    }

    func menuBarTitle(sprint: SprintInfo) -> String {
        let settings = SprintSettings.shared
        var parts: [String] = []

        if settings.showSprintNumber {
            parts.append(sprint.label)
        }

        if sprint.isNonWorkingDay && settings.nonWorkingDisplay == "frei" {
            let freeEmoji = settings.showEmoji ? "🎉 " : ""
            let freeLabel = isActualWeekend() ? "Wochenende" : "Frei"
            parts.append("\(freeEmoji)\(freeLabel)")
        } else if settings.showDayCount {
            let dayToShow: Int
            if sprint.isNonWorkingDay && settings.nonWorkingDisplay == "naechster" {
                dayToShow = min(sprint.currentDay + 1, sprint.totalDays)
            } else {
                dayToShow = sprint.currentDay
            }
            parts.append("Tag \(dayToShow)/\(sprint.totalDays)")
        }

        let prefix = settings.showEmoji ? "🏃 " : ""
        return prefix + parts.joined(separator: " · ")
    }

    func setupMenu(sprint: SprintInfo) {
        let settings = SprintSettings.shared
        let menu = NSMenu()

        // Sprint-Info Header
        let headerItem = NSMenuItem(title: "dkd \(sprint.label)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        headerItem.attributedTitle = NSAttributedString(
            string: "dkd \(sprint.label)",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Zeitraum
        let dateItem = NSMenuItem(title: "📆 \(formatDate(sprint.startDate)) – \(formatDate(sprint.endDate))", action: nil, keyEquivalent: "")
        dateItem.isEnabled = false
        menu.addItem(dateItem)

        // Sprint-Woche
        let weekItem = NSMenuItem(title: "📊 Woche \(sprint.weekInSprint) von \(sprint.totalWeeks)", action: nil, keyEquivalent: "")
        weekItem.isEnabled = false
        menu.addItem(weekItem)

        // Tag im Sprint / Frei
        if sprint.isNonWorkingDay && settings.nonWorkingDisplay == "frei" {
            let freeLabel = isActualWeekend() ? "Wochenende" : "Frei"
            let freeItem = NSMenuItem(title: "🎉 \(freeLabel)", action: nil, keyEquivalent: "")
            freeItem.isEnabled = false
            menu.addItem(freeItem)
        } else {
            let dayToShow: Int
            if sprint.isNonWorkingDay && settings.nonWorkingDisplay == "naechster" {
                dayToShow = min(sprint.currentDay + 1, sprint.totalDays)
            } else {
                dayToShow = sprint.currentDay
            }
            let dayItem = NSMenuItem(title: "⏱️ Tag \(dayToShow) von \(sprint.totalDays)", action: nil, keyEquivalent: "")
            dayItem.isEnabled = false
            menu.addItem(dayItem)
        }

        // Verbleibende Arbeitstage
        let remainItem = NSMenuItem(title: "⏳ Noch \(sprint.remainingDays) Arbeitstage", action: nil, keyEquivalent: "")
        remainItem.isEnabled = false
        menu.addItem(remainItem)

        // Fortschrittsbalken
        let progressPercent = Int(sprint.progress * 100)
        let filledBlocks = Int(sprint.progress * 10)
        let emptyBlocks = 10 - filledBlocks
        let progressBar = String(repeating: "▓", count: filledBlocks) + String(repeating: "░", count: emptyBlocks)
        let progressItem = NSMenuItem(title: "\(progressBar) \(progressPercent)%", action: nil, keyEquivalent: "")
        progressItem.isEnabled = false
        menu.addItem(progressItem)

        menu.addItem(NSMenuItem.separator())

        // Über
        let aboutItem = NSMenuItem(title: "Über dkd Sprint Tracker…", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Einstellungen
        let settingsItem = NSMenuItem(title: "Einstellungen…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Beenden
        let quitItem = NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func showAbout() {
        aboutController.showWindow()
    }

    @objc func showSettings() {
        settingsController.showWindow()
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Als Menüleisten-App ohne Dock-Icon
app.setActivationPolicy(.accessory)

app.run()
